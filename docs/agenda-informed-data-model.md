# Agenda-Informed Data Model

This document records what Structure should learn from Lotus Agenda without trying to recreate Agenda's DOS interface, macro system, bundled applications, or full feature set.

The useful lesson is conceptual: Agenda's visible grid was not merely a spreadsheet. It was a display and editing surface over a network of items, categories, assignments, views, and sections. Structure should preserve that deeper model while keeping its own capture experience simpler, quieter, and more modern.

## Guiding Principle

Structure should let the user capture information before the user has to structure it.

The core sequence should remain:

1. Type an Entry.
2. Create another Entry when the thought changes.
3. Let structure emerge later through columns, categories, assignments, views, suggestions, and filters.

Agenda's Quick Start introduced users in a similar order: enter information first, assign categories second, switch views third, and tailor the application later. Structure should treat that order as a product-design guardrail.

## Main Lesson From Agenda

Agenda's power came from assignments, not from cells.

In Agenda, the same item could appear in several contexts because it had relationships to several categories. Columns, section heads, and views were different ways to show or edit those relationships.

Structure should follow that pattern:

- An Entry exists once in the Library.
- A View displays Entries through a chosen perspective.
- A Column is a visible place to enter or inspect structure.
- An Assignment is the durable relationship that gives an Entry meaning.
- A cell in a column is usually an editing surface for an Assignment or value, not the primary fact itself.

This distinction matters because Structure should not grow into a conventional spreadsheet with notes attached. It should become an information manager where the same Entry can be understood from many angles.

## Vocabulary

### Library

A Library is the information boundary and persistence boundary.

For the default user story, one user has one Library. Multiple Views into that Library should correlate the same Entries. Separate Libraries are a later explicit feature for hard boundaries such as work, personal life, games, clients, archives, or scratch imports.

Separate Libraries should eventually have separate databases, encryption boundaries, sync identities, and search indexes.

### Entry

An Entry is the user-authored unit of captured information.

Agenda called its atomic unit an item, often described as a short line or two of information. Structure should keep Entry as the user-facing term because it matches the writing experience better and leaves room for richer text.

An Entry should be born with:

- stable id
- body text
- optional rich text presentation data
- created timestamp
- modified timestamp
- captured timestamp
- deletion tombstone when needed

An Entry should not require:

- title
- file name
- folder
- category
- column value
- type
- template
- formatting

### Item

An Item is a detected or extracted unit inside an Entry.

Examples include a word, phrase, name, date, number, phone number, URL, place, action candidate, or topic candidate.

Items are semantic observations. They are not necessarily rows in the main UI. They can help Structure suggest or explain Assignments later.

The user should not need to think about Items during capture.

### Category

A Category is a named organizing concept.

In Agenda, categories could behave as section heads, column heads, column entries, hierarchy nodes, and assignment targets. Structure should keep that flexibility.

A Category may represent:

- person
- project
- topic
- place
- action
- date-related concept
- status
- priority
- free-form grouping
- other user-defined meaning

Categories should allow aliases so that renaming a Category does not destroy matching behavior.

### Category Family

A Category Family is a parent concept with related child values.

Examples:

```text
Priority
  High
  Medium
  Low

Status
  Wanted
  Purchased

Freshness
  Fresh
  Spoiled
```

Category Families should support two important behaviors:

- Assignment to a child value can imply membership in the parent family.
- Some families may be mutually exclusive, while others may allow multiple values.

This maps well to the earlier Type and State distinction:

- Type-like families usually describe stable classifications.
- State-like families may change over time and may need effective dates.

### Column

A Column is a View-specific display and editing surface.

A newly created Column should default to no definition. This preserves frictionless creation and avoids forcing the user to decide what a field means too early.

Later, at the user's convenience, a Column may become one of several kinds:

```text
Undefined
Category
Text Attribute
Date
Number
State
Computed
```

Column behavior should depend on its kind:

