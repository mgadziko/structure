# Structure Product Design

Structure is the working title for an Agenda-inspired personal information manager. The name is provisional, but useful: the product is about capturing information freely and letting structure emerge afterward.

## Product Thesis

Structure is built around a write-it-now, structure-it-later workflow.

The user should be able to enter a sentence, paragraph, clipping, task, fact, or observation without first deciding which database table, field, project, folder, or tag it belongs to. The app should then help discover, suggest, and maintain useful structure over time.

The core experience should feel like this:

1. The user writes an Entry quickly.
2. Structure notices meaningful Items inside the Entry.
3. Structure suggests or applies Categories.
4. The Entry appears in useful Views.
5. The user can correct the structure directly from any View.

The product should not become merely a notes app, tag manager, spreadsheet, outliner, task app, or document editor. It may borrow from all of those, but its identity is the live relationship between free text and emergent structure.

## Capture Principle

Entry creation is the front door of the product and should feel almost weightless. The durable phrase for this principle is frictionless creation.

Frictionless creation should remain both a product-design standard and a possible future marketing phrase: Structure should let the user create an Entry before the app asks for names, categories, locations, fields, formatting, or filing.


The user should be able to get content into Structure quickly, without deciding what kind of information it is, where it belongs, which fields it needs, what categories apply, or how it should look. The app should accept the Entry first and delay form, structure, formatting, categorization, and filing until later.

This is not a secondary convenience. It is one of the main reasons the app should exist. If creating an Entry requires intellectual overhead, the product has failed at its most important moment.

Early capture should favor:

- free typing as the default state
- a fast New Entry command, `Command-E`, for separating one Entry from the next
- immediate typing focus
- automatic persistence, with no save dialog or save-location decision during capture
- minimal required UI
- no mandatory fields
- no required category choice
- no font, bold, italic, or styling decisions before text entry
- an optional list command for segmented parallel ideas during capture
- later review and refinement instead of up-front organization

The first capture interface can be understood as three actions:

1. Type freely.
2. Press New Entry, `Command-E`, when the current thought should become separate from the next one.
3. Optionally use List when the thought naturally contains parallel points.

Everything else should wait. Saving, filing, categorizing, formatting, and view placement should happen automatically or later.

The creation UI should be sparse and austere. The main window should be mostly the Entries themselves, with typing focus preserved and controls kept out of the way. Scrolling is the primary way to move through recent Entries: the user can back up to an earlier Entry, then scroll down to return to the latest Entry. Dedicated page up, page down, and similar navigation controls should not appear in the primary capture surface unless later usability testing proves they are necessary.

## Initial Scope

The first implementation target is macOS.

Version 1 is local-only. Sync is not a v1 feature, but the model should avoid choices that would make later sync painful. Cross-platform support for Windows, Linux, iOS, and Android is a background architectural concern, not a defining constraint for the first prototype.

The first prototype should prove the core interaction rather than solve every future platform and cloud problem.

See also [Portable Rich Text Direction](portable-rich-text.md) for the current decision that Markdown should become the canonical cross-platform rich-text representation, with macOS RTF treated as a prototype implementation detail or migration source.

## Library And Window Model

The default user story is one Library per user. A Library is the underlying local database that contains Entries, Items, Attributes, Categories, Assignments, Views, Rules, and change history.

A window should not imply a separate Library. On macOS, `Command-N` should create a new Window or View, while `Command-E` should create a new Entry in the frontmost Window or View. Multiple windows should usually be different workspaces or Views into the same Library. For example, a shopping list window and a vacation-planning window should both refer to the same Library unless the user explicitly opens or creates another Library.

This matters because Structure's value depends on emergent correlation. People, dates, places, purchases, tasks, and events become more useful when they can be discovered across the user's captured information.

However, Structure should not assume that one Library is the only possible model. Some users may need hard boundaries between unrelated information worlds. Examples include personal and workplace information, a Dungeons and Dragons campaign Library separate from ordinary life, client-specific Libraries, archive Libraries, and experimental import or scratch Libraries.

Multiple Libraries should therefore be a later explicit feature, not an accidental result of opening a new window. Creating or switching Libraries can involve a deliberate user decision because it changes the information boundary. Creating an Entry should not.

The one-Library default also supports the no-Save-command paradigm. During normal use, the user should type Entries, close windows, or quit the app without manually deciding where or whether to save a file. Persistence is part of the Library, not a document-management chore.

Initial prototype assumption:

- one local Library
- one SQLite database
- one or more windows may eventually point into that Library
- no multi-Library UI in v1

Future model:

- multiple Libraries may exist
- each Library has its own database, encryption boundary, sync identity, and search index
- windows are associated with a selected Library
- cross-Library search or correlation should not happen by default

## Core Vocabulary

### Entry

An Entry is the primary human-authored unit of information. It may be a sentence, paragraph, note, task, pasted clipping, contact fact, event reminder, or other captured thought.

Entries are what the user writes, reads, searches, edits, and views.

An Entry should have first-class metadata including:

- stable id
- body text
- created_at
- updated_at
- captured_at
- deleted_at, for future sync-safe deletion

For most new Entries, created_at and captured_at will be the same. They may differ for imported notes, older paper notes, transcribed material, or information whose meaningful capture time predates database creation.

### Item

An Item is a parsed, detected, or extracted unit inside an Entry.

Items may include:

