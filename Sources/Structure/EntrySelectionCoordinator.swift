import AppKit

extension Notification.Name {
    static let entryTextSelectionChanged = Notification.Name("StructureEntryTextSelectionChanged")
    static let entryFindResultSelected = Notification.Name("StructureEntryFindResultSelected")
}

final class FindResultFocusRequest {
    let cellID: StructureCellID
    let range: NSRange

    init(cellID: StructureCellID, range: NSRange) {
        self.cellID = cellID
        self.range = range
    }
}

final class EntrySelectionCoordinator {
    static let shared = EntrySelectionCoordinator()

    private let textViews = NSHashTable<NSTextView>.weakObjects()
    private var entryTextViews: [Entry.ID: WeakTextView] = [:]
    private var cellTextViews: [StructureCellID: WeakTextView] = [:]
    private var cellIDsByTextViewID: [ObjectIdentifier: StructureCellID] = [:]
    private var cellOrderByEntryID: [Entry.ID: [StructureCellID]] = [:]
    private var visibleEntryIDs: [Entry.ID] = []
    private weak var activeTextView: NSTextView?
    private weak var lastSelectAllTextView: NSTextView?
    private var lastSelectAllTime: Date?
    private let escalationInterval: TimeInterval = 1.1

    private init() {}

    func register(_ textView: NSTextView) {
        textViews.add(textView)
    }

    func registerEntryTextView(_ textView: NSTextView, entryID: Entry.ID) {
        register(textView, cellID: .entry(entryID))
        entryTextViews[entryID] = WeakTextView(textView)
    }

    func registerColumnTextView(_ textView: NSTextView, entryID: Entry.ID, columnID: EntryColumn.ID) {
        register(textView, cellID: .column(entryID: entryID, columnID: columnID))
    }

    func register(_ textView: NSTextView, cellID: StructureCellID) {
        register(textView)
        cellTextViews[cellID] = WeakTextView(textView)
        cellIDsByTextViewID[ObjectIdentifier(textView)] = cellID
    }

    func unregister(_ textView: NSTextView) {
        textViews.remove(textView)
        entryTextViews = entryTextViews.filter { $0.value.textView !== textView && $0.value.textView != nil }
        cellTextViews = cellTextViews.filter { $0.value.textView !== textView && $0.value.textView != nil }
        cellIDsByTextViewID.removeValue(forKey: ObjectIdentifier(textView))
    }

    func updateCellOrder(entryID: Entry.ID, columnsBeforeEntry: [EntryColumn], columnsAfterEntry: [EntryColumn]) {
        cellOrderByEntryID[entryID] =
            columnsBeforeEntry.map { .column(entryID: entryID, columnID: $0.id) }
            + [.entry(entryID)]
            + columnsAfterEntry.map { .column(entryID: entryID, columnID: $0.id) }
    }

    func updateVisibleEntryOrder(_ entryIDs: [Entry.ID]) {
        visibleEntryIDs = entryIDs
    }

    func focusEntry(id: Entry.ID) {
        guard let textView = entryTextViews[id]?.textView else { return }
        focusAndPlaceInsertionPoint(in: textView)
    }

    func moveFocus(from textView: NSTextView, direction: CellFocusDirection) -> Bool {
        guard
            let cellID = cellIDsByTextViewID[ObjectIdentifier(textView)],
            let entryID = cellID.entryID,
            let rowOrder = cellOrderByEntryID[entryID],
            let currentIndex = rowOrder.firstIndex(of: cellID)
        else { return false }

        let targetIndex: Int
        switch direction {
        case .left:
            targetIndex = currentIndex - 1
        case .right:
            targetIndex = currentIndex + 1
        }

        if rowOrder.indices.contains(targetIndex),
           let targetTextView = cellTextViews[rowOrder[targetIndex]]?.textView {
            focusAndPlaceInsertionPoint(in: targetTextView)
            return true
        }

        guard let wrappedTextView = wrappedRowTextView(from: entryID, direction: direction) else {
            return false
        }

        focusAndPlaceInsertionPoint(in: wrappedTextView)
        return true
    }

    private func wrappedRowTextView(from entryID: Entry.ID, direction: CellFocusDirection) -> NSTextView? {
        guard let rowIndex = visibleEntryIDs.firstIndex(of: entryID) else { return nil }

        let targetRowIndex: Int
        switch direction {
        case .left:
            targetRowIndex = rowIndex - 1
        case .right:
            targetRowIndex = rowIndex + 1
        }

        guard visibleEntryIDs.indices.contains(targetRowIndex),
              let targetRowOrder = cellOrderByEntryID[visibleEntryIDs[targetRowIndex]],
              let targetCellID = direction == .right ? targetRowOrder.first : targetRowOrder.last
        else { return nil }

        return cellTextViews[targetCellID]?.textView
    }

