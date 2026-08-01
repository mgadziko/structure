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

@MainActor
func findPanel(for model: EntryListModel) {
    let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    input.stringValue = model.findText
    input.placeholderString = "Find"

    let alert = NSAlert()
    alert.messageText = "Find"
    alert.informativeText = "Search the current View from the current cursor position."
    alert.accessoryView = input
    alert.addButton(withTitle: "Find Next")
    alert.addButton(withTitle: "Cancel")
    alert.window.initialFirstResponder = input

    if alert.runModal() == .alertFirstButtonReturn {
        model.findNext(input.stringValue)
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
    @State private var viewZoomScale: CGFloat = 1.0

    var body: some Scene {
        WindowGroup("Structure") {
            EntryStreamView(model: model, viewScale: viewZoomScale)
                .frame(minWidth: 620, minHeight: 520)
                .background(WindowTitleSetter(title: model.windowTitle))
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Structure") {
                    AboutBoxController.shared.show()
                }
            }

            CommandGroup(after: .pasteboard) {
                Button("Find") {
                    findPanel(for: model)
                }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(!model.hasOpenLibrary || !model.hasOpenView)
            }

            CommandGroup(after: .toolbar) {
                Button("Zoom In") {
                    viewZoomScale = min(viewZoomScale + 0.1, 2.0)
                }
                .keyboardShortcut("+", modifiers: [.command])
                .disabled(viewZoomScale >= 2.0)

                Button("Zoom Out") {
                    viewZoomScale = max(viewZoomScale - 0.1, 0.7)
                }
                .keyboardShortcut("-", modifiers: [.command])
                .disabled(viewZoomScale <= 0.7)
            }

            CommandGroup(replacing: .newItem) {
                Button("New Library") {
                    newLibraryPanel(for: model)
                }

                Button("Open Library") {
                    openLibraryPanel(for: model)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Menu("Open Recent Library") {
                    ForEach(model.recentLibraryURLs, id: \.path) { url in
                        Button(libraryMenuTitle(for: url)) {
                            model.openLibrary(at: url)
                        }
                        .disabled(model.activeLibraryURL?.path == url.path)
                    }
                }
                .disabled(model.recentLibraryURLs.isEmpty)

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

@MainActor
final class AboutBoxController {
    static let shared = AboutBoxController()

    private var panel: NSPanel?

    func show() {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 552, height: 300),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.contentView = NSHostingView(rootView: AboutBoxView())
        self.panel = panel

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AboutBoxView: View {
    private var versionText: String {
        if let buildTimestamp = Bundle.main.object(forInfoDictionaryKey: "StructureBuildTimestamp") as? String,
           !buildTimestamp.isEmpty {
            return "Version: \(buildTimestamp)"
        }

        return "Version: Development"
    }

    var body: some View {
        ZStack {
            AboutVisualEffectBackground()

            VStack(alignment: .leading, spacing: 0) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .padding(.bottom, 22)

                Text("Structure")
                    .font(.headline.weight(.semibold))
                    .padding(.bottom, 4)

                Text(versionText)
                    .font(.body)
                    .padding(.bottom, 14)

                Text("Frictionless capture for structure-it-later thinking.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 14)

                Text("©2026 Mark Gadzikowski. All Rights Reserved Worldwide.")
                    .font(.body.weight(.semibold))
                    .padding(.bottom, 2)

                Text("Contact: structure@quantumpenguin.net")
                    .font(.body)
                    .padding(.top, 18)

                Spacer()

                HStack {
                    Spacer()
                    Button("OK") {
                        NSApp.keyWindow?.close()
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .frame(width: 228)
                    Spacer()
                }
            }
            .foregroundStyle(.primary)
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 552, height: 300)
    }
}

struct AboutVisualEffectBackground: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.state = .active
    }
}

private func libraryMenuTitle(for url: URL) -> String {
    let defaultURL = try? EntryStore.defaultDatabaseURL
    let legacyDefaultURL = try? EntryStore.legacyDefaultDatabaseURL
    if url.path == defaultURL?.path || url.path == legacyDefaultURL?.path {
        return "Initial Library"
    }
    return url.deletingPathExtension().lastPathComponent
}

private struct WindowTitleSetter: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.title = title
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            view.window?.title = title
        }
    }
}
