import AppKit
import SwiftUI
import UniformTypeIdentifiers

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

@MainActor
func openLibraryPanel(for model: EntryListModel) {
    let panel = NSOpenPanel()
    panel.title = "Open Structure Library"
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = structureLibraryContentTypes

    if panel.runModal() == .OK, let url = panel.url {
        model.openLibrary(at: url)
    }
}

@MainActor
func newLibraryPanel(for model: EntryListModel) {
    let panel = NSSavePanel()
    panel.title = "New Structure Library"
    panel.nameFieldStringValue = "Untitled.structurelibrary"
    panel.allowedContentTypes = structureLibraryContentTypes
    panel.canCreateDirectories = true

    if panel.runModal() == .OK, let url = panel.url {
        model.createLibrary(at: url)
    }
}

private var structureLibraryContentTypes: [UTType] {
    [
        UTType(filenameExtension: "structurelibrary"),
        UTType(filenameExtension: "sqlite")
    ].compactMap { $0 }
}

@MainActor
func openViewSelectionPanel(for model: EntryListModel) {
    let selector = ViewSelectionController(views: model.views)
    let alert = NSAlert()
    alert.messageText = "Open View"
    alert.informativeText = "Choose a View from the current Library."
    alert.accessoryView = selector.scrollView
    alert.addButton(withTitle: "Open")
    alert.addButton(withTitle: "Cancel")

    if alert.runModal() == .alertFirstButtonReturn, let viewID = selector.selectedViewID {
        model.openView(id: viewID)
    }
}

private final class ViewSelectionController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let views: [StructureView]
    let scrollView: NSScrollView
    private let tableView = NSTableView()

    var selectedViewID: StructureView.ID? {
        let row = tableView.selectedRow
        guard row >= 0, row < views.count else { return nil }
        return views[row].id
    }

    init(views: [StructureView]) {
        self.views = views.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 280, height: 180))
        super.init()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("View"))
        column.title = "View"
        column.width = 260
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false
        if !self.views.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        views.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ViewCell")
        let textField = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
        textField.identifier = identifier
        textField.stringValue = views[row].title
        return textField
    }
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
            CommandGroup(replacing: .newItem) {
                Button("New Library") {
                    newLibraryPanel(for: model)
                }

                Button("Open Library") {
                    openLibraryPanel(for: model)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Close Library") {
                    model.closeLibrary()
                }
                .disabled(!model.hasOpenLibrary)

                Divider()

                Button("New View") {
                    model.createView()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(!model.hasOpenLibrary)

                if model.views.count <= 7 {
                    Menu("Open View") {
                        ForEach(model.views) { view in
                            Button(view.title) {
                                model.openView(id: view.id)
                            }
                            .disabled(model.activeView?.id == view.id)
                        }
                    }
                    .disabled(!model.hasOpenLibrary || model.views.isEmpty)
                } else {
                    Button("Open View...") {
                        openViewSelectionPanel(for: model)
                    }
                    .disabled(!model.hasOpenLibrary || model.views.isEmpty)
                }

                Button("Close View") {
                    model.closeView()
                }
                .keyboardShortcut("w", modifiers: [.command])
                .disabled(!model.hasOpenView)

                Divider()

                Button("New Entry") {
                    model.createEntry()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(!model.hasOpenLibrary || !model.hasOpenView)
            }
        }
    }
}