- Undefined columns accept plain values and remain low-ceremony.
- Category columns assign Entries to Categories or child Categories.
- Text Attribute columns store descriptive text values.
- Date columns store parsed or manually entered dates.
- Number columns store numeric values and can later support calculations.
- State columns describe a current condition, possibly with history.
- Computed columns display derived values without directly storing user text.

Agenda allowed adding an existing category as a column head, causing existing assignments to appear in the new column. Structure should preserve this idea: adding a known Column/Category to a View should reveal existing relevant data, not create an empty duplicate.

### Assignment

An Assignment is the durable relationship between an Entry or Item and a Category, Attribute, or typed value.

Assignments are the heart of the model.

An Assignment should record:

- subject: Entry or Item
- target: Category, Attribute, Column definition, or value type
- value, when applicable
- source
- state
- confidence, when applicable
- explanation or reason
- created timestamp
- modified timestamp
- effective timestamp, when applicable
- ended timestamp, when applicable
- deletion tombstone when needed

Assignment sources should include:

```text
user
view_context
column_edit
alias_match
parser
rule
import
system
```

Assignment states should include:

```text
explicit
suggested
inferred
accepted
rejected
superseded
```

Open design question: whether `explicit` and `accepted` should be separate states or whether accepted suggestions should become explicit assignments with preserved provenance.

### Value

A Value is the content carried by an Assignment or Column cell.

Possible value kinds:

```text
text
category_ref
date
time
datetime
number
boolean
rich_text
computed
```

The model should avoid assuming that all values are strings. Dates and numbers should be typed early enough that sorting, filtering, and later calculations are not built on fragile text parsing.

### View

A View is a saved lens into a Library.

A View can determine:

- visible Columns
- Column order
- Column widths
- sorting
- filtering
- grouping
- sectioning
- display preferences

A View is not a separate database. Editing inside a View edits Entries and Assignments in the Library.

A new View may start with only the Entry column, but it should be able to reveal existing Columns/Categories when the user adds them. This supports the Agenda-like model that Views are perspectives over existing information.

### Section

A Section is a group within a View.

Agenda used section heads to group items by a Category or date. Structure should reserve this concept but not rush to implement it.

Later examples:

- group by Project
- group by Person
- group by Date
- group by State
- group uncategorized Entries separately
- collapse or expand sections
- hide empty sections

Sections should be View behavior, not a new kind of Library boundary.

### Rule Or Detector

A Rule or Detector notices possible structure.

Rules should begin deterministic and explainable. AI-assisted inference can come later, but Structure should not depend on opaque inference for its first useful model.

Examples:

- exact text match to a Category alias
- date parser
- phone number parser
- Entry shorter than three words
- value is numeric
- value matches a previously used Category value in this Column

## Explicit Versus Inferred Structure

Agenda could automatically assign Categories when it recognized names, dates, or category terms in item text. That is powerful, but it can also surprise modern users.

Structure should be more cautious at first.

Recommended progression:

1. Support explicit Assignments created by direct user action.
2. Detect possible Assignments quietly.
3. Show suggestions without moving Entries unexpectedly.
4. Let the user accept or reject suggestions.
5. Preserve the reason for every accepted or rejected suggestion.
6. Only later add optional automatic application rules.

This keeps the app trustworthy. The user should never feel that Structure rearranged information behind their back.

## Column Lifecycle

Columns should mature gradually.

### Stage 1: Undefined

The user creates a Column and names it. The Column accepts text. No schema decision is required.

This is the correct default for frictionless use.

### Stage 2: Pattern Emerges

Structure notices repeated values or parseable values.

Examples:

- `High`, `Medium`, `Low`
- dates
- names
- dollar amounts
- repeated places
- repeated status words

Structure may offer lightweight suggestions, such as "Treat this column as a Category column" or "Treat this column as Date."

### Stage 3: User Defines Meaning

