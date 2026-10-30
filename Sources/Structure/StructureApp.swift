import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let structureTabbingIdentifier = "StructureLibraryTabs"
private let structureWindowGroupID = "structure-window"

final class StructureAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openStructureWindow()
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        StructureTabSession.shared.beginTerminating()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        StructureTabSession.shared.beginTerminating()
    }
}

@MainActor
func openStructureWindow() {
    NSApp.activate(ignoringOtherApps: true)
    requestNewWindowForTab(relativeTo: nil)
}

@MainActor
func openStructureTab(openWindow: OpenWindowAction, activeViewID: StructureView.ID?) {
    NSApp.activate(ignoringOtherApps: true)
    StructureTabSession.shared.prepareNextTab(activeViewID: activeViewID)
    guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
        openWindow(id: structureWindowGroupID)
        return
    }
    configureStructureTabbing(for: window)
    StructureTabCoordinator.shared.prepareToAttachNextWindow(to: window)
    openWindow(id: structureWindowGroupID)
}

@MainActor
func selectNextStructureTab() {
    NSApp.sendAction(#selector(NSWindow.selectNextTab(_:)), to: nil, from: nil)
}

@MainActor
func mergeAllStructureWindows() {
    guard let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow else { return }
    StructureTabCoordinator.shared.mergeAllStructureWindows(into: parentWindow)
}

@MainActor
func configureStructureTabbing(for window: NSWindow) {
    window.tabbingIdentifier = structureTabbingIdentifier
    window.tabbingMode = .preferred
}

@MainActor
final class StructureTabCoordinator {
    static let shared = StructureTabCoordinator()

    private weak var pendingParentWindow: NSWindow?
    private var pendingAttachmentCount = 0
    private var windowIDsByViewID: [StructureView.ID: ObjectIdentifier] = [:]
    private var windowsByID: [ObjectIdentifier: NSWindow] = [:]
    private var viewIDsByWindowID: [ObjectIdentifier: StructureView.ID] = [:]

    func prepareToAttachNextWindow(to parentWindow: NSWindow) {
        pendingParentWindow = parentWindow
        pendingAttachmentCount += 1
    }

    func configure(_ window: NSWindow) {
        configureStructureTabbing(for: window)
        guard let parentWindow = pendingParentWindow,
              parentWindow !== window,
              pendingAttachmentCount > 0
        else { return }

        pendingAttachmentCount -= 1
        if pendingAttachmentCount == 0 {
            pendingParentWindow = nil
        }
        configureStructureTabbing(for: parentWindow)
        parentWindow.addTabbedWindow(window, ordered: .above)
        parentWindow.makeKeyAndOrderFront(nil)
    }

    func register(_ window: NSWindow, viewID: StructureView.ID?) {
        configureStructureTabbing(for: window)
        let windowID = ObjectIdentifier(window)
        windowsByID[windowID] = window
        if let viewID {
            windowIDsByViewID[viewID] = windowID
            viewIDsByWindowID[windowID] = viewID
        }
    }

    func currentVisibleTabViewOrder() -> [StructureView.ID] {
        let visibleStructureWindows = NSApp.windows
            .filter { isStructureDocumentWindow($0) }

        let referenceWindow = [NSApp.keyWindow, NSApp.mainWindow]
            .compactMap { $0 }
            .first { isStructureDocumentWindow($0) }
            ?? visibleStructureWindows.first
        let groupedWindows = referenceWindow?.tabGroup?.windows
            .filter { isStructureDocumentWindow($0) }
            ?? visibleStructureWindows
        let orderedViewIDs = groupedWindows.compactMap { window in
            viewIDsByWindowID[ObjectIdentifier(window)]
        }

        guard !orderedViewIDs.isEmpty else { return [] }
        return deduplicated(orderedViewIDs)
    }

    func mergeAllStructureWindows(into parentWindow: NSWindow) {
        configureStructureTabbing(for: parentWindow)
        let structureWindows = NSApp.windows
            .filter { isMergeableStructureWindow($0, parentWindow: parentWindow) }

        for window in structureWindows {
            configureStructureTabbing(for: window)
            if let tabGroup = parentWindow.tabGroup {
                tabGroup.addWindow(window)
            } else {
                parentWindow.addTabbedWindow(window, ordered: .above)
            }
        }
        pendingParentWindow = nil
        pendingAttachmentCount = 0
        parentWindow.makeKeyAndOrderFront(nil)
    }

    func mergeStructureWindows(into parentWindow: NSWindow, orderedViewIDs: [StructureView.ID]) {
        configureStructureTabbing(for: parentWindow)
        for (index, viewID) in orderedViewIDs.enumerated() {
            guard let windowID = windowIDsByViewID[viewID],
                  let window = windowsByID[windowID],
                  isMergeableStructureWindow(window, parentWindow: parentWindow)
            else { continue }

            configureStructureTabbing(for: window)
            if let tabGroup = parentWindow.tabGroup {
                let insertionIndex = min(index, tabGroup.windows.count)
                tabGroup.insertWindow(window, at: insertionIndex)
            } else {
                parentWindow.addTabbedWindow(window, ordered: .above)
            }
        }
        pendingParentWindow = nil
        pendingAttachmentCount = 0
        parentWindow.makeKeyAndOrderFront(nil)
    }

    private func isMergeableStructureWindow(_ window: NSWindow, parentWindow: NSWindow) -> Bool {
        window !== parentWindow
            && isStructureDocumentWindow(window)
    }

    private func isStructureDocumentWindow(_ window: NSWindow) -> Bool {
        window.isVisible
            && windowsByID[ObjectIdentifier(window)] != nil
            && window.canBecomeMain
            && window.level == .normal
            && !(window is NSPanel)
    }

    private func deduplicated(_ viewIDs: [StructureView.ID]) -> [StructureView.ID] {
        var seen = Set<StructureView.ID>()
        var result: [StructureView.ID] = []
        for viewID in viewIDs where seen.insert(viewID).inserted {
            result.append(viewID)
        }
        return result
    }
}

@MainActor
func requestNewWindowForTab(relativeTo _: NSWindow?) {
    NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
}

@MainActor
final class StructureTabSession {
    static let shared = StructureTabSession()

    private let openViewTabIDsPreferenceKey = "StructureOpenViewTabIDs"
    private let savedInitialViewIDs: [StructureView.ID]
    private var pendingInitialViewIDs: [StructureView.ID]
    private let expectedRestoredTabCount: Int
    private var preparedInitialViewID: StructureView.ID?
    private var activeTabOrder: [UUID] = []
    private var activeViewIDsByTab: [UUID: StructureView.ID] = [:]
    private var didRequestRestoredTabs = false
    private var isTerminating = false

    private init() {
        let savedViewIDs = UserDefaults.standard.stringArray(forKey: openViewTabIDsPreferenceKey) ?? []
        savedInitialViewIDs = savedViewIDs
        pendingInitialViewIDs = savedViewIDs
        expectedRestoredTabCount = savedViewIDs.count
    }

    func beginTerminating() {
        let visualOrder = StructureTabCoordinator.shared.currentVisibleTabViewOrder()
        persist(force: true, overrideViewIDs: visualOrder.isEmpty ? nil : visualOrder)
        isTerminating = true
    }

    func claimInitialViewID() -> StructureView.ID? {
        if let preparedInitialViewID {
            self.preparedInitialViewID = nil
            return preparedInitialViewID
        }
        guard !pendingInitialViewIDs.isEmpty else { return nil }
        return pendingInitialViewIDs.removeFirst()
    }

    func prepareNextTab(activeViewID: StructureView.ID?) {
        preparedInitialViewID = activeViewID
    }

    func restoreTabsIfNeeded(from window: NSWindow?, openWindow: OpenWindowAction) {
        guard let launchWindow = window, !didRequestRestoredTabs else { return }
        didRequestRestoredTabs = true

        let tabCountToRestore = pendingInitialViewIDs.count
        guard tabCountToRestore > 0 else { return }

        configureStructureTabbing(for: launchWindow)
        for index in 0..<tabCountToRestore {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.12)) {
                openWindow(id: structureWindowGroupID)
            }
        }
        for delay in [0.4, 0.9, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(tabCountToRestore) * 0.12) + delay) {
                StructureTabCoordinator.shared.mergeStructureWindows(into: launchWindow, orderedViewIDs: self.savedInitialViewIDs)
            }
        }
    }

    func update(tabID: UUID, viewID: StructureView.ID?) {
        guard let viewID else { return }
        if !activeTabOrder.contains(tabID) {
            activeTabOrder.append(tabID)
        }
        activeViewIDsByTab[tabID] = viewID
        persist()
    }

    func unregister(tabID: UUID) {
        activeTabOrder.removeAll { $0 == tabID }
        activeViewIDsByTab.removeValue(forKey: tabID)
        persist()
    }

    private func persist(force: Bool = false, overrideViewIDs: [StructureView.ID]? = nil) {
        guard force || !isTerminating else { return }
        guard force || !isRestoringSavedTabs else { return }

        let viewIDs = overrideViewIDs ?? activeTabOrder.compactMap { activeViewIDsByTab[$0] }
        if viewIDs.isEmpty {
            UserDefaults.standard.removeObject(forKey: openViewTabIDsPreferenceKey)
        } else {
            UserDefaults.standard.set(viewIDs, forKey: openViewTabIDsPreferenceKey)
        }
        UserDefaults.standard.synchronize()
    }

    private var isRestoringSavedTabs: Bool {
        expectedRestoredTabCount > 1 && activeTabOrder.count < expectedRestoredTabCount
    }
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

