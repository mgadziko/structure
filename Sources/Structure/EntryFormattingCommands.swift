import AppKit

enum EntryFormattingCommands {
    enum ListKind {
        case bullet
        case numbered
    }

    static func applyFontFamily(_ family: String) {
        transformFonts { font in
            let size = font?.pointSize ?? 17
            return NSFontManager.shared.convert(font ?? NSFont.systemFont(ofSize: size), toFamily: family)
        }
    }

    static func applyFontSize(_ size: CGFloat) {
        transformFonts { font in
            NSFontManager.shared.convert(font ?? NSFont.systemFont(ofSize: size), toSize: size)
        }
    }

    static func toggleBold() {
        transformFonts { font in
            toggleFontTrait(.boldFontMask, in: font)
        }
    }

    static func toggleItalic() {
        transformFonts { font in
            toggleFontTrait(.italicFontMask, in: font)
        }
    }

    static func toggleUnderline() {
        toggleAttribute(.underlineStyle, enabledValue: NSUnderlineStyle.single.rawValue)
    }

    static func toggleStrikethrough() {
        toggleAttribute(.strikethroughStyle, enabledValue: NSUnderlineStyle.single.rawValue)
    }

    static func toggleList(_ kind: ListKind) {
        guard let textView = activeTextView(), let storage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        let targetRange = paragraphRange(for: selectedRange, in: storage.string as NSString)
        guard targetRange.location != NSNotFound else { return }

        let text = storage.string as NSString
        let paragraphRanges = paragraphRanges(in: targetRange, text: text)
        let remove = paragraphRanges.allSatisfy { range in
            paragraphHasListMarker(in: text.substring(with: range), kind: kind)
        }

        registerUndo(for: textView)
        storage.beginEditing()
        var locationDelta = 0
        for (index, originalRange) in paragraphRanges.enumerated() {
            let range = NSRange(
                location: originalRange.location + locationDelta,
                length: originalRange.length
            )
            if remove {
                locationDelta += removeListMarker(kind, from: storage, paragraphRange: range)
            } else {
                let marker = kind == .bullet ? "\u{2022}\t" : "\(index + 1).\t"
                storage.replaceCharacters(in: NSRange(location: range.location, length: 0), with: marker)
                locationDelta += (marker as NSString).length
                applyListParagraphStyle(to: NSRange(location: range.location, length: range.length + (marker as NSString).length), in: storage)
            }
        }
        storage.endEditing()
        textView.didChangeText()
    }

    private static func transformFonts(_ transform: (NSFont?) -> NSFont) {
        guard let textView = activeTextView() else { return }
        let selectedRanges = textView.selectedRanges.compactMap { $0.rangeValue }
        let effectiveRanges = selectedRanges.filter { $0.length > 0 }

        if effectiveRanges.isEmpty {
            let currentFont = textView.typingAttributes[.font] as? NSFont
            textView.typingAttributes[.font] = transform(currentFont)
            return
        }

        guard let storage = textView.textStorage else { return }
        registerUndo(for: textView)
        storage.beginEditing()
        for range in effectiveRanges {
            storage.enumerateAttribute(.font, in: range) { value, attributeRange, _ in
                storage.addAttribute(.font, value: transform(value as? NSFont), range: attributeRange)
            }
        }
        storage.endEditing()
        textView.didChangeText()
    }

    private static func toggleFontTrait(_ trait: NSFontTraitMask, in font: NSFont?) -> NSFont {
        let currentFont = font ?? NSFont.systemFont(ofSize: 17)
        let traits = NSFontManager.shared.traits(of: currentFont)
        if traits.contains(trait) {
            return NSFontManager.shared.convert(currentFont, toNotHaveTrait: trait)
        }
        return NSFontManager.shared.convert(currentFont, toHaveTrait: trait)
    }

    private static func toggleAttribute(_ key: NSAttributedString.Key, enabledValue: Int) {
        guard let textView = activeTextView() else { return }
        let selectedRanges = textView.selectedRanges.compactMap { $0.rangeValue }
        let effectiveRanges = selectedRanges.filter { $0.length > 0 }

        if effectiveRanges.isEmpty {
            if textView.typingAttributes[key] == nil {
                textView.typingAttributes[key] = enabledValue
            } else {
                textView.typingAttributes.removeValue(forKey: key)
            }
            return
        }

        guard let storage = textView.textStorage else { return }
        registerUndo(for: textView)
        storage.beginEditing()
        for range in effectiveRanges {
            let currentlyEnabled = storage.attribute(key, at: range.location, effectiveRange: nil) != nil
            if currentlyEnabled {
                storage.removeAttribute(key, range: range)
            } else {
                storage.addAttribute(key, value: enabledValue, range: range)
            }
        }
        storage.endEditing()
        textView.didChangeText()
    }

    private static func activeTextView() -> NSTextView? {
        NSApp.keyWindow?.firstResponder as? NSTextView
    }

    private static func registerUndo(for textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let snapshot = NSAttributedString(attributedString: storage)
        let selectedRanges = textView.selectedRanges
        textView.undoManager?.registerUndo(withTarget: textView) { target in
            target.textStorage?.setAttributedString(snapshot)
            target.selectedRanges = selectedRanges
            target.didChangeText()
        }
    }

    private static func paragraphRange(for range: NSRange, in text: NSString) -> NSRange {
        if text.length == 0 {
            return NSRange(location: 0, length: 0)
        }
        let safeLocation = min(range.location, max(text.length - 1, 0))
        let safeLength = min(range.length, text.length - safeLocation)
        return text.paragraphRange(for: NSRange(location: safeLocation, length: safeLength))
    }

    private static func paragraphRanges(in range: NSRange, text: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var location = range.location
        let end = range.location + range.length

        repeat {
            let paragraph = text.paragraphRange(for: NSRange(location: min(location, text.length), length: 0))
            ranges.append(paragraph)
            location = paragraph.location + paragraph.length
        } while location < end

        return ranges
    }

    private static func paragraphHasListMarker(in paragraph: String, kind: ListKind) -> Bool {
        switch kind {
        case .bullet:
            return paragraph.hasPrefix("\u{2022}\t") || paragraph.hasPrefix("\u{2022} ")
        case .numbered:
            return paragraph.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
        }
    }

    private static func removeListMarker(_ kind: ListKind, from storage: NSMutableAttributedString, paragraphRange: NSRange) -> Int {
        let paragraph = (storage.string as NSString).substring(with: paragraphRange)
        let removalLength: Int
        switch kind {
        case .bullet:
            if paragraph.hasPrefix("\u{2022}\t") || paragraph.hasPrefix("\u{2022} ") {
                removalLength = 2
            } else {
                removalLength = 0
            }
        case .numbered:
            let nsParagraph = paragraph as NSString
            let match = try? NSRegularExpression(pattern: #"^\d+\.\s"#)
                .firstMatch(in: paragraph, range: NSRange(location: 0, length: nsParagraph.length))
            removalLength = match?.range.length ?? 0
        }

        if removalLength > 0 {
            storage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: removalLength), with: "")
        }
        return -removalLength
    }

    private static func applyListParagraphStyle(to range: NSRange, in storage: NSMutableAttributedString) {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 0
        style.headIndent = 24
        style.tabStops = [NSTextTab(textAlignment: .left, location: 24)]
        storage.addAttribute(.paragraphStyle, value: style, range: range)
    }
}
