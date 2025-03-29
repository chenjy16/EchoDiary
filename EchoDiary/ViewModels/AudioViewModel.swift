import Foundation
import AudioKit
import SwiftWhisper
import AVFoundation
import Speech

// 在 AudioViewModel 类中添加以下属性
class AudioViewModel: NSObject, ObservableObject {
    
    
    enum WhisperLanguage: String, CaseIterable, Identifiable {
        case english = "en"
        case chinese = "zh"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .chinese: return "Chinese"
            }
        }
        
        var localeIdentifier: String {
            switch self {
            case .english: return "en-US"
            case .chinese: return "zh-CN"
            }
        }
        
        var modelName: String {
            switch self {
            case .english: return "tiny.en"
            case .chinese: return "tiny" // 使用通用模型支持中文
            }
        }
    }
    
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var transcribedText: String?
    @Published var isProcessing = false
    @Published var isIncrementalTranscribing = false
    
    // 添加语言选择相关属性
    @Published var selectedLanguage: WhisperLanguage = .english
    
    private var audioRecorder: AVAudioRecorder?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    // 现有的转录方法
    // 添加进度属性
    @Published var conversionProgress: Float = 0
    
    // 修改 convertAudioFileToPCMArray 方法以支持进度显示
    func convertAudioFileToPCMArray(fileURL: URL, progressHandler: @escaping (Float) -> Void, completionHandler: @escaping (Result<[Float], Error>) ->Void) {
        // 使用后台队列处理音频转换
        DispatchQueue.global(qos: .userInitiated).async {
            // 报告初始进度
            DispatchQueue.main.async {
                progressHandler(0.1)
            }
            
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                DispatchQueue.main.async {
                    completionHandler(.failure(NSError(domain: "AudioConversion", code: 0, userInfo: [NSLocalizedDescriptionKey: "音频文件不存在"])))
                }
                return
            }
            
            // 获取文件类型
            let fileExtension = fileURL.pathExtension.lowercased()
            print("处理音频文件类型: \(fileExtension)")
            
            var options = FormatConverter.Options()
            options.format = .wav
            options.sampleRate = 16000
            options.bitDepth = 16
            options.channels = 1
            options.isInterleaved = false
            
            // 报告转换开始
            DispatchQueue.main.async {
                progressHandler(0.2)
            }
            
            // 创建临时文件路径
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".wav")
            let converter = FormatConverter(inputURL: fileURL, outputURL: tempURL, options: options)
            
            // 使用信号量等待转换完成
            let semaphore = DispatchSemaphore(value: 0)
            var conversionError: Error?
            
            // 添加日志以便调试
            print("开始转换音频: \(fileURL.path)")
            print("音频文件大小: \(try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] ?? 0) bytes")
            
            converter.start { error in
                if let error = error {
                    print("音频转换失败: \(error.localizedDescription)")
                    conversionError = error
                } else {
                    print("音频转换成功")
                }
                semaphore.signal()
            }
            
            // 等待转换完成
            semaphore.wait()
            
            // 报告转换完成
            DispatchQueue.main.async {
                progressHandler(0.4)
            }
            
            if let error = conversionError {
                DispatchQueue.main.async {
                    print("返回转换错误: \(error.localizedDescription)")
                    completionHandler(.failure(error))
                }
                return
            }
            
            do {
                // 检查临时文件是否存在
                if !FileManager.default.fileExists(atPath: tempURL.path) {
                    throw NSError(domain: "AudioConversion", code: 1, userInfo: [NSLocalizedDescriptionKey: "转换后的临时文件不存在"])
                }
                
                let data = try Data(contentsOf: tempURL)
                print("转换后的WAV文件大小: \(data.count) bytes")
                
                // 报告数据处理开始
                DispatchQueue.main.async {
                    progressHandler(0.6)
                }
                
                // 确保数据长度足够包含WAV头部
                guard data.count > 44 else {
                    throw NSError(domain: "AudioConversion", code: 2, userInfo: [NSLocalizedDescriptionKey: "转换后的音频数据太短"])
                }
                
                // 预分配内存以提高性能
                let expectedSize = (data.count - 44) / 2
                var floats = [Float]()
                floats.reserveCapacity(expectedSize)
                
                // 使用更高效的数据处理方式
                for i in stride(from: 44, to: data.count, by: 2) {
                    if i + 2 <= data.count {
                        let value = data[i..<i+2].withUnsafeBytes {
                            let short = Int16(littleEndian: $0.load(as: Int16.self))
                            return max(-1.0, min(Float(short) / 32767.0, 1.0))
                        }
                        floats.append(value)
                    }
                    
                    // 每处理10%的数据更新一次进度
                    if i % (data.count / 10) < 2 {
                        let progress = 0.6 + 0.3 * Float(i) / Float(data.count)
                        DispatchQueue.main.async {
                            progressHandler(progress)
                        }
                    }
                }
                
                print("成功提取PCM数据，样本数: \(floats.count)")
                
                // 清理临时文件
                try? FileManager.default.removeItem(at: tempURL)
                
                // 报告完成
                DispatchQueue.main.async {
                    progressHandler(1.0)
                    completionHandler(.success(floats))
                }
            } catch {
                print("处理WAV数据失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completionHandler(.failure(error))
                }
            }
        }
    }
    
    // 新增录音功能
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("\(Date().timeIntervalSince1970).m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            recordingURL = audioFilename
            isRecording = true
        } catch {
            print("录音失败: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        // 自动转录录音内容
        if let url = recordingURL {
            isProcessing = true
            extractTextFromAudio(url) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    switch result {
                    case .success(let text):
                        self?.transcribedText = text
                    case .failure(let error):
                        print("转录失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // 增量转录方法
    func startIncrementalTranscription() {
        // 请求语音识别权限
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if status == .authorized {
                    self.beginIncrementalTranscription()
                } else {
                    // 回退到普通录音
                    self.startRecording()
                }
            }
        }
    }
    
    // 修改 beginIncrementalTranscription 方法
    private func beginIncrementalTranscription() {
        isIncrementalTranscribing = true
        transcribedText = ""
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // 创建临时文件用于保存录音
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("\(Date().timeIntervalSince1970).m4a")
            recordingURL = audioFilename
            
            audioEngine = AVAudioEngine()
            
            // 创建识别请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                fatalError("无法创建语音识别请求")
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // 使用选择的语言进行识别
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage.localeIdentifier))
            
            guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
                // 回退到普通录音
                startRecording()
                return
            }
            
            // 开始识别任务
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                
                if error != nil || (result?.isFinal ?? false) {
                    self.stopIncrementalTranscription()
                }
            }
            
            // 设置音频输入
            let inputNode = audioEngine?.inputNode
            let recordingFormat = inputNode?.outputFormat(forBus: 0)
            
            // 安装音频输入 tap
            inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
                
                // 同时保存音频数据到文件（可选）
                // 这里需要额外的代码来保存音频数据
            }
            
            audioEngine?.prepare()
            try audioEngine?.start()
            
            isRecording = true
        } catch {
            // 回退到普通录音
            startRecording()
        }
    }
    
    func stopIncrementalTranscription() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isIncrementalTranscribing = false
        isRecording = false
    }
    
    // 修改现有的录音控制方法
    func toggleRecording() {
        if isRecording {
            if isIncrementalTranscribing {
                stopIncrementalTranscription()
            } else {
                stopRecording()
            }
        } else {
            // 优先使用增量转录
            startIncrementalTranscription()
        }
    }
    
    // 将importAudio方法移动到类内部
    // 更新 importAudio 方法
    func importAudio(from url: URL, completionHandler: @escaping (Result<String, Error>) -> Void) {
        isProcessing = true
        conversionProgress = 0
        
        // 复制文件到应用沙盒
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent("\(Date().timeIntervalSince1970)_imported.\(url.pathExtension)")
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // 获取文件安全访问权限
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "ImportAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法访问选择的音频文件"])
            }
            
            // 确保在完成后释放访问权限
            defer { url.stopAccessingSecurityScopedResource() }
            
            // 检查文件是否存在且可读
            if !FileManager.default.isReadableFile(atPath: url.path) {
                throw NSError(domain: "ImportAudio", code: 2, userInfo: [NSLocalizedDescriptionKey: "选择的音频文件不可读"])
            }
            
            // 打印文件信息以便调试
            print("导入音频文件: \(url.path)")
            print("文件大小: \(try FileManager.default.attributesOfItem(atPath: url.path)[.size] ?? 0) bytes")
            print("文件类型: \(url.pathExtension)")
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            recordingURL = destinationURL
            
            // 使用现有的音频转文字功能
            extractTextFromAudio(destinationURL) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    self?.conversionProgress = 0
                    completionHandler(result)
                }
            }
        } catch {
            print("导入音频失败: \(error.localizedDescription)")
            isProcessing = false
            conversionProgress = 0
            completionHandler(.failure(error))
        }
    }
    
    // 将 extractTextFromAudio 方法移动到类内部
    func extractTextFromAudio(_ audioURL: URL, completionHandler: @escaping (Result<String, Error>) ->Void) {
        // 根据选择的语言加载对应的模型
        let modelName = selectedLanguage.modelName
        
        // 尝试多种可能的路径查找模型文件
        var modelURL: URL?
        
        // 1. 首先尝试从主Bundle直接加载
        modelURL = Bundle.main.url(forResource: modelName, withExtension: "bin")
        
        // 2. 如果没找到，尝试从Resources目录加载
        if modelURL == nil {
            modelURL = Bundle.main.url(forResource: modelName, withExtension: "bin", subdirectory: "Resources")
        }
        
        // 3. 如果仍然没找到，尝试从Documents目录加载（如果用户可能下载了模型）
        if modelURL == nil {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let potentialURL = documentsPath.appendingPathComponent("\(modelName).bin")
            if FileManager.default.fileExists(atPath: potentialURL.path) {
                modelURL = potentialURL
            }
        }
        
        // 确保找到了模型文件
        guard let finalModelURL = modelURL else {
            let errorMessage = "Unable to find speech recognition model: \(modelName).bin. Please ensure the model file is added to the project."
            print(errorMessage)
            completionHandler(.failure(NSError(domain: "WhisperError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }
        
        let whisper = Whisper(fromFileURL: finalModelURL)
        
        // 重置进度
        conversionProgress = 0
        
        // 使用 [weak self] 避免强引用循环
        convertAudioFileToPCMArray(fileURL: audioURL, progressHandler: { [weak self] progress in
            // 使用可选链安全地访问 self
            self?.conversionProgress = progress
        }) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
                case .success(let success):
                    // 音频转换完成，开始转录
                    self.conversionProgress = 0.8
                    whisper.transcribe(audioFrames: success) { [weak self] result in
                        guard let self = self else { return }
                        
                        // 转录完成
                        self.conversionProgress = 1.0
                        switch result {
                        case .success(let segments):
                            let transcribedText = segments.map(\.text).joined()
                            completionHandler(.success(transcribedText))
                        case .failure(let error):
                            completionHandler(.failure(error))
                        }
                    }
                case .failure(let failure):
                    self.conversionProgress = 0
                    completionHandler(.failure(failure))
            }
        }
    }
}

extension AudioViewModel: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("录音未成功完成")
        }
    }
}




