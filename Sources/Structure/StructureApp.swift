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
func toggleFullScreenForKeyWindow() {
    NSApp.keyWindow?.toggleFullScreen(nil)
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
func confirmDeleteActiveView(for model: EntryListModel) {
    guard let view = model.activeView else { return }

    let alert = NSAlert()
    alert.messageText = "Delete \(view.title). Are you sure?"
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "OK")
    alert.alertStyle = .warning

    if alert.runModal() == .alertSecondButtonReturn {
        model.deleteActiveView()
    }
}

@MainActor
func renameActiveViewPanel(for model: EntryListModel) {
    guard let view = model.activeView else { return }

    let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    input.stringValue = view.title

    let alert = NSAlert()
    alert.messageText = "Rename View"
    alert.informativeText = "Enter a new name for \(view.title)."
    alert.accessoryView = input
    alert.addButton(withTitle: "Rename")
    alert.addButton(withTitle: "Cancel")
    alert.window.initialFirstResponder = input

    if alert.runModal() == .alertFirstButtonReturn {
        model.renameActiveView(to: input.stringValue)
    }
}

@MainActor
func viewCriteriaPanel(for model: EntryListModel) {
    guard model.hasOpenView else { return }
    let selector = ViewCriteriaController(
        columns: model.columns,
        criteria: model.activeView?.criteria ?? [],
        valueSuggestions: model.criteriaValueSuggestions
    )

    let alert = NSAlert()
    alert.messageText = "Add/Modify Criteria"
    alert.informativeText = "Show Entries where a column matches this value."
    alert.accessoryView = selector.view
    alert.addButton(withTitle: "Apply")
    alert.addButton(withTitle: "Cancel")
    alert.window.initialFirstResponder = selector.valueField

    switch alert.runModal() {
    case .alertFirstButtonReturn:
        model.updateActiveViewCriteria(selector.criteria)
    default:
        break
    }
}

@MainActor
func saveCriteriaAsCategoryRulePanel(for model: EntryListModel) {
    guard model.canSaveActiveCriteriaAsCategoryRule else { return }

    let controller = CategoryRuleController(
        targetColumns: model.categoryRuleTargetColumns,
        defaultCategoryName: model.activeViewTitle
    )

    let alert = NSAlert()
    alert.messageText = "Save Criteria as Category Rule"
    alert.informativeText = "When Entries match this View's Criteria, fill an empty Category cell with this value."
    alert.accessoryView = controller.view
    alert.addButton(withTitle: "Save Rule")
    alert.addButton(withTitle: "Cancel")
    alert.window.initialFirstResponder = controller.categoryField

    if alert.runModal() == .alertFirstButtonReturn,
       let targetColumnID = controller.selectedTargetColumnID {
        model.saveActiveViewCriteriaAsCategoryRule(
            targetColumnID: targetColumnID,
            categoryName: controller.categoryName
        )
    }
}

@MainActor
func removeCriteriaPanel(for model: EntryListModel) {
    guard let activeView = model.activeView, !activeView.criteria.isEmpty else { return }

    let selector = CriteriaRemovalController(
        criteria: activeView.criteria,
        columns: model.columns
    )
    let alert = NSAlert()
    alert.messageText = "Remove Criteria"
    alert.informativeText = "Select the active Criteria to remove from this View."
    alert.accessoryView = selector.view
    alert.addButton(withTitle: "Remove Selected")
    alert.addButton(withTitle: "Cancel")

    if alert.runModal() == .alertFirstButtonReturn {
        model.removeActiveViewCriteria(ids: selector.selectedCriterionIDs)
    }
}

