import Foundation
import Combine
import MLXLMCommon

class DiaryViewModel: ObservableObject {
    @Published var diaryEntries: [DiaryEntry] = []
    @Published var currentEntry: DiaryEntry?
    // 添加模型状态追踪
    @Published var modelLoadingState: ModelLoadingState = .unknown
    
    private let dataManager = DiaryDataManager.shared
    // 只保留一个 queue 声明
    private let queue = DispatchQueue(label: "com.mlc-llm.DiaryViewModel", attributes: .concurrent)
    
    enum ModelLoadingState {
        case unknown, loading, loaded, failed(Error)
    }
    
    init() {
        loadEntries()
    }
    
    func loadEntries() {
        let loadedEntries = dataManager.loadDiaryEntries().sorted(by: { $0.date > $1.date })
        
        // 只有当数据真正变化时才更新和通知
        let needsUpdate = diaryEntries.count != loadedEntries.count || 
                         zip(diaryEntries, loadedEntries).contains { $0.0.id != $0.1.id }
        
        if needsUpdate {
            diaryEntries = loadedEntries
            objectWillChange.send()
        }
    }
    
    // 添加适当的内存管理
    func addEntry(title: String, content: String, audioURL: URL?) {
        // 使用正确的初始化方式（自动生成 id 和 date）
        let newEntry = DiaryEntry(
            title: title, 
            content: content, 
            audioURL: audioURL
        )
        
        // 确保在主线程上更新UI相关属性
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.diaryEntries.insert(newEntry, at: 0)
            self.saveEntries()
            self.objectWillChange.send()
        }
    }
    
    // 删除这里的重复声明
    // private let queue = DispatchQueue(label: "com.mlc-llm.DiaryViewModel", attributes: .concurrent)
    
    func updateEntry(_ entry: DiaryEntry) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if let index = self.diaryEntries.firstIndex(where: { $0.id == entry.id }) {
                self.diaryEntries[index] = entry
                self.saveEntries()
                
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    func deleteEntry(_ entry: DiaryEntry) {
        diaryEntries.removeAll(where: { $0.id == entry.id })
        saveEntries()
        
        // 删除关联的音频文件
        if let audioURL = entry.audioURL {
            do {
                try FileManager.default.removeItem(at: audioURL)
            } catch {
                print("删除音频文件失败: \(error.localizedDescription)")
                // 可以考虑记录失败的文件，以便后续清理
            }
        }
        objectWillChange.send()
    }
    
    private func saveEntries() {
        // 创建备份
        let backupEntries = diaryEntries
        
        do {
            try dataManager.saveDiaryEntries(diaryEntries)
        } catch {
            print("保存日记条目失败: \(error.localizedDescription)")
            // 恢复到备份数据
            diaryEntries = backupEntries
            // 尝试再次保存或通知用户
        }
    }
    
    // 添加模型加载状态检查方法
    func checkModelLoadingState(llm: LLMEvaluator, appManager: AppManager) {
        // 检查模型是否已安装
        let modelName = MLXLMCommon.ModelConfiguration.defaultModel.name
        let isModelInstalled = appManager.installedModels.contains(modelName)
        
        if !isModelInstalled {
            modelLoadingState = .unknown
            return
        }
        
        // 使用非隔离方法获取加载状态
        Task { @MainActor in
            // 在主线程上下文中访问 loadState
            switch llm.loadState {
            case .idle:
                // 模型已安装但未加载，尝试加载
                modelLoadingState = .loading
                do {
                    try await llm.load(modelName: modelName)
                    modelLoadingState = .loaded
                } catch {
                    modelLoadingState = .failed(error)
                    print("模型加载失败: \(error.localizedDescription)")
                }
            case .loaded:
                modelLoadingState = .loaded
            }
        }
    }
}
