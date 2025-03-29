import Foundation

class DiaryDataManager {
    static let shared = DiaryDataManager()
    
    private let userDefaults = UserDefaults.standard
    private let diaryEntriesKey = "diaryEntries"
    
    private init() {}
    
    func saveDiaryEntries(_ entries: [DiaryEntry]) {
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: diaryEntriesKey)
        }
    }
    
    func loadDiaryEntries() -> [DiaryEntry] {
        if let data = userDefaults.data(forKey: diaryEntriesKey),
           let entries = try? JSONDecoder().decode([DiaryEntry].self, from: data) {
            return entries.sorted(by: { $0.date > $1.date }) // 增加排序
        }
        return []
    }
    
    func saveAudioFile(audioData: Data) -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "\(UUID().uuidString).m4a"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try audioData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving audio file: \(error)")
            return nil
        }
    }
}
