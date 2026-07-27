import AppKit

final class EntrySelectionCoordinator {
    static let shared = EntrySelectionCoordinator()

    private let textViews = NSHashTable<NSTextView>.weakObjects()
    private weak var lastSelectAllTextView: NSTextView?
    private var lastSelectAllTime: Date?
    private let escalationInterval: TimeInterval = 1.1

    private init() {}

    func register(_ textView: NSTextView) {
        textViews.add(textView)
    }

    func unregister(_ textView: NSTextView) {
        textViews.remove(textView)
    }

    func focus(_ textView: NSTextView) {
        for otherTextView in textViews.allObjects where otherTextView !== textView {
            otherTextView.setSelectedRange(NSRange(location: 0, length: 0))
        }
        lastSelectAllTextView = nil
        lastSelectAllTime = nil
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
    }

    private func selectAllEntryText() {
        for textView in textViews.allObjects {
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.setSelectedRange(fullRange)
        }
    }
}

final class EntryTextView: NSTextView {
    deinit {
        EntrySelectionCoordinator.shared.unregister(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "a" {
            EntrySelectionCoordinator.shared.handleSelectAll(in: self)
            return
        }

        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        EntrySelectionCoordinator.shared.focus(self)
        super.mouseDown(with: event)
    }
}
