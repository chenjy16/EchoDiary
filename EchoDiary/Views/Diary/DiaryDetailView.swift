import SwiftUI
import AVFoundation

struct DiaryDetailView: View {
    @State var entry: DiaryEntry
    @ObservedObject var viewModel: DiaryViewModel
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedContent: String = ""
    @StateObject private var audioPlayerManager = AudioPlayerManager()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isEditing {
                    TextField("Title", text: $editedTitle)
                        .font(.title)
                        .padding(.horizontal)
                    
                    TextEditor(text: $editedContent)
                        .frame(minHeight: 200)
                        .padding(.horizontal)
                } else {
                    Text(entry.title)
                        .font(.title)
                        .padding(.horizontal)
                    
                    Text(entry.date, style: .date)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    if let audioURL = entry.audioURL, FileManager.default.fileExists(atPath: audioURL.path) {
                        Button(action: {
                            if audioPlayerManager.isPlaying {
                                audioPlayerManager.stopAudio()
                            } else {
                                audioPlayerManager.playAudio(url: audioURL)
                            }
                        }) {
                            HStack {
                                Image(systemName: audioPlayerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                Text(audioPlayerManager.isPlaying ? "Pause Recording" : "Play Recording")
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    
                    Text(entry.content)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
        }
        .onDisappear {
            audioPlayerManager.stopAudio()
        }
    }
    
    private func startEditing() {
        editedTitle = entry.title
        editedContent = entry.content
        isEditing = true
    }
    
    private func saveChanges() {
        var updatedEntry = entry
        updatedEntry.title = editedTitle
        updatedEntry.content = editedContent
        
        viewModel.updateEntry(updatedEntry)
        entry = updatedEntry
        isEditing = false
    }
}

// Create a separate class to handle audio player delegation
class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    private var audioPlayer: AVAudioPlayer?
    
    func playAudio(url: URL) {
        do {
            // 设置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("音频文件不存在: \(url.path)")
                return
            }
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay() // 添加预加载
            let success = audioPlayer?.play() ?? false
            print("开始播放音频: \(url.path), 播放状态: \(success)")
            isPlaying = success
        } catch {
            print("播放音频失败: \(error.localizedDescription)")
        }
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
