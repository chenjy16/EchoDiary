import StoreKit
import SwiftData
import SwiftUI

struct ChatsListView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Binding var currentThread: Thread?
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Thread.timestamp, order: .reverse) var threads: [Thread]
    @State var search = ""
    @State var selection: Thread?
    @Binding var isPromptFocused: Bool
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            ZStack {
                List(selection: $selection) {
                    ForEach(filteredThreads, id: \.id) { thread in
                        VStack(alignment: .leading) {
                            ZStack {
                                if let firstMessage = thread.sortedMessages.first {
                                    Text(firstMessage.content)
                                        .lineLimit(1)
                                } else {
                                    Text("untitled")
                                }
                            }
                            .foregroundStyle(.primary)
                            .font(.headline)

                            Text("\(thread.timestamp.formatted())")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                            .tag(thread)
                    }
                    .onDelete(perform: deleteThreads)
                }
                .onChange(of: selection) {
                    setCurrentThread(selection)
                }
                .listStyle(.insetGrouped)
                if filteredThreads.count == 0 {
                    ContentUnavailableView {
                        Label(threads.count == 0 ? "no chats yet" : "no results", systemImage: "message")
                    }
                }
            }
            .navigationTitle("chats")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "search")
           
                .toolbar {

                    if appManager.userInterfaceIdiom == .phone {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                            }
                        }
                    }

                  /*  ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            selection = nil
                            // create new thread
                            setCurrentThread(nil)

                            // ask for review if appropriate
                            requestReviewIfAppropriate()
                        }) {
                            Image(systemName: "plus")
                        }
                        .keyboardShortcut("N", modifiers: [.command])

                    }*/
                    
                }
        }
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
    }

    var filteredThreads: [Thread] {
        threads.filter { thread in
            search.isEmpty || thread.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(search)
            }
        }
    }

    func requestReviewIfAppropriate() {
        if appManager.numberOfVisits - appManager.numberOfVisitsOfLastRequest >= 5 {
            requestReview() // can only be prompted if the user hasn't given a review in the last year, so it will prompt again when apple deems appropriate
            appManager.numberOfVisitsOfLastRequest = appManager.numberOfVisits
        }
    }

    private func deleteThreads(at offsets: IndexSet) {
        for offset in offsets {
            let thread = threads[offset]

            if let currentThread = currentThread {
                if currentThread.id == thread.id {
                    setCurrentThread(nil)
                }
            }

            // Adding a delay fixes a crash on iOS following a deletion
            let delay = appManager.userInterfaceIdiom == .phone ? 1.0 : 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                modelContext.delete(thread)
            }
        }
    }

    private func deleteThread(_ thread: Thread) {
        if let currentThread = currentThread {
            if currentThread.id == thread.id {
                setCurrentThread(nil)
            }
        }
        modelContext.delete(thread)
    }

    private func setCurrentThread(_ thread: Thread? = nil) {
        currentThread = thread
        isPromptFocused = true
        dismiss()
        appManager.playHaptic()
    }
}
