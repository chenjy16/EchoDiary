import SwiftUI
import MLXLMCommon

struct DiaryListView: View {
    @ObservedObject var viewModel: DiaryViewModel
    @State private var showingNewEntrySheet = false
    @State private var searchText = ""
    @State private var selectedFilter: EntryFilter = .all

    @State private var showingModelInstallAlert = false  // 添加模型安装提示状态
    @State private var showModelInstallView = false
    @State private var selectedModel = MLXLMCommon.ModelConfiguration.defaultModel
    @EnvironmentObject var appManager: AppManager  // 添加 AppManager 环境对象
    @Environment(LLMEvaluator.self) var llm  // 添加 LLM 环境
    
    enum EntryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case hasAudio = "With Audio"
        case recent = "Recent"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .hasAudio: return "mic.fill"
            case .recent: return "clock"
            }
        }
    }
    
    init(viewModel: DiaryViewModel? = nil) {
        if let vm = viewModel {
            self._viewModel = ObservedObject(wrappedValue: vm)
        } else {
            self._viewModel = ObservedObject(wrappedValue: DiaryViewModel())
        }
    }
    
    var filteredEntries: [DiaryEntry] {
        let entries = viewModel.diaryEntries
        
        // 应用搜索过滤
        let searchFiltered = searchText.isEmpty ? entries : entries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
        
        // 应用分类过滤
        switch selectedFilter {
        case .all:
            return searchFiltered
        case .hasAudio:
            return searchFiltered.filter { $0.audioURL != nil }
        case .recent:
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return searchFiltered.filter { $0.date >= oneWeekAgo }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search entries", text: $searchText)
                    .font(.system(size: 16))
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // 过滤选项
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(EntryFilter.allCases) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            HStack {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 12))
                                Text(filter.rawValue)
                                    .font(.system(size: 13))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.1))
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // 日记列表
            List {
                ForEach(filteredEntries) { entry in
                    NavigationLink(destination: DiaryDetailView(entry: entry, viewModel: viewModel)) {
                        EnhancedDiaryEntryRow(entry: entry)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.deleteEntry(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            // Don't set the navigation title here, it's already set in StartView
            .overlay {
                if filteredEntries.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Entries Found")
                            .font(.headline)
                        Text("Try changing your search or filter, or create a new entry")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingNewEntrySheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewEntrySheet) {
            NewDiaryEntryView(viewModel: viewModel)
        }
        // 保留一个 sheet 定义
        .sheet(isPresented: $showModelInstallView) {
            NavigationStack {
                OnboardingInstallModelView(showOnboarding: $showModelInstallView)
                    .environment(llm)
                    .environmentObject(appManager)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { showModelInstallView = false }) {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            } // 添加缺少的右括号
        }
        .onChange(of: showingNewEntrySheet) { isPresented in
            if !isPresented {
                viewModel.loadEntries()
            }
        }
        .onAppear {
            viewModel.loadEntries()
        }
        // 合并多个 onAppear 块
        .onAppear {
            // 检查模型是否已安装
            checkModelInstallation()
            
            // 刷新日记列表
            viewModel.loadEntries()
        }
    }
    
    // 添加检查模型安装的方法
    private func checkModelInstallation() {
        // 检查语音识别模型
        let audioViewModel = AudioViewModel()
        let whisperModelAvailable = audioViewModel.checkModelAvailability()
        
        // 使用更可靠的方式检查LLM模型
        let modelName = MLXLMCommon.ModelConfiguration.defaultModel.name
        let isModelInstalled = appManager.installedModels.contains(modelName)
        
        // 在主线程上下文中检查模型加载状态
        Task { @MainActor in
            // 检查模型是否已加载
            let isModelLoaded: Bool
            switch llm.loadState {
            case .loaded:
                isModelLoaded = true
            case .idle:
                isModelLoaded = false
                // 如果模型已安装但未加载，尝试加载
                if isModelInstalled {
                    do {
                        try await llm.load(modelName: modelName)
                    } catch {
                        print("模型加载失败: \(error.localizedDescription)")
                        showingModelInstallAlert = true
                    }
                }
            }
            
            if !whisperModelAvailable || !isModelInstalled || (!isModelLoaded && isModelInstalled) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingModelInstallAlert = true
                }
            }
        }
    }
}

// 增强版日记条目行
struct EnhancedDiaryEntryRow: View {
    let entry: DiaryEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 日期显示
            VStack {
                Text("\(Calendar.current.component(.day, from: entry.date))")
                    .font(.system(size: 22, weight: .bold))
                Text(entry.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(width: 45, height: 45)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title)
                    .font(.headline)
                
                if !entry.content.isEmpty {
                    Text(entry.content.prefix(80) + (entry.content.count > 80 ? "..." : ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if entry.audioURL != nil {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                        Text("Audio Recording")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}