    func currentFindAnchor() -> FindAnchor? {
        guard
            let activeTextView,
            let cellID = cellIDsByTextViewID[ObjectIdentifier(activeTextView)]
        else { return nil }

        return FindAnchor(cellID: cellID, selectedRange: activeTextView.selectedRange())
    }

    func selectFindResult(cellID: StructureCellID, range: NSRange, notifyScroll: Bool = true) {
        guard let textView = cellTextViews[cellID]?.textView else { return }
        focusTextView(textView)
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        notifyTextSelectionChanged(in: textView)
        if notifyScroll {
            NotificationCenter.default.post(
                name: .entryFindResultSelected,
                object: FindResultFocusRequest(cellID: cellID, range: range)
            )
        }
    }

    func focusTextView(_ textView: NSTextView) {
        activeTextView = textView
        for otherTextView in textViews.allObjects where otherTextView !== textView {
            otherTextView.setSelectedRange(NSRange(location: 0, length: 0))
        }
        lastSelectAllTextView = nil
        lastSelectAllTime = nil
        notifyTextSelectionChanged(in: textView)
    }

    private func focusAndPlaceInsertionPoint(in textView: NSTextView) {
        focusTextView(textView)
        placeInsertionPoint(in: textView)
    }

    private func placeInsertionPoint(in textView: NSTextView) {
        textView.window?.makeFirstResponder(textView)
        let end = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: end, length: 0))
        textView.scrollRangeToVisible(NSRange(location: end, length: 0))
        notifyTextSelectionChanged(in: textView)
    }

    func focus(_ textView: NSTextView) {
        focusTextView(textView)
    }

    func handleSelectAll(in textView: NSTextView) {
        let now = Date()
        let shouldEscalate = lastSelectAllTextView === textView
            && textView.selectedRange().length == (textView.string as NSString).length
            && lastSelectAllTime.map { now.timeIntervalSince($0) <= escalationInterval } == true

        if shouldEscalate {
            selectAllEntryText()
            lastSelectAllTextView = nil
            lastSelectAllTime = nil
        } else {
            textView.selectAll(nil)
            lastSelectAllTextView = textView
            lastSelectAllTime = now
        }
        notifyTextSelectionChanged(in: textView)
    }

    func notifyTextSelectionChanged() {
        NotificationCenter.default.post(name: .entryTextSelectionChanged, object: nil)
    }

    func notifyTextSelectionChanged(in textView: NSTextView) {
        activeTextView = textView
        NotificationCenter.default.post(name: .entryTextSelectionChanged, object: textView)
    }

    func currentTextView() -> NSTextView? {
        activeTextView ?? NSApp.keyWindow?.firstResponder as? NSTextView
    }

    private func selectAllEntryText() {
        for textView in textViews.allObjects {
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.setSelectedRange(fullRange)
        }
    }
}

enum CellFocusDirection {
    case left
    case right
}

enum StructureCellID: Hashable {
    case entry(Entry.ID)
    case column(entryID: Entry.ID, columnID: EntryColumn.ID)

    var entryID: Entry.ID? {
        switch self {
        case .entry(let entryID):
            return entryID
        case .column(let entryID, _):
            return entryID
        }
    }
}

struct FindAnchor {
    let cellID: StructureCellID
    let selectedRange: NSRange
}

private final class WeakTextView {
    weak var textView: NSTextView?

    init(_ textView: NSTextView) {
        self.textView = textView
    }
}

final class EntryTextView: NSTextView {
    deinit {
        EntrySelectionCoordinator.shared.unregister(self)
    }

    override func keyDown(with event: NSEvent) {
        if handleTabNavigation(in: self, event: event) {
            return
        }

        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "a" {
            EntrySelectionCoordinator.shared.handleSelectAll(in: self)
            return
        }

        super.keyDown(with: event)
        EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: self)
    }

    override func mouseDown(with event: NSEvent) {
        EntrySelectionCoordinator.shared.focus(self)
        super.mouseDown(with: event)
        DispatchQueue.main.async {
            EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: self)
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: self)
    }
}

func handleTabNavigation(in textView: NSTextView, event: NSEvent) -> Bool {
    guard event.keyCode == 48 else { return false }
    let direction: CellFocusDirection = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        ? .left
        : .right
    _ = EntrySelectionCoordinator.shared.moveFocus(from: textView, direction: direction)
    return true
}
