import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // 定义支持的音频类型
        let supportedTypes: [UTType] = [
            .audio,
            .mpeg4Audio,
            .wav,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "mp3") ?? .audio,
            UTType(filenameExtension: "caf") ?? .audio,
            UTType(filenameExtension: "aac") ?? .audio,
            UTType(filenameExtension: "aiff") ?? .audio,
            UTType(filenameExtension: "aifc") ?? .audio,
            UTType(filenameExtension: "amr") ?? .audio,
            UTType(filenameExtension: "mp4") ?? .audio,
            UTType(filenameExtension: "m4v") ?? .audio  // 有些语音备忘录可能以视频格式保存
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // 获取文件的安全访问权限
            guard url.startAccessingSecurityScopedResource() else {
                print("无法获取文件访问权限")
                return
            }
            
            // 确保在完成后释放访问权限
            defer { url.stopAccessingSecurityScopedResource() }
            
            parent.onPick(url)
        }
    }
}