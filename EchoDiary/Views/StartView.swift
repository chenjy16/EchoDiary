import SwiftUI
import MarkdownUI
import MLXLMCommon
import SwiftData

// MARK: - 颜色主题
struct ThemeColors {
    let accent = "#4A90E2"      // 更现代的蓝色
    let primary = "#F5F9FF"     // 更柔和的背景色
    let lightBlue = "#EDF2FC"   // 更细腻的渐变色
    let white = "#FFFFFF"
    let darkGray = "#2C3E50"    // 更深邃的文字颜色
    let shadowColor = "#00000010" // 阴影颜色
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - 背景视图
struct BackgroundView: View {
    let themeColors: ThemeColors
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: themeColors.primary),
                Color(hex: themeColors.lightBlue)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Logo视图
struct LogoView: View {
    var body: some View {
        HStack {

            Text("EchoDiary")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - 标签栏视图
struct TabBarView: View {
    @Binding var selectedTab: Int
    let themeColors: ThemeColors
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "Voice Notes", icon: "mic.fill", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabButton(title: "Mind Insight", icon: "brain.head.profile", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            TabButton(title: "About", icon: "info.circle.fill", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .background(Color(hex: themeColors.white))  // 使用主题中的白色
        .cornerRadius(24)  // 保持圆角
        .shadow(color: Color(hex: themeColors.shadowColor), radius: 8, x: 0, y: 2)  // 使用主题阴影颜色
        .padding(.horizontal, 20)  // 保持水平内边距
    }
}

// MARK: - 标签按钮
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(isSelected ? .blue : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - 设备不支持视图
struct DeviceNoSupportedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Device Not Supported")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your device does not support Metal 3 and cannot run the AI models of this application.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding()
    }
}

// MARK: - 主视图
struct StartView: View {

    @State private var selectedTab: Int = 0
    @State private var isEnabled: Bool = true
    
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    
    @State var isPromptFocused: Bool = false
    @State private var showOnboarding = false
    @State private var showSettings = false
    @State private var showChats = false
    @State private var currentThread: Thread?
    
    // 添加模型安装视图的状态
    @State var selectedModel = MLXLMCommon.ModelConfiguration.defaultModel
    let suggestedModel = MLXLMCommon.ModelConfiguration.defaultModel
    @State private var deviceSupportsMetal3: Bool = true
    
    private let themeColors = ThemeColors()
    @StateObject private var viewModel = DiaryViewModel()

    
    var filteredModels: [MLXLMCommon.ModelConfiguration] {
        MLXLMCommon.ModelConfiguration.availableModels
            .filter { !appManager.installedModels.contains($0.name) }
            .filter { model in
                !(appManager.installedModels.isEmpty && model.name == suggestedModel.name)
            }
            .sorted { $0.name < $1.name }
    }
    
    func checkModels() {
        // 自动选择第一个可用模型
        if appManager.installedModels.contains(suggestedModel.name) {
            if let model = filteredModels.first {
                selectedModel = model
            }
        }
    }
    
    func checkMetal3Support() {
        if let device = MTLCreateSystemDefaultDevice() {
            deviceSupportsMetal3 = device.supportsFamily(.metal3)
        }
    }
    
    func dismissOnboarding() {
        isPromptFocused = true
    }
    
    
    // MARK: - 主体视图
    var body: some View {
        NavigationStack {
            ZStack {
                // 渐变背景
                BackgroundView(themeColors: themeColors)
                
                VStack(spacing: 0) {
                    // 主内容区域
                    mainContent
                        .padding(.bottom, 8) // 添加底部内边距
                  
                }
            }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            // 渐变背景
            BackgroundView(themeColors: themeColors)
                .ignoresSafeArea()
            
            // 使用 GeometryReader 获取屏幕尺寸
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Logo 区域
                    LogoView()
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // 根据选项卡显示不同内容
                    if selectedTab == 0 {
                        // 直接使用 NavigationView 包装 DiaryListView
                        NavigationView {
                            DiaryListView(viewModel: viewModel)
                                .navigationBarTitle("Voice Diary", displayMode: .inline)
                        }
                        .navigationViewStyle(StackNavigationViewStyle())
                    } else if selectedTab == 1 {
                        behaviorTabContent
                    } else {
                        aboutTabContent
                    }
                    
                    // 添加底部空间，为标签栏留出位置
                    Spacer(minLength: 80) // 确保内容不会被底部标签栏遮挡
                }
                
                // 底部标签栏，固定在底部
                VStack(spacing: 0) {
                    Spacer() // 将标签栏推到底部
                    
                    TabBarView(selectedTab: $selectedTab, themeColors: themeColors)
                        .padding(.bottom, UIApplication.shared.windows.first?.safeAreaInsets.bottom == 0 ? 16 : 8)
                        // 根据是否有安全区域调整底部间距
                }
                .ignoresSafeArea(edges: .bottom) // 忽略底部安全区域，确保标签栏可以延伸到屏幕底部
            }
        }
    }
    
   
    
    // 行为标签内容
    @ViewBuilder
    private var behaviorTabContent: some View {
        Section {
            ZStack {
                if deviceSupportsMetal3 {
                    behaviorTabSupportedContent
                } else {
                    DeviceNoSupportedView()
                }
            }
            .onAppear {
                checkMetal3Support()
            }
            
            // 聊天入口部分 - 优化间距和对齐
            if !appManager.installedModels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chat")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        .padding(.bottom, 2)
                    
                    NavigationLink(destination: chatSection) {
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start New Conversation")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .shadow(color: Color(hex: themeColors.shadowColor), radius: 4, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 20)  // 增加顶部内边距
                .padding(.horizontal, 16)  // 增加水平内边距
                .padding(.bottom, 12)  // 增加底部内边距
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
    
    private var behaviorTabSupportedContent: some View {
        VStack(spacing: 20) {  // 增加间距
            // 已安装模型部分
            if appManager.installedModels.count > 0 {
                installedModelsSection
            } else {
                // 推荐模型部分
                suggestedModelSection
            }
            
            // 其他模型部分
            if filteredModels.count > 0 {
                otherModelsSection
            }
        }
        .padding(.horizontal, 16)  // 增加水平内边距
        .padding(.vertical, 12)    // 增加垂直内边距
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: OnboardingDownloadingModelProgressView(showOnboarding: $showOnboarding, selectedModel: $selectedModel)) {
                    Text("Install")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)  // 增加水平内边距
                        .padding(.vertical, 10)    // 增加垂直内边距
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(filteredModels.isEmpty ? Color.gray : Color.blue)
                        )
                }
                .disabled(filteredModels.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
        .task {
            checkModels()
        }
    }
    

    
    private var installedModelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Installed")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.leading, 8)  // 增加左侧内边距
                .padding(.bottom, 4)   // 减少底部内边距
            
            VStack(spacing: 12) {  // 增加间距
                ForEach(appManager.installedModels, id: \.self) { modelName in
                    let model = MLXLMCommon.ModelConfiguration.getModelByName(modelName)
                    HStack(spacing: 16) {  // 增加元素间距
                        // 使用checkmark.circle.fill表示已安装
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 22))  // 增大图标
                            .frame(width: 28, height: 28)  // 增大图标容器
                        
                        VStack(alignment: .leading, spacing: 6) {  // 增加文本间距
                              Text(appManager.modelDisplayName(modelName))
                                  .font(.system(size: 16, weight: .medium))
                                  .foregroundColor(.primary)
                              
                              Text(modelName)
                                  .font(.system(size: 12))
                                  .foregroundColor(.secondary)
                                  .lineLimit(1)
                          }
                        
                        Spacer()
                        
                        // 显示模型大小
                        if let size = model?.modelSize {
                            Text("\(size) GB")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)  // 增加水平内边距
                                .padding(.vertical, 6)     // 增加垂直内边距
                                .background(
                                    RoundedRectangle(cornerRadius: 10)  // 增加圆角
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                        
                        // 显示当前使用的模型
                        if appManager.currentModelName == modelName {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 18))  // 增大图标
                                .padding(.leading, 4)     // 增加左侧内边距
                        }
                    }
                    .padding(.vertical, 16)  // 增加垂直内边距
                    .padding(.horizontal, 20)  // 增加水平内边距
                    .background(
                        RoundedRectangle(cornerRadius: 16)  // 增加圆角
                            .fill(appManager.currentModelName == modelName ? Color.blue.opacity(0.1) : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)  // 增加圆角
                            .stroke(appManager.currentModelName == modelName ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                    )
                    .onTapGesture {
                        // 保存旧模型名称，以便切换失败时回滚
                        let oldModelName = appManager.currentModelName
                        withAnimation {
                            appManager.currentModelName = modelName
                            // 添加异步任务并处理可能的错误
                            Task {
                                if let model = MLXLMCommon.ModelConfiguration.getModelByName(modelName) {
                                    // 显示加载指示器或禁用UI
                                    isEnabled = false
                                    await llm.switchModel(model)
                                    // 切换成功后恢复UI
                                    isEnabled = true
                                    // 添加成功提示
                                    appManager.playHaptic()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 推荐模型部分 - 优化布局
    private var suggestedModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                .padding(.bottom, 2)
            
            modelSelectionButton(model: suggestedModel, isSelected: selectedModel.name == suggestedModel.name)
        }
    }

    // 其他模型部分 - 优化布局
    private var otherModelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Others")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                .padding(.bottom, 2)
            
            VStack(spacing: 8) {
                ForEach(filteredModels, id: \.name) { model in
                    modelSelectionButton(model: model, isSelected: selectedModel.name == model.name)
                }
            }
        }
    }

    // 模型选择按钮 - 优化布局
    private func modelSelectionButton(model: MLXLMCommon.ModelConfiguration, isSelected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedModel = model
            }
        } label: {
            HStack(spacing: 12) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 20))
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appManager.modelDisplayName(model.name))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(model.name)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 显示模型大小
                if let size = model.modelSize {
                    Text("\(size) GB")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 关于标签内容
    private var aboutTabContent: some View {
        Section {
            AboutView()
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    // 聊天部分
    var chatSection: some View {
        ChatView(
            currentThread: $currentThread,
            isPromptFocused: $isPromptFocused,
            showChats: $showChats,
            showSettings: $showSettings
        )
        .environmentObject(appManager)
        .environment(llm)
        .task {
            isPromptFocused = false
            if let modelName = appManager.currentModelName {
                if let model = MLXLMCommon.ModelConfiguration.getModelByName(modelName) {
                    await llm.switchModel(model)
                }
            }
        }
        .background(Color(hex: themeColors.white))
        .fontDesign(appManager.appFontDesign.getFontDesign())
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
        .fontWidth(appManager.appFontWidth.getFontWidth())
        .gesture(appManager.userInterfaceIdiom == .phone ?
            DragGesture()
                .onChanged { gesture in
                    if !showChats && gesture.startLocation.x < 20 && gesture.translation.width > 100 {
                        appManager.playHaptic()
                        showChats = true
                    }
                } : nil)
        .sheet(isPresented: $showChats) {
            ChatsListView(
                currentThread: $currentThread,
                isPromptFocused: $isPromptFocused
            )
            .environmentObject(appManager)
            .presentationDragIndicator(.hidden)
            .if(appManager.userInterfaceIdiom == .phone) { view in
                view.presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(currentThread: $currentThread)
                .environmentObject(appManager)
                .environment(llm)
                .presentationDragIndicator(.hidden)
                .if(appManager.userInterfaceIdiom == .phone) { view in
                    view.presentationDetents([.medium])
                }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: dismissOnboarding) {
            OnboardingView(showOnboarding: $showOnboarding)
                .environment(llm)
                .interactiveDismissDisabled(appManager.installedModels.isEmpty)
        }
    }
    

    


}

// MARK: - View 扩展
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
