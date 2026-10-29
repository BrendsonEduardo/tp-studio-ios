import SwiftUI
import UIKit

@main
struct TeleprompterStudioApp: App {
    @StateObject private var engine = BroadcastEngine()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(engine)
                .onAppear {
                    // Garante Wake Lock nativo para que a tela do iPhone (12 ao 17 Pro Max) nunca apague no ar
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}