@MainActor
func importOneNoteNotebookPanel(for model: EntryListModel) {
    let panel = NSOpenPanel()
    panel.title = "Import OneNote Notebook"
    panel.message = "Choose an HTML/XHTML OneNote export file or a folder containing exported pages."
    panel.prompt = "Import"
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [
        .html,
        UTType(filenameExtension: "xhtml"),
        UTType(filenameExtension: "htm"),
        UTType(filenameExtension: "one"),
        UTType(filenameExtension: "onepkg")
    ].compactMap { $0 }

    if panel.runModal() == .OK, let url = panel.url {
        model.importOneNoteNotebook(at: url)
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
func newViewPanel(for model: EntryListModel) {
    let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    input.stringValue = model.suggestedNewViewTitle
    input.selectText(nil)

    let alert = NSAlert()
    alert.messageText = "New View"
    alert.informativeText = "Name this View."
    alert.accessoryView = input
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")
    alert.window.initialFirstResponder = input

    if alert.runModal() == .alertFirstButtonReturn {
        model.createView(title: input.stringValue)
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
func manageCategoryRulesPanel(for model: EntryListModel) {
    let managerView = NSHostingView(rootView: CategoryRulesManagerView(model: model))
    managerView.frame = NSRect(x: 0, y: 0, width: 560, height: 340)

    let alert = NSAlert()
    alert.messageText = "Category Rules"
    alert.informativeText = "Review saved Category Rules for this Library."
    alert.accessoryView = managerView
    alert.addButton(withTitle: "Done")
    alert.runModal()
}

@MainActor
func confirmApplyCategoryRulesToCurrentView(for model: EntryListModel) {
    let alert = NSAlert()
    alert.messageText = "Apply Category Rules to Current View?"
    alert.informativeText = "Rules will fill only empty matching Category cells in the current View."
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Apply")

    if alert.runModal() == .alertSecondButtonReturn {
        model.applyCategoryRulesToCurrentView()
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

private struct CategoryRulesManagerView: View {
    @ObservedObject var model: EntryListModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Target")
                    .frame(width: 180, alignment: .leading)
                Text("Criteria")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Delete")
                    .frame(width: 48, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)

            Divider()

            if model.categoryRuleSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No saved Category Rules")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Create one from a filtered View with Criteria > Save Criteria as Category Rule...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
            } else {
                ScrollView {
                    ForEach(model.categoryRuleSummaries) { summary in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary.targetColumnTitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text(summary.categoryName)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(width: 180, alignment: .leading)

                            Text(summary.criteriaText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button(role: .destructive) {
                                confirmDeleteCategoryRule(summary, model: model)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete Category Rule")
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(8)
        .frame(width: 560, height: 340, alignment: .topLeading)
    }

    private func confirmDeleteCategoryRule(_ summary: CategoryRuleSummary, model: EntryListModel) {
        let alert = NSAlert()
        alert.messageText = "Delete Category Rule?"
        alert.informativeText = "\(summary.targetColumnTitle) = \(summary.categoryName)\n\(summary.criteriaText)"
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        alert.alertStyle = .warning

        if alert.runModal() == .alertSecondButtonReturn {
            model.deleteCategoryRule(id: summary.id)
        }
    }
}

@main
struct StructureApp: App {
    @NSApplicationDelegateAdaptor(StructureAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @FocusedObject private var model: EntryListModel?
    @State private var viewZoomScale: CGFloat = 1.0

    var body: some Scene {
        WindowGroup("Structure", id: structureWindowGroupID) {
            StructureWindowRoot(viewScale: viewZoomScale)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Structure") {
                    AboutBoxController.shared.show()
                }
            }

            CommandGroup(after: .pasteboard) {
                Button("Find") {
                    if let model {
                        findPanel(for: model)
                    }
                }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(model?.hasOpenLibrary != true || model?.hasOpenView != true)
            }

            CommandGroup(before: .toolbar) {
                Button("Enter Full Screen") {
                    toggleFullScreenForKeyWindow()
                }
                .keyboardShortcut("f", modifiers: [.control, .command])
                .disabled(NSApp.keyWindow == nil)
            }

            CommandGroup(after: .windowArrangement) {
                Button("New Tab") {
                    openStructureTab(openWindow: openWindow, activeViewID: model?.activeView?.id)
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("Next Tab") {
                    selectNextStructureTab()
                }
                .keyboardShortcut(.tab, modifiers: [.command])
                .disabled(NSApp.keyWindow == nil)

                Button("Merge All Windows") {
                    mergeAllStructureWindows()
                }
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
                    if let model {
                        renameActiveViewPanel(for: model)
                    }
                }
                .disabled(model?.hasOpenLibrary != true || model?.hasOpenView != true)

                Button("Delete Current View") {
                    if let model {
                        confirmDeleteActiveView(for: model)
                    }
                }
                .disabled(model?.hasOpenLibrary != true || model?.canDeleteActiveView != true)
            }

            CommandMenu("Criteria") {
                Button("Show Active Criteria") {
                    if let model {
                        showActiveCriteriaPanel(for: model)
                    }
                }
                .disabled(model?.hasOpenLibrary != true || model?.hasOpenView != true)

                Divider()

                Button("Add/Modify Criteria") {
                    if let model {
                        viewCriteriaPanel(for: model)
                    }
                }
                .disabled(model?.hasOpenLibrary != true || model?.canFilterActiveView != true || model?.columns.isEmpty != false)

                Button("Remove Criteria") {
                    if let model {
                        removeCriteriaPanel(for: model)
                    }
                }
                .disabled(model?.hasOpenLibrary != true || model?.canClearActiveViewFilter != true)

                Divider()

                Button("Save Criteria as Category Rule...") {
                    if let model {
                        saveCriteriaAsCategoryRulePanel(for: model)
                    }
                }
                .disabled(model?.hasOpenLibrary != true || model?.canSaveActiveCriteriaAsCategoryRule != true)

                Button("Manage Category Rules...") {
                    if let model {
                        manageCategoryRulesPanel(for: model)
                    }
                }
                .disabled(model?.hasOpenLibrary != true)

                Button("Apply Category Rules to Current View") {
                    if let model {
                        confirmApplyCategoryRulesToCurrentView(for: model)
                    }
                }
                .disabled(model?.hasOpenLibrary != true || model?.hasOpenView != true || model?.hasCategoryRules != true)
            }

            CommandGroup(replacing: .newItem) {
                Button("New Library") {
                    if let model {
                        newLibraryPanel(for: model)
                    }
                }
                .disabled(model == nil)

                Button("Open Library") {
                    if let model {
                        openLibraryPanel(for: model)
                    }
                }
                .keyboardShortcut("o", modifiers: [.command])
                .disabled(model == nil)

                Menu("Open Recent Library") {
                    ForEach(model?.recentLibraryURLs ?? [], id: \.path) { url in
                        Button(libraryMenuTitle(for: url)) {
                            model?.openLibrary(at: url)
                        }
                        .disabled(model?.activeLibraryURL?.path == url.path)
                    }
                }
                .disabled(model?.recentLibraryURLs.isEmpty != false)

                Button("Close Library") {
                    model?.closeLibrary()
                }
                .disabled(model?.hasOpenLibrary != true)

                Divider()

                Button("Import OneNote Notebook") {
                    if let model {
                        importOneNoteNotebookPanel(for: model)
                    }
                }
                .disabled(model?.hasOpenLibrary != true || model?.hasOpenView != true)

                Divider()

                Button("New View") {
                    if let model {
                        newViewPanel(for: model)
                    }
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(model?.hasOpenLibrary != true)

                if (model?.views.count ?? 0) <= 7 {
                    Menu("Open View") {
                        ForEach(model?.views ?? []) { view in
                            Button(view.title) {
                                model?.openView(id: view.id)
                            }
                            .disabled(model?.activeView?.id == view.id)
                        }
                    }
                    .disabled(model?.hasOpenLibrary != true || model?.views.isEmpty != false)
                } else {
                    Button("Open View...") {
                        if let model {
                            openViewSelectionPanel(for: model)
                        }
                    }
                    .disabled(model?.hasOpenLibrary != true || model?.views.isEmpty != false)
                }

                Button("Close View") {
                    model?.closeView()
                }
                .keyboardShortcut("w", modifiers: [.command])
                .disabled(model?.hasOpenView != true)

                Divider()

                Button("New Entry") {
                    model?.createEntry()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(model?.hasOpenLibrary != true || model?.hasOpenView != true)
            }
        }
    }
}

private struct StructureWindowRoot: View {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var model: EntryListModel
    @State private var tabID = UUID()
    let viewScale: CGFloat

    init(viewScale: CGFloat) {
        self.viewScale = viewScale
        _model = StateObject(wrappedValue: EntryListModel(initialViewID: StructureTabSession.shared.claimInitialViewID()))
    }

    var body: some View {
        EntryStreamView(model: model, viewScale: viewScale)
            .frame(minWidth: 620, minHeight: 520)
            .background(WindowTitleSetter(
                title: model.windowTitle,
                tabID: tabID,
                viewID: model.activeView?.id,
                openWindow: openWindow
            ))
            .focusedSceneObject(model)
            .onAppear {
                StructureTabSession.shared.update(tabID: tabID, viewID: model.activeView?.id)
            }
            .onChange(of: model.activeView?.id) { viewID in
                StructureTabSession.shared.update(tabID: tabID, viewID: viewID)
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
    let tabID: UUID
    let viewID: StructureView.ID?
    let openWindow: OpenWindowAction

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.configure(
                view.window,
                title: title,
                tabID: tabID,
                viewID: viewID,
                openWindow: openWindow
            )
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configure(
                view.window,
                title: title,
                tabID: tabID,
                viewID: viewID,
                openWindow: openWindow
            )
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

        func configure(
            _ window: NSWindow?,
            title: String,
            tabID: UUID,
            viewID: StructureView.ID?,
            openWindow: OpenWindowAction
        ) {
            guard let window else { return }
            window.title = title
            window.isRestorable = false
            window.restorationClass = nil
            Task { @MainActor in
                StructureTabCoordinator.shared.register(window, viewID: viewID)
                StructureTabCoordinator.shared.configure(window)
                StructureTabSession.shared.restoreTabsIfNeeded(from: window, openWindow: openWindow)
            }
            if observedWindow !== window {
                observe(window, tabID: tabID)
            }
            restoreFrameIfNeeded(for: window)
        }

        private func observe(_ window: NSWindow, tabID: UUID) {
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
                    Task { @MainActor in
                        StructureTabSession.shared.unregister(tabID: tabID)
                    }
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
