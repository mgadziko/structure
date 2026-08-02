# Portable Rich Text Direction

Structure is macOS-first for the prototype, but the long-term product is planned for macOS, iOS, Android, Windows, and eventually other environments if the project grows that far.

The current macOS prototype uses AppKit rich text editing and stores RTF data for formatted Entry and column text. That is useful for proving the interaction quickly, but it should not become the only long-term representation of formatted text.

## Decision

Markdown should become Structure's canonical portable rich-text representation.

RTF may remain a temporary macOS editing cache or migration source, but the durable cross-platform model should be text-first and Markdown-compatible.

## Why Markdown

Markdown fits Structure because it is:

- plain text
- familiar to many users
- easy to search
- easy to diff and sync
- easier to encrypt and move between devices than opaque platform archives
- available across macOS, iOS, Android, Windows, Linux, and web tooling

This matches Structure's core principle: the user's content remains available as ordinary text, while form and structure can emerge later.

## Initial Markdown Subset

The first portable formatting subset should stay modest:

```text
bold
italic
strikethrough
bullet lists
numbered lists
links
```

Underline is not standard Markdown. If Structure keeps underline, it should be represented as a deliberate extension rather than pretending it is ordinary Markdown.

## Deferred Markdown Features

Avoid these until there is a clear need:

```text
tables
embedded HTML
footnotes
images
code fences
custom block syntax
complex style sheets
```

## Implementation Direction

Near term:

- keep the current macOS rich text editor
- keep storing plain text as canonical searchable content
- treat RTF as prototype presentation data
- avoid adding more formatting features that cannot map cleanly to Markdown

Later:

- add a Markdown storage field or document representation
- migrate existing RTF formatting into the supported Markdown subset where possible
- use platform-native editors/renderers as views over the same Markdown content
- keep Entry creation frictionless and avoid exposing Markdown syntax unless the user chooses to type it directly

## Open Questions

- Should Structure store Markdown only, or Markdown plus a platform-specific render cache?
- Should the editor show literal Markdown markers, rendered formatting, or a hybrid?
- How should underline be represented if we keep it?
- How should partial rich text spans in secondary columns map to Markdown?
- Should list state be stored as literal Markdown markers or structured spans rendered as Markdown on export?
