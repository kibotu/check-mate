import SwiftUI
import Orchard

@main
struct BridgeSampleApp: App {
    
    init () {
        let consoleLogger = ConsoleLogger()
        consoleLogger.showTimesStamp = false
        consoleLogger.showInvocation = true
        Orchard.loggers.append(consoleLogger)
    }
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
