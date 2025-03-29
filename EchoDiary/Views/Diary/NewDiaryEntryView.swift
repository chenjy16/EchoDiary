import SwiftUI


struct NewDiaryEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var audioVM = AudioViewModel()
    @ObservedObject var viewModel: DiaryViewModel
    
    // Modification: Add a default title with date and time format
    @State private var title: String = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: Date())
    }()
    @State private var content = ""
    
    var body: some View {
        NavigationView {
            // Extract form content to a separate view
            DiaryEntryFormContent(
                title: $title,
                content: $content,
                audioVM: audioVM,
                viewModel: viewModel,
                presentationMode: presentationMode
            )
            .navigationTitle("New Diary Entry")
        }
        .onAppear {
            // Clear previous transcription content
            audioVM.transcribedText = nil
        }
    }
}

// Break down the complex view into smaller components
struct DiaryEntryFormContent: View {
    @Binding var title: String
    @Binding var content: String
    @ObservedObject var audioVM: AudioViewModel
    var viewModel: DiaryViewModel
    var presentationMode: Binding<PresentationMode>
    
    // 添加文档选择器状态
    @State private var showDocumentPicker = false
    
    // 添加错误提示状态
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 将 showErrorAlert 方法移动到这里 - 结构体内部
    func showErrorAlert(message: String) {
        errorMessage = message
        showError = true
    }
    
    var body: some View {
        Form {
            Section(header: Text("Diary Title")) {
                TextField("Enter Title", text: $title)
            }
            
            // Language settings section
            languageSettingsSection
            
            // Recording section
            recordingSection
            
            Section(header: Text("Diary Content")) {
                TextEditor(text: $content)
                    .frame(minHeight: 200)
                    .onChange(of: audioVM.transcribedText) { newValue in
                        if let text = newValue, !text.isEmpty {
                            content = text
                        }
                    }
            }
        }
        .navigationBarItems(
            leading: cancelButton,
            trailing: saveButton
        )
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // Extract sections into computed properties
    var languageSettingsSection: some View {
        Section(header: Text("Speech Settings")) {
            Picker("Recognition Language", selection: $audioVM.selectedLanguage) {
                ForEach(AudioViewModel.WhisperLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if !audioVM.checkModelAvailability() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Speech recognition model files are missing. Please ensure the required model files are added.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // 修复 recordingSection 实现 - 添加缺少的闭合括号
    // 修改 recordingSection 实现，添加进度显示
    var recordingSection: some View {
        Section(header: Text("录音")) {
            recordButton
            
            // 添加导入音频按钮
            if !audioVM.isRecording {
                Button(action: {
                    showDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("导入音频文件")
                    }
                }
                .sheet(isPresented: $showDocumentPicker) {
                    DocumentPicker { url in
                        audioVM.importAudio(from: url) { result in
                            switch result {
                            case .success(let text):
                                self.content = text
                                self.audioVM.transcribedText = text
                            case .failure(let error):
                                // 添加错误提示
                                self.showErrorAlert(message: "导入音频失败: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
            
            // 现有的录音状态指示器
            if audioVM.isRecording || audioVM.isProcessing {
                if audioVM.isProcessing {
                    VStack {
                        HStack {
                            Spacer()
                            Text("正在转录音频...")
                            Spacer()
                        }
                        
                        // 添加进度条
                        if audioVM.conversionProgress > 0 {
                            ProgressView(value: audioVM.conversionProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.vertical, 8)
                            
                            // 添加进度百分比显示
                            Text("\(Int(audioVM.conversionProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            ProgressView()
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Display real-time transcription prompt
                if audioVM.isIncrementalTranscribing,
                   let text = audioVM.transcribedText,
                   !text.isEmpty {
                    Text("实时转录进行中...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
    }
    
    // 添加 recordButton 实现
    var recordButton: some View {
        Button(action: {
            audioVM.toggleRecording()
        }) {
            HStack {
                Image(systemName: audioVM.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(audioVM.isRecording ? .red : .blue)
                Text(audioVM.isRecording ? "停止录音" : "开始录音")
            }
        }
    }
    
    // 添加 cancelButton 实现
    var cancelButton: some View {
        Button("取消") {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // 添加 saveButton 实现
    var saveButton: some View {
        Button("保存") {
            // 保存日记条目
            viewModel.addEntry(title: title, content: content, audioURL: audioVM.recordingURL)
            presentationMode.wrappedValue.dismiss()
        }
        .disabled(title.isEmpty || content.isEmpty)
    }
}

// Add checkModelAvailability method to AudioViewModel if it doesn't exist
extension AudioViewModel {
    func checkModelAvailability() -> Bool {
        let modelNames = WhisperLanguage.allCases.map { $0.modelName }
        
        for modelName in modelNames {
            // Try multiple possible paths
            let modelExists = Bundle.main.url(forResource: modelName, withExtension: "bin") != nil ||
                             Bundle.main.url(forResource: modelName, withExtension: "bin", subdirectory: "Resources") != nil
            
            if !modelExists {
                print("Warning: Model file \(modelName).bin not found.")
                return false
            }
        }
        
        return true
    }
}