@MainActor
func showActiveCriteriaPanel(for model: EntryListModel) {
    let summaries = model.activeViewCriteriaSummaries
    let alert = NSAlert()
    alert.messageText = "Active Criteria"
    alert.informativeText = summaries.isEmpty
        ? "This View has no active Criteria."
        : summaries.joined(separator: "\n")
    alert.addButton(withTitle: "OK")
    alert.runModal()
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

private final class ViewCriteriaController: NSObject {
    let columns: [EntryColumn]
    let view: NSView
    let valueField: NSComboBox
    private var rows: [CriterionRowController] = []
    private let valueSuggestions: (EntryColumn.ID) -> [String]

    var criteria: [ViewCriterion] {
        rows.compactMap { row in
            guard !row.isRemoved else { return nil }
            guard let columnID = row.selectedColumnID else { return nil }
            let value = row.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return ViewCriterion(id: row.criterionID ?? UUID().uuidString, columnID: columnID, value: value)
        }
    }

    init(
        columns: [EntryColumn],
        criteria: [ViewCriterion],
        valueSuggestions: @escaping (EntryColumn.ID) -> [String]
    ) {
        self.columns = columns.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        self.valueSuggestions = valueSuggestions

        let rowCount = max(criteria.count + 1, 1)
        let rowHeight: CGFloat = 32
        let width: CGFloat = 420
        let height = CGFloat(rowCount) * rowHeight
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        var firstValueField: NSComboBox?
        let usedColumnIDs = Set(criteria.map(\.columnID))
        for index in 0..<rowCount {
            let criterion = index < criteria.count ? criteria[index] : nil
            let initialColumnID = criterion?.columnID ?? self.columns.first { !usedColumnIDs.contains($0.id) }?.id
            let rowFrame = NSRect(
                x: 0,
                y: height - CGFloat(index + 1) * rowHeight,
                width: width,
                height: 26
            )
            let row = CriterionRowController(
                frame: rowFrame,
                columns: self.columns,
                criterion: criterion,
                initialColumnID: initialColumnID,
                valueSuggestions: valueSuggestions
            )
            rows.append(row)
            container.addSubview(row.view)
            firstValueField = firstValueField ?? row.valueField
        }

        self.valueField = firstValueField ?? NSComboBox(frame: .zero)
        self.view = container
        super.init()
    }
}

private final class CriterionRowController: NSObject {
    let view: NSView
    let valueField: NSComboBox
    let criterionID: String?
    private(set) var isRemoved = false
    private let columns: [EntryColumn]
    private let popup: NSPopUpButton
    private let removeButton: NSButton
    private let valueSuggestions: (EntryColumn.ID) -> [String]

    var selectedColumnID: EntryColumn.ID? {
        guard popup.indexOfSelectedItem >= 0,
              popup.indexOfSelectedItem < columns.count
        else { return nil }
        return columns[popup.indexOfSelectedItem].id
    }

    var value: String {
        valueField.stringValue
    }

    init(
        frame: NSRect,
        columns: [EntryColumn],
        criterion: ViewCriterion?,
        initialColumnID: EntryColumn.ID?,
        valueSuggestions: @escaping (EntryColumn.ID) -> [String]
    ) {
        self.columns = columns
        self.criterionID = criterion?.id
        self.valueSuggestions = valueSuggestions

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 170, height: 26), pullsDown: false)
        for column in columns {
            popup.addItem(withTitle: column.title)
        }
        if let selectedColumnID = criterion?.columnID ?? initialColumnID,
           let selectedIndex = columns.firstIndex(where: { $0.id == selectedColumnID }) {
            popup.selectItem(at: selectedIndex)
        }
        popup.isEnabled = !columns.isEmpty

        let valueField = NSComboBox(frame: NSRect(x: 184, y: 2, width: 200, height: 24))
        valueField.placeholderString = "Value"
        valueField.stringValue = criterion?.value ?? ""
        valueField.completes = true
        valueField.numberOfVisibleItems = 10

        let removeButton = NSButton(frame: NSRect(x: 392, y: 1, width: 28, height: 24))
        removeButton.bezelStyle = .inline
        removeButton.image = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Remove Criterion")
        removeButton.title = ""
        removeButton.isBordered = false
        removeButton.isHidden = criterion == nil

        let rowView = NSView(frame: frame)
        rowView.addSubview(popup)
        rowView.addSubview(valueField)
        rowView.addSubview(removeButton)

        self.popup = popup
        self.valueField = valueField
        self.removeButton = removeButton
        self.view = rowView
        super.init()

        popup.target = self
        popup.action = #selector(selectedColumnChanged)
        removeButton.target = self
        removeButton.action = #selector(removeCriterion)
        reloadValueSuggestions()
    }

    @objc private func selectedColumnChanged() {
        reloadValueSuggestions()
    }

    private func reloadValueSuggestions() {
        let currentValue = valueField.stringValue
        valueField.removeAllItems()
        if let selectedColumnID {
            valueField.addItems(withObjectValues: valueSuggestions(selectedColumnID))
        }
        valueField.stringValue = currentValue
    }

    @objc private func removeCriterion() {
        isRemoved = true
        valueField.stringValue = ""
        popup.isEnabled = false
        valueField.isEnabled = false
        removeButton.isEnabled = false
        view.alphaValue = 0.35
    }
}

