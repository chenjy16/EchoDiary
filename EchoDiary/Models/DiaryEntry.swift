import Foundation

struct DiaryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var date: Date
    var audioURL: URL?

    
    // 实现 Equatable 协议
    static func == (lhs: DiaryEntry, rhs: DiaryEntry) -> Bool {
        return lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.content == rhs.content &&
        lhs.date == rhs.date &&
        lhs.audioURL == rhs.audioURL

    }
    
    // 将初始化方法移到结构体内部
    init(title: String, content: String, audioURL: URL? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.date = Date()
        self.audioURL = audioURL
    }
}
