import MarkdownUI
import SwiftUI
import MLXLMCommon

struct ChatView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Binding var currentThread: Thread?
    @Environment(LLMEvaluator.self) var llm
    @Namespace var bottomID
    @State var showModelPicker = false
    @State var prompt = ""
    
    
    // 移除多余的焦点状态同步机制
     @FocusState var isTextFieldFocused: Bool
     // 保留一个焦点状态绑定
     @Binding var isPromptFocused: Bool
    
    
    @Binding var showChats: Bool
    @Binding var showSettings: Bool
    
    @State private var generatingThreadID: UUID?
    

    var isPromptEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    let platformBackgroundColor: Color = {
        return Color(UIColor.secondarySystemBackground)
    }()

    var chatInput: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // 简化输入框配置，减少不必要的修饰符
            TextField("message", text: $prompt, axis: .vertical)
            .focused($isTextFieldFocused)
            .onChange(of: isTextFieldFocused) { newValue in
                // 单向同步，避免循环引用
                if isPromptFocused != newValue {
                    isPromptFocused = newValue
                }
            }
            .onChange(of: isPromptFocused) { newValue in
                // 使用异步更新避免UI阻塞
                if isTextFieldFocused != newValue {
                    DispatchQueue.main.async {
                        isTextFieldFocused = newValue
                    }
                }
            }
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 48)
            .onSubmit {
                generate()
            }
            if llm.running {
                stopButton
            } else {
                generateButton
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(platformBackgroundColor)
        )
    }

    var showChatsButton: some View {
        // 聊天列表按钮 - 从导航栏移到这里
        Button(action: {
            appManager.playHaptic()
            showChats.toggle()
        }) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 22))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
        }
    }

    var generateButton: some View {
        Button {
            generate()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

        }
        .disabled(isPromptEmpty)
        .padding(.trailing, 12)
        .padding(.bottom, 12)
    }

    var stopButton: some View {
        Button {
            llm.stop()
        } label: {
            Image(systemName: "stop.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

        }
        .disabled(llm.cancelled)
        .padding(.trailing, 12)
        .padding(.bottom, 12)
    }

    var chatTitle: String {
        if let currentThread = currentThread {
            if let firstMessage = currentThread.sortedMessages.first {
                return firstMessage.content
            }
        }

        return "chat"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 添加当前模型指示器
                if let currentModelName = appManager.currentModelName {
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Text("当前模型: \(appManager.modelDisplayName(currentModelName))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                }
                
                if let currentThread = currentThread {
                    ConversationView(thread: currentThread, generatingThreadID: generatingThreadID)
                } else {
                    Spacer()
                    Image(systemName: appManager.getMoonPhaseIcon())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.quaternary)
                    Spacer()
                }

                HStack(alignment: .bottom) {
                    showChatsButton
                    chatInput
                }
                .padding()
            }
            // 简化焦点状态同步逻辑
            .onChange(of: isPromptFocused) { newValue in
                isTextFieldFocused = newValue
            }
            .onChange(of: isTextFieldFocused) { newValue in
                isPromptFocused = newValue
            }
            .onChange(of: appManager.currentModelName) { newModelName in
                if let modelName = newModelName,
                   let model = MLXLMCommon.ModelConfiguration.getModelByName(modelName) {
                    Task {
                        await llm.switchModel(model)
                    }
                }
            }
            .navigationTitle(chatTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        appManager.playHaptic()
                        showSettings.toggle()
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }

    private func generate() {
        if !isPromptEmpty {
            if currentThread == nil {
                let newThread = Thread()
                currentThread = newThread
                modelContext.insert(newThread)
                try? modelContext.save()
            }

            if let currentThread = currentThread {
                generatingThreadID = currentThread.id
                Task {
                    let message = prompt
                    prompt = ""
                    appManager.playHaptic()
                    sendMessage(Message(role: .user, content: message, thread: currentThread))
                    if let modelName = appManager.currentModelName {
                        let output = await llm.generate(modelName: modelName, thread: currentThread, systemPrompt: appManager.systemPrompt)
                        sendMessage(Message(role: .assistant, content: output, thread: currentThread, generatingTime: llm.thinkingTime))
                        generatingThreadID = nil
                    }
                }
            }
        }
    }

    private func sendMessage(_ message: Message) {
        appManager.playHaptic()
        modelContext.insert(message)
        try? modelContext.save()
    }

}