private final class CriteriaRemovalController: NSObject {
    let view: NSView
    private var rows: [CriteriaRemovalRow] = []

    var selectedCriterionIDs: Set<ViewCriterion.ID> {
        Set(rows.filter(\.isSelected).map(\.criterionID))
    }

    init(criteria: [ViewCriterion], columns: [EntryColumn]) {
        let columnTitlesByID = Dictionary(uniqueKeysWithValues: columns.map { ($0.id, $0.title) })
        let width: CGFloat = 420
        let listHeight: CGFloat = 170
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 210))

        let selectAllButton = NSButton(
            title: "Select All",
            target: nil,
            action: nil
        )
        selectAllButton.bezelStyle = .rounded
        selectAllButton.frame = NSRect(x: 0, y: 178, width: 96, height: 28)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: listHeight))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let rowHeight: CGFloat = 30
        let documentHeight = max(listHeight, CGFloat(criteria.count) * rowHeight)
        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: width - 18, height: documentHeight))

        for (index, criterion) in criteria.enumerated() {
            let title = columnTitlesByID[criterion.columnID] ?? "Unknown Column"
            let row = CriteriaRemovalRow(
                criterionID: criterion.id,
                title: "\(title) = \(criterion.value)"
            )
            row.checkbox.frame = NSRect(
                x: 8,
                y: documentHeight - CGFloat(index + 1) * rowHeight,
                width: width - 34,
                height: 24
            )
            rows.append(row)
            documentView.addSubview(row.checkbox)
        }

        scrollView.documentView = documentView
        container.addSubview(selectAllButton)
        container.addSubview(scrollView)

        self.view = container
        super.init()

        selectAllButton.target = self
        selectAllButton.action = #selector(selectAll)
    }

    @objc private func selectAll() {
        for row in rows {
            row.checkbox.state = .on
        }
    }
}

private final class CriteriaRemovalRow {
    let criterionID: ViewCriterion.ID
    let checkbox: NSButton

    var isSelected: Bool {
        checkbox.state == .on
    }

    init(criterionID: ViewCriterion.ID, title: String) {
        self.criterionID = criterionID
        self.checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        self.checkbox.lineBreakMode = .byTruncatingTail
    }
}

private final class CategoryRuleController: NSObject {
    let view: NSView
    let categoryField: NSTextField
    private let targetColumns: [EntryColumn]
    private let popup: NSPopUpButton

    var selectedTargetColumnID: EntryColumn.ID? {
        guard popup.indexOfSelectedItem >= 0,
              popup.indexOfSelectedItem < targetColumns.count
        else { return nil }
        return targetColumns[popup.indexOfSelectedItem].id
    }

    var categoryName: String {
        categoryField.stringValue
    }

