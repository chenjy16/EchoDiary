
import SwiftUI
import MLXLLM

@main
struct EchoDiaryApp: App {
    
    
    @StateObject var appManager = AppManager()
    
    @State var llm = LLMEvaluator()

    init() {
        UITableView.appearance().separatorStyle = .none
        UITableView.appearance().tableFooterView = UIView()
    }

    var body: some Scene {
        WindowGroup {
            StartView()
                .preferredColorScheme(.light) // 统一颜色方案
                .modelContainer(for: [Thread.self, Message.self])
                .environmentObject(appManager)
                .environment(llm)
                .environment(DeviceStat())

        }
    }
}