The user may define the Column as a Category, Date, Number, Text Attribute, State, or Computed column.

Existing values should be migrated into typed Assignments where possible, with review for ambiguous values.

### Stage 4: View Reuse

The user can add this Column or Category to another View. Existing Assignments appear automatically in the relevant rows.

This is one of the important Agenda-like moments: structure created in one perspective becomes useful in another.

## Autocomplete Direction

Agenda's autocomplete was context-aware. It did not merely complete arbitrary text; it completed from relevant categories and values.

Structure's autocomplete should evolve in the same direction:

- In the Entry column, avoid aggressive autocomplete so capture stays plain.
- In undefined secondary columns, suggest from the current Entry and previous values in that Column.
- In Category columns, suggest from the Category Family.
- In Date columns, help parse dates.
- In Number columns, avoid word completions and prioritize valid numeric entry.

Ghost completion is preferable to intrusive popup behavior because it keeps typing calm. Tab can accept a suggestion, but Tab must also remain predictable for cell navigation.

Open design question: when a ghost completion exists and the user presses Tab, should Tab accept the completion first, then a second Tab move to the next cell?

## Date Handling

Dates should be descriptive before they are operational.

A Date can narrow or describe an Entry without making the Entry a task, appointment, deadline, or reminder.

Examples:

- `Mark's Birthday`
- `Holiday`
- `July 26, 2026`
- `next Tuesday`
- `past`
- `present`
- `pending`

Structure should avoid assuming that a Date means "due date." A Date may be past, present, pending, historical, documentary, recurring, or merely descriptive.

The model should eventually support Date-related States such as Past, Present, and Pending, but the exact definition of Present remains deferred.

## Sorting And Stability During Editing

Agenda-like views can rearrange information dynamically, but Structure must protect editing focus.

Rows should not sort or re-sort while a user is actively typing or editing a cell. If a committed edit changes the row's sort position, Structure should keep the edited Entry visible and keep focus understandable.

This is a user-trust issue, not just a polish issue.

## What Not To Copy From Agenda Yet

Structure should not currently pursue:

- Agenda macro syntax
- bundled starter applications as product centerpieces
- complex report generation
- printing workflows
- scheduling and alarms as a core early feature
- automatic hidden assignments that immediately rearrange Views
- DOS-style function-key UI patterns
- requiring users to choose a file before capture

These may contain historical ideas worth studying later, but they should not drive the current prototype.

## Implementation Implications

The next implementation phase should favor foundation over new visible features.

Likely model additions:

- stable Assignment table
- typed Assignment values
- Category table with aliases
- Category hierarchy or Category Family representation
- ViewColumn definitions that can point to Category/Attribute definitions
- provenance fields for assignment source and state
- migration path from current user-column text values into Assignment-backed values

Likely UI implications:

- keep the Entry column fast and quiet
- keep new Columns undefined by default
- add opt-in Column definition later
- preserve existing values when a Column is later defined
- make adding an existing Column/Category to a View reveal existing data
- make suggestions visible but non-disruptive

## Open Questions

- Is Assignment a single unified table, or should CategoryAssignment, AttributeAssignment, and CellValue remain separate tables with a shared conceptual layer?
- Should Category Family be its own table, or is a parent Category enough for the first implementation?
- Should accepted suggestions become explicit Assignments, or remain accepted inferred Assignments?
- Should Column definitions live globally in the Library while ViewColumn stores only display settings?
- How should undefined Column values migrate when the Column later becomes typed?
- What is the minimum UI for reviewing suggested Assignments without cluttering capture?
- Should Tab accept ghost completion before moving focus, or should another key accept completions?

## Recommended Next Step

Before adding more Agenda-like UI, implement or design the persistence layer for Assignments and typed column values.

The first code-facing goal should be:

```text
Secondary column text values are stored in a way that can later become typed Assignments without data loss.
```

That goal preserves the current prototype while preparing Structure for the deeper Agenda model.
