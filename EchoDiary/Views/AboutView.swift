import SwiftUI
import StoreKit


struct AboutView: View {
    
    
    private var appVersion: String {
        
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    @State private var showingPurchaseHistory = false
    
    var body: some View {
        NavigationStack {
            List {
                appInfoSection
            }
            .navigationBarTitleDisplayMode(.inline)

        }
    }
    
    // MARK: - View Components
    
    private var appInfoSection: some View {
        
        
        Section(header: Text("App Info")) {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundColor(.gray)
            }
        }
        
        
    }
    
}
