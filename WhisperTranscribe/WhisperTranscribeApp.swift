import SwiftUI
import AppKit

@main
struct WhisperTranscribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var queue = TranscriptionQueue()
    @AppStorage("setupCompleted") private var setupCompleted = false
    @State private var showSetup = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showSetup {
                    SetupView {
                        showSetup = false
                        setupCompleted = true
                    }
                } else {
                    ContentView(queue: queue)
                        .frame(minWidth: 900, minHeight: 600)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                if !setupCompleted || !SystemInfo.hasMlxWhisper || !SystemInfo.isAppleSilicon {
                    showSetup = true
                }
            }
        }
        .onChange(of: queue.isRunning) { _, _ in
            appDelegate.queue = queue
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Setup & Dipendenze") { showSetup = true }
                    .keyboardShortcut(",", modifiers: [.command, .shift])
            }
        }
    }
}


final class AppDelegate: NSObject, NSApplicationDelegate {
    var queue: TranscriptionQueue?
    func applicationWillTerminate(_ notification: Notification) {
        queue?.stopQueue()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        p.arguments = ["-9", "-f", "mlx_whisper"]
        try? p.run()
        p.waitUntilExit()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