- words or phrases
- names
- dates
- times
- numbers
- amounts
- URLs
- email addresses
- phone numbers
- addresses
- identifiers
- possible topics or actions

Items are not necessarily visible as standalone records in the main UI. They are the semantic material Structure notices inside Entries.

Example:

```text
Entry:
Call Fred next Tuesday about invoice 1047.

Items:
Fred
next Tuesday
invoice
1047
```

### Category

A Category is an organizing concept. Categories may behave like tags, fields, values, hierarchy nodes, view headings, or inferred concepts depending on context.

A Category may have:

- name
- aliases
- parent category
- child categories
- optional type, such as person, date, topic, project, place, action, number, or text
- optional exclusivity rules within a category group
- optional assignment rules

Categories should be flexible enough to let the user structure information after capture, without requiring the user to define a rigid schema before capture.

### Assignment

An Assignment connects an Entry or Item to a Category.

Assignments may be:

- explicit, created by the user
- inferred, created automatically with high confidence
- suggested, pending user confirmation
- rule-generated
- view-implied, created because the user added or edited an Entry inside a View

Assignments should preserve enough provenance to explain why they exist.

Example:

```text
Entry: Call Fred next Tuesday about invoice 1047.
Assignments:
- Fred, because the text matched a person category alias
- next Tuesday, because the text contained a parsed date
- Invoice, because the text matched a topic category
```

### View

A View is a live lens over Entries.

Views may filter, group, sort, and display Entries according to Categories, Assignments, dates, text search, computed properties, and rule output. A View is not just a saved search or static report. Editing an Entry inside a View may update the Entry's Assignments.

Examples:

- Inbox
- All Entries mentioning Fred
- Entries due this week
- Entries with no Categories
- Entries containing phone numbers
- Entries shorter than three words
- Entries grouped by person
- Entries grouped by project, then due date

### Rule

A Rule describes how Structure should infer, suggest, or apply Assignments.

Rules should start deterministic and explainable. AI-assisted suggestions may be useful later, but the first system should not depend on opaque inference.

Rules may match on:

- exact text
- aliases
- regular patterns
- dates
- numbers
- Entry length
- existing Categories
- context from a View

## Text And Formatting

Structure should support modest rich text, not full document-layout complexity.

The canonical searchable body should remain plain text or cleanly extractable text. Styling should be secondary presentation data.

Early rich text scope:

- platform-appropriate font selection
- bold
- italic
- links
- possibly simple lists

Out of early scope:

- page layout
- embedded complex documents
- elaborate style sheets
- collaborative rich text editing
- formatting as semantic structure

## Local Storage

The local database should be robust from the beginning. SQLite is the likely default choice for the macOS prototype because it is mature, embeddable, portable, and supports full-text search.

The storage model should be designed with future sync in mind:

- stable ids
- created_at and updated_at on durable records
- deleted_at tombstones instead of immediate destructive deletion
- append-only change log or equivalent mutation history
- local full-text index
- explicit versioning for schema migrations

The first prototype should use real persistence rather than a throwaway in-memory model, unless a temporary sketch is clearly marked as such.

## Sync Posture

Sync is not part of version 1.

However, Structure should avoid decisions that would block future one-person, many-device sync. The likely future model is local-first with encrypted change packets exchanged through a cloud relay or mailbox. The server should ideally not need to understand user content.

The product is not initially collaborative, so simultaneous editing of the same Entry is not a primary use case. Even so, later sync will need deterministic behavior for ordering, tombstones, device identity, and conflict handling.

## Encryption Posture

Encryption should be planned from the beginning.

Version 1 does not need full end-to-end cloud sync encryption, but the architecture should account for:

- encrypted local storage or encrypted sensitive payloads
- encrypted future sync packets
- local-only search indexes
- key creation and storage
- device enrollment later
- account recovery questions later

If the future sync server cannot read content, search must remain local. That is acceptable and consistent with local-first design.

## First Prototype Goal

The first prototype should prove the magic moment:

```text
Call Fred next Tuesday about invoice 1047.
```

Structure should let the user enter this quickly, then detect or suggest useful structure such as:

- Fred as a person Category
- next Tuesday as a date Item or date Category assignment
- invoice as a topic Category
- 1047 as a number or reference Item

The Entry should then become visible through relevant Views, and the user should be able to correct or remove any inferred structure.

## Not Yet

The following are intentionally out of initial scope:

- internet sync
- collaboration
- mobile UI
- Windows and Linux UI
- cloud accounts
- AI-dependent categorization
- complex rich text layout
- plugin system
- public sharing
- enterprise administration

These may matter later. They should not distract from proving the core Entry, Item, Category, Assignment, and View model first.

## Future: Starter Libraries And Templates

Lotus Agenda shipped with several predesigned templates for specific purposes, such as client tracking and advanced planning/to-do workflows. Structure may eventually benefit from starter Libraries, starter Views, or template packs that demonstrate useful structure without forcing it on every user.

Possible future examples:

- client list with Views for client name, last contact date, sales, and purchased products
- planning Library with task states, dates, priorities, and review Views
- household/shopping starter with shopping Categories and purchased/wanted States
- project tracker with people, dates, milestones, and open loops

These should not interfere with frictionless creation. The default first-run experience should still allow immediate typing without choosing a template. Templates should be optional aids for users who want a prebuilt structure, not a required onboarding decision.
