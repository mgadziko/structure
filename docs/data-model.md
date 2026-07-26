# Data Model Sketch

This document defines the first working data model for Structure. It is not a final schema, but it should be concrete enough to guide the first macOS prototype.

The model should support frictionless Entry creation now and remain compatible with later categorization, views, local full-text search, encryption, and one-person multi-device sync.

## Model Goals

The first model should provide:

- durable local persistence
- stable identifiers
- creation, modification, capture, and deletion timestamps
- free-form Entry bodies
- extracted Items inside Entries
- flexible Categories
- Assignments between Entries, Items, and Categories
- saved Views as live lenses over Entries
- deterministic Rules for suggestions and auto-assignment
- a Change Log suitable for future sync

Version 1 is local-only, but destructive deletion, unstable identifiers, and schema assumptions that block future sync should be avoided.

## Entity Overview

```text
Entry
  user-authored unit of information

Item
  detected or extracted unit inside an Entry

Category
  organizing concept that can behave like a tag, field, value, or hierarchy node

Assignment
  relationship connecting an Entry or Item to a Category

View
  saved live lens over Entries

Rule
  deterministic instruction for suggesting or applying Assignments

ChangeLogEntry
  durable record of local mutations for undo, audit, and future sync
```

## Entry

An Entry is the primary human-authored unit of information.

Fields:

```text
id
body_plain_text
body_rich_text_data nullable
created_at
updated_at
captured_at
deleted_at nullable
```

Notes:

- `id` should be stable and globally unique enough for future sync.
- `body_plain_text` is canonical for search and semantic analysis.
- `body_rich_text_data` stores modest presentation data when needed.
- `created_at` records when the database object was created.
- `captured_at` records when the information should be treated as captured.
- `updated_at` changes when the Entry content or meaningful metadata changes.
- `deleted_at` supports tombstones for future sync-safe deletion.
- Entries are born unnamed.
- Display names should be derived from body excerpt and timestamp unless the user later adds optional title metadata.

Possible later fields:

```text
title nullable
source nullable
archived_at nullable
pinned_at nullable
```

## Item

An Item is a detected or extracted unit inside an Entry.

Fields:

```text
id
entry_id
kind
text
normalized_value nullable
start_offset nullable
end_offset nullable
confidence nullable
created_at
updated_at
deleted_at nullable
```

Possible `kind` values:

```text
word
phrase
person_candidate
date
time
number
amount
url
email
phone
address
identifier
topic_candidate
action_candidate
```

Notes:

- Items are semantic observations, not necessarily user-visible records.
- `start_offset` and `end_offset` locate the Item in the Entry's plain text when applicable.
- `normalized_value` allows dates, numbers, URLs, or identifiers to be queried consistently.
- Items may be regenerated when Entry text changes, but user-confirmed structure should not be silently lost.

## Category

A Category is an organizing concept.

Fields:

```text
id
name
kind nullable
parent_id nullable
created_at
updated_at
deleted_at nullable
```

Possible `kind` values:

```text
generic
person
project
topic
date
place
action
number
text
status
```

Notes:

- Categories can be hierarchical through `parent_id`.
- A Category's meaning should not be limited to a tag. It may act as a field, value, view heading, or inferred concept depending on context.
- Category aliases should be represented separately so name changes do not destroy matching behavior.

## Category Alias

A Category Alias is a matchable name or phrase for a Category.

Fields:

```text
id
category_id
alias
match_mode
created_at
updated_at
deleted_at nullable
```

Possible `match_mode` values:

```text
exact
case_insensitive
word_boundary
phrase
pattern
```

## Assignment

An Assignment connects an Entry or Item to a Category.

Fields:

```text
id
entry_id nullable
item_id nullable
category_id
state
source
confidence nullable
reason nullable
created_at
updated_at
deleted_at nullable
```

Possible `state` values:

```text
explicit
inferred
suggested
rejected
```

Possible `source` values:

```text
user
alias_match
rule
parser
view_context
import
system
```

Notes:

- An Assignment may target an Entry directly or target an Item inside an Entry.
- User decisions should be preserved. If the user rejects a suggestion, Structure should avoid repeatedly making the same suggestion without a new reason.
- `reason` should support concise explanations such as `matched alias Fred` or `parsed date next Tuesday`.

## View

A View is a saved live lens over Entries.

Fields:

```text
id
name
view_definition
created_at
updated_at
deleted_at nullable
```

Notes:

- `view_definition` can begin as structured JSON.
- Views may filter, group, sort, and display Entries according to Categories, Assignments, text search, dates, computed predicates, or rule output.
- Editing within a View may create view-implied Assignments.

Example view definition, conceptual only:

```json
{
  "filter": {
    "category": "Fred"
  },
  "sort": ["captured_at desc"],
  "columns": ["body", "captured_at", "categories"]
}
```

## Rule

A Rule describes deterministic logic for suggesting or applying Assignments.

Fields:

```text
id
name
enabled
trigger_definition
action_definition
created_at
updated_at
deleted_at nullable
```

Notes:

- Rules should be explainable.
- AI-assisted suggestions may be added later, but v1 should not depend on them.
- Rule definitions can begin as structured JSON, then be formalized after the prototype proves the interaction.

## ChangeLogEntry

A ChangeLogEntry records durable mutations.

Fields:

```text
id
device_id nullable
sequence_number
entity_type
entity_id
operation
payload
created_at
```

Possible `operation` values:

```text
create
update
delete
restore
assign
unassign
suggest
reject
```

Notes:

- The v1 app is local-only, so `device_id` may initially be a local constant.
- The Change Log should help with debugging, undo, audit, and future sync.
- Deletion should generally create tombstones rather than immediately removing durable records.

## Storage Direction

SQLite is the likely local database for the first macOS prototype.

Reasons:

- mature and reliable
- available on all target platforms
- good fit for local-first storage
- supports transactions
- supports full-text search through FTS
- easy to back up as a local file

The first schema should include explicit migrations from the beginning, even if there is only one migration at first.

## Encryption And Search Notes

Encryption should be planned, but not allowed to block the first local prototype.

The model should assume:

- local search indexes are derived from decrypted local content
- future sync packets can be encrypted independently from local storage
- sensitive payload encryption may affect how full-text indexing is implemented
- keys and device enrollment are future concerns, not v1 UI concerns

## Open Questions

- Should rich text be stored as RTF, attributed string archive data, Markdown-like markup, or another portable representation?
- Should extracted Items be stored permanently, regenerated on demand, or both?
- Should Category hierarchy allow multiple parents later?
- How should view-implied Assignments be represented so the user can understand and undo them?
- What is the minimum useful query syntax for the first prototype?
