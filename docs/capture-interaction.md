# Capture Interaction Spec

This document defines the first Structure capture experience. It is intentionally narrow: before Structure can become a powerful information manager, it must make Entry creation feel frictionless.

## Principle

Frictionless creation means the user can put an Entry into Structure before making decisions about naming, filing, formatting, categorizing, or saving. The one-Library model supports this directly: the user types Entries, quits when done, and never has to manually save a file during normal use.

The capture surface should communicate: write first, structure later.

## First Screen

The first screen should be a sparse scrolling surface of Entries.

The dominant visual element is text. Controls should be absent or nearly absent from the main creation surface. The user should not feel that the app is asking them to configure a record, fill out a form, choose a location, or operate a document editor.

The initial window should support:

- continuous vertical scrolling through Entries
- immediate typing focus
- automatic persistence
- a clear current Entry insertion point
- a fast New Entry action, `Command-E`
- an optional List action

The initial window should avoid:

- save dialogs
- required Entry names or document names
- category pickers
- visible formatting toolbars
- page up/page down controls
- template choosers
- mandatory fields
- modal setup before writing

## Primary Actions

### Type

Typing is the default state. The user should be able to launch the app and begin typing into the current Entry immediately.

No explicit save action should be required. The Entry should be persisted automatically as it is created and edited.

### New Entry

New Entry is the main structural action during capture.

When the user decides the current thought should be separate from the next thought, they press New Entry, `Command-E`. Structure creates a new Entry, assigns timestamps, persists it, and moves typing focus into the new Entry.

New Entry should not ask for:

- a title
- a file name
- a folder
- a category
- a type
- a template
- a style

The new Entry is born unnamed. Its visible identity can be derived from its body excerpt and timestamp until the user optionally adds more structure later.

### List

List is the only optional creation-time aid in the first capture model.

It exists for thoughts that naturally contain segmented parallel ideas. It should help make content clearer without turning capture into formatting work.

List should be lightweight and reversible. It should not require the user to choose among many list styles during capture.

## Scrolling Model

Scrolling is the primary navigation mechanism in the capture surface.

The user should be able to scroll upward to revisit earlier Entries, edit or inspect them, and scroll downward to return to the latest Entry. This should feel like moving through a living stream of captured thoughts, not like paging through documents.

Dedicated page up, page down, and similar navigation controls should not appear in the primary capture UI unless later testing shows they are necessary.

Keyboard and platform-native scrolling behavior should still work.

## Persistence

Every Entry should receive durable metadata automatically:

- stable id
- created_at
- updated_at
- captured_at
- deleted_at, when applicable

Creation and modification timestamps are system-managed. The user should not be asked to name or save an Entry at creation time.

For empty or nearly empty Entries, Structure may display a fallback label derived from timestamp, such as an untitled Entry created at a specific time. This is a display fallback, not a required user-facing naming step.

## Capture And Formatting

Formatting should not interrupt capture.

The first capture surface may support modest rich text later, but bold, italic, font, and styling choices should not be visually foregrounded during Entry creation. Formatting belongs to refinement, not initial capture.

The canonical Entry body should remain searchable text or cleanly extractable text.

## Capture And Structure

Structure may notice Items, suggest Categories, or infer Assignments in the background, but these should not interrupt typing.

The first capture flow should not stop the user to ask whether `Fred` is a person, whether `next Tuesday` is a date, or whether `invoice` is a topic. Those questions can be deferred to later review, subtle suggestions, or view-based refinement.

## First Prototype Acceptance Criteria

The first prototype should pass this simple test:

1. Open Structure.
2. Type a sentence.
3. Press New Entry with `Command-E`.
4. Type another sentence.
5. Scroll back to the first Entry.
6. Scroll down to the latest Entry.
7. Quit and reopen the app.
8. Confirm both Entries remain, with timestamps preserved.

If the user had to name, save, file, categorize, format, or configure anything during those steps, the prototype failed the frictionless creation principle.

## Future: Window-Level Category Context

Deferred feature, not part of the first prototype.

While typing Entries, the user may realize that the current window or View has a common Category that should apply to Entries already created there and to future Entries created there.

Example:

1. The user creates two Entries that are really part of a shopping list.
2. The user invokes a keyboard command, possibly `Command-L` for List.
3. Structure asks for or accepts a Category name, such as `Shopping`.
4. Structure assigns that Category to the existing Entries in the current window or View.
5. Future Entries created in that same window or View inherit the same Category context until the context is changed or cleared.

This feature should preserve frictionless creation. It should let the user add shared structure after the thought stream has already begun, without requiring every Entry to be manually assigned later.

Design notes:

- The Category context belongs to the specific window or View, not necessarily the entire Library.
- Applying a Category context should be visible and reversible.
- The user should be able to understand which Entries were affected retroactively.
- Future inherited assignments should preserve provenance, such as `view_context` or `window_context`.
- Shortcut choice is not final. `Command-L` is memorable for List, but may conflict with common platform conventions.

## Open Question: Latest Entry Placement

The first prototype currently treats the Entry stream like a chronological writing surface, with newer Entries appearing lower in the scroll flow and the window scrolling to the latest Entry.

This should remain open for design testing. There are two plausible models:

- newest Entry at the bottom, matching chat/log/journal expectations
- newest Entry at the top, reducing the need to scroll down after opening a window

The bottom model may feel familiar because the user writes forward through time and scrolls back to earlier Entries. The top model may be more efficient because the latest Entry is immediately visible when the window opens.

A third option is to keep newest-at-bottom ordering but always open a window directly at the latest Entry. That may preserve chronological expectations while avoiding extra work.

No final decision yet. The core requirement is that opening a window should not make the user hunt for the current Entry.

## Future: Add Column From Heading Bar

Deferred feature, not part of the first prototype.

A simple Library or View window may begin with two visible column headings:

```text
Created
Entry
```

`Created` is automatic metadata, not a decision the user makes during capture. It should appear as column 1 for now. `Entry` should appear as column 2 and remain the user's main writing surface.

When the user is working in a window and realizes that the current Entries share a useful characteristic, the user should be able to add structure directly from the heading bar without opening a schema editor.

Example workflow:

1. The window shows `Created` and `Entry` columns.
2. The user clicks in the heading bar to the left or right of the `Entry` heading.
3. Structure creates a new column heading editor in place.
4. The user types `Date`.
5. The window now shows three columns: `Created`, `Entry`, and `Date`.
6. The `Date` cells are blank unless Structure can parse dates from existing Entry text or the user fills them in.

This should feel like adding structure to the current View, not like defining a database table before capture. The user should be able to create the column at the moment the need becomes obvious.

New columns should initially have no required definition. A column may later become associated with a Category, Attribute, computed value, or parser-backed field, but that definition should happen at the user's convenience. Creating the column should not force the user to decide what kind of structure it represents.

Design notes:

- The View may include a minimal formatting bar above the column headings.
- Formatting commands should affect the selected text in the current Entry only.
- New Entries should always begin unformatted, even if the previous Entry ended with active list or text styling.
- Basic formatting controls may include font size, typeface, bold, italics, underline, strikethrough, bullet list, and numbered list.
- `Command-A` should first select all text in the current Entry. A second `Command-A` within a short interval should select all Entry text in the current column.
- The initial capture View should have `Created` and `Entry` columns.
- Column headings should be visually distinct from Entry content. Blue headings are acceptable for the prototype.
- Clicking a heading should sort by that column in ascending order by default. A second click should sort descending.
- Entry text sorting should use natural numeric-aware ordering before ordinary alphabetical ordering.
- Adding a column should preserve existing Entries.
- The new column should default to no definition rather than immediately becoming a Category or Attribute.
- The new column name may later correspond to a Category, Attribute, computed value, or parser-backed field.
- Parser-backed columns, such as `Date`, may auto-populate from Entry text when confidence is high enough.
- Blank cells are acceptable and should not imply incomplete or invalid Entries.
- The interaction should allow immediate naming and then immediate use.
- Column creation should be reversible.
- Assignments of information to labels should generally happen at the user's convenience, not merely because a column or Entry was created.
- It remains an open question whether a View row is always defined by a single Entry, as in the remembered Lotus Agenda model, or whether later Views can present multiple Entries on one row.
