# Capture Interaction Spec

This document defines the first Structure capture experience. It is intentionally narrow: before Structure can become a powerful information manager, it must make Entry creation feel frictionless.

## Principle

Frictionless creation means the user can put an Entry into Structure before making decisions about naming, filing, formatting, categorizing, or saving.

The capture surface should communicate: write first, structure later.

## First Screen

The first screen should be a sparse scrolling surface of Entries.

The dominant visual element is text. Controls should be absent or nearly absent from the main creation surface. The user should not feel that the app is asking them to configure a record, fill out a form, choose a location, or operate a document editor.

The initial window should support:

- continuous vertical scrolling through Entries
- immediate typing focus
- automatic persistence
- a clear current Entry insertion point
- a fast New Entry action
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

When the user decides the current thought should be separate from the next thought, they press New Entry. Structure creates a new Entry, assigns timestamps, persists it, and moves typing focus into the new Entry.

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
3. Press New Entry.
4. Type another sentence.
5. Scroll back to the first Entry.
6. Scroll down to the latest Entry.
7. Quit and reopen the app.
8. Confirm both Entries remain, with timestamps preserved.

If the user had to name, save, file, categorize, format, or configure anything during those steps, the prototype failed the frictionless creation principle.