    init(targetColumns: [EntryColumn], defaultCategoryName: String) {
        self.targetColumns = targetColumns
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 34, width: 320, height: 26), pullsDown: false)
        for column in targetColumns {
            popup.addItem(withTitle: column.title)
        }
        popup.isEnabled = !targetColumns.isEmpty

        let categoryField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        categoryField.placeholderString = "Category"
        categoryField.stringValue = defaultCategoryName

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 62))
        container.addSubview(popup)
        container.addSubview(categoryField)

        self.popup = popup
        self.categoryField = categoryField
        self.view = container
        super.init()
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

            CommandGroup(before: .toolbar) {
                Button("Enter Full Screen") {
                    toggleFullScreenForKeyWindow()
                }
                .keyboardShortcut("f", modifiers: [.control, .command])
                .disabled(NSApp.keyWindow == nil)
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

                Divider()

                Button("Rename Current View") {
                    renameActiveViewPanel(for: model)
                }
                .disabled(!model.hasOpenLibrary || !model.hasOpenView)

                Button("Delete Current View") {
                    confirmDeleteActiveView(for: model)
                }
                .disabled(!model.hasOpenLibrary || !model.canDeleteActiveView)
            }

            CommandMenu("Criteria") {
                Button("Show Active Criteria") {
                    showActiveCriteriaPanel(for: model)
                }
                .disabled(!model.hasOpenLibrary || !model.hasOpenView)

                Divider()

                Button("Add/Modify Criteria") {
                    viewCriteriaPanel(for: model)
                }
                .disabled(!model.hasOpenLibrary || !model.canFilterActiveView || model.columns.isEmpty)

                Button("Remove Criteria") {
                    removeCriteriaPanel(for: model)
                }
                .disabled(!model.hasOpenLibrary || !model.canClearActiveViewFilter)

                Divider()

                Button("Save Criteria as Category Rule...") {
                    saveCriteriaAsCategoryRulePanel(for: model)
                }
                .disabled(!model.hasOpenLibrary || !model.canSaveActiveCriteriaAsCategoryRule)
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
            context.coordinator.configure(view.window, title: title)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configure(view.window, title: title)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private let framePreferenceKey = "StructureMainWindowFrame"
        private weak var observedWindow: NSWindow?
        private var restoredWindowIDs: Set<ObjectIdentifier> = []
        private var observers: [NSObjectProtocol] = []

        func configure(_ window: NSWindow?, title: String) {
            guard let window else { return }
            window.title = title
            if observedWindow !== window {
                observe(window)
            }
            restoreFrameIfNeeded(for: window)
        }

        private func observe(_ window: NSWindow) {
            removeObservers()
            observedWindow = window
            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] notification in
                    self?.saveFrame(from: notification.object as? NSWindow)
                },
                center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] notification in
                    self?.saveFrame(from: notification.object as? NSWindow)
                },
                center.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main) { [weak self] notification in
                    self?.saveFrame(from: notification.object as? NSWindow)
                },
                center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] notification in
                    self?.saveFrame(from: notification.object as? NSWindow)
                }
            ]
        }

        private func restoreFrameIfNeeded(for window: NSWindow) {
            let id = ObjectIdentifier(window)
            guard !restoredWindowIDs.contains(id) else { return }
            restoredWindowIDs.insert(id)

            guard let storedFrame = UserDefaults.standard.string(forKey: framePreferenceKey) else { return }
            let frame = NSRectFromString(storedFrame)
            guard frame.width > 0, frame.height > 0 else { return }

            let visibleFrames = NSScreen.screens.map(\.visibleFrame)
            guard visibleFrames.contains(where: { $0.intersects(frame) }) else { return }
            window.setFrame(frame, display: true)
        }

        private func saveFrame(from window: NSWindow?) {
            guard let window else { return }
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: framePreferenceKey)
        }

        private func removeObservers() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers = []
        }

        deinit {
            removeObservers()
        }
    }
}
