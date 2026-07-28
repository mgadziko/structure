import AppKit
import SwiftUI

struct FormattingBar: View {
    @State private var selectedSize = "17"
    @State private var selectedFamily = NSFont.systemFont(ofSize: 17).familyName ?? "System"
    @State private var isUpdatingFromActiveTextView = false

    private let fontSizes = ["8", "10", "12", "14", "16", "18", "20", "24", "28", "32", "36"]
    private let fontFamilies = NSFontManager.shared.availableFontFamilies.sorted {
        $0.localizedStandardCompare($1) == .orderedAscending
    }

    var body: some View {
        HStack(spacing: 8) {
            FontSizeComboBox(values: fontSizes, text: $selectedSize) { value in
                guard let size = Double(value), size > 0 else { return }
                EntryFormattingCommands.applyFontSize(CGFloat(size))
            }
            .frame(width: 64, height: 24)

            Picker("Typeface", selection: $selectedFamily) {
                ForEach(fontFamilies, id: \.self) { family in
                    Text(family).tag(family)
                }
            }
            .labelsHidden()
            .frame(width: 180)
            .onChange(of: selectedFamily) { family in
                guard !isUpdatingFromActiveTextView else { return }
                EntryFormattingCommands.applyFontFamily(family)
            }

            Divider()
                .frame(height: 22)

            FormatButton(title: "B", accessibilityLabel: "Bold", action: EntryFormattingCommands.toggleBold)
                .font(.system(size: 13, weight: .bold))
            FormatButton(title: "I", accessibilityLabel: "Italic", action: EntryFormattingCommands.toggleItalic)
                .italic()
            FormatButton(title: "U", accessibilityLabel: "Underline", action: EntryFormattingCommands.toggleUnderline)
                .underline()
            FormatButton(title: "S", accessibilityLabel: "Strikethrough", action: EntryFormattingCommands.toggleStrikethrough)
                .strikethrough()

            Divider()
                .frame(height: 22)

            FormatButton(title: "\u{2022}", accessibilityLabel: "Bullet List") {
                EntryFormattingCommands.toggleList(.bullet)
            }
            FormatButton(title: "1.", accessibilityLabel: "Numbered List") {
                EntryFormattingCommands.toggleList(.numbered)
            }

            Spacer()
        }
        .padding(.horizontal, 38)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .entryTextSelectionChanged)) { notification in
            updateControlsFromActiveTextView(notification.object as? NSTextView)
        }
        .onAppear {
            updateControlsFromActiveTextView(nil)
        }
    }

    private func updateControlsFromActiveTextView(_ textView: NSTextView?) {
        guard let font = activeFont(in: textView) else { return }
        let family = font.familyName ?? font.fontName
        if selectedFamily != family, fontFamilies.contains(family) {
            isUpdatingFromActiveTextView = true
            selectedFamily = family
            DispatchQueue.main.async {
                isUpdatingFromActiveTextView = false
            }
        }

        let size = String(Int(round(font.pointSize)))
        if selectedSize != size {
            selectedSize = size
        }
    }

    private func activeFont(in notifiedTextView: NSTextView?) -> NSFont? {
        guard let textView = notifiedTextView ?? EntrySelectionCoordinator.shared.currentTextView() else { return nil }

        let selectedRange = textView.selectedRange()
        if let storage = textView.textStorage, storage.length > 0 {
            let location: Int
            if selectedRange.length > 0 {
                location = selectedRange.location
            } else if selectedRange.location >= storage.length {
                location = storage.length - 1
            } else {
                location = selectedRange.location
            }

            if location >= 0,
               location < storage.length,
               let font = storage.attribute(.font, at: location, effectiveRange: nil) as? NSFont {
                return font
            }
        }

        if let typingFont = textView.typingAttributes[.font] as? NSFont {
            return typingFont
        }

        return textView.font
    }
}

private struct FormatButton: View {
    let title: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct FontSizeComboBox: NSViewRepresentable {
    let values: [String]
    @Binding var text: String
    let onCommit: (String) -> Void

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.addItems(withObjectValues: values)
        comboBox.stringValue = text
        comboBox.completes = true
        comboBox.numberOfVisibleItems = values.count
        comboBox.delegate = context.coordinator
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        if comboBox.stringValue != text {
            comboBox.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        @Binding var text: String
        let onCommit: (String) -> Void

        init(text: Binding<String>, onCommit: @escaping (String) -> Void) {
            _text = text
            self.onCommit = onCommit
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            commitSelectedValue(notification)
        }

        func comboBoxSelectionIsChanging(_ notification: Notification) {
            commitSelectedValue(notification)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            commitTypedValue(notification)
        }

        private func commitSelectedValue(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            let value: String
            if let selectedValue = comboBox.objectValueOfSelectedItem as? String {
                value = selectedValue
            } else {
                value = comboBox.stringValue
            }
            comboBox.stringValue = value
            commit(value)
        }

        private func commitTypedValue(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            commit(comboBox.stringValue)
        }

        private func commit(_ value: String) {
            text = value
            onCommit(value)
        }
    }
}
