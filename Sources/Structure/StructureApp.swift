import AppKit
import SwiftUI

final class StructureAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openStructureWindow()
        }
        return true
    }
}

func openStructureWindow() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
}

@main
struct StructureApp: App {
    @NSApplicationDelegateAdaptor(StructureAppDelegate.self) private var appDelegate
    @StateObject private var model = EntryListModel()

    var body: some Scene {
        WindowGroup("Structure") {
            EntryStreamView(model: model)
                .frame(minWidth: 620, minHeight: 520)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Window") {
                    openStructureWindow()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Entry") {
                    model.createEntry()
                }
                .keyboardShortcut("e", modifiers: [.command])
            }
        }
    }
}
