# Table Navigation Test Plan

This plan verifies the current keyboard navigation behavior for Structure's row-and-column editing surface.

## Setup

1. Launch `dist/Structure.app`.
2. Open or create a Library with one View containing at least three Entries.
3. Add at least two user columns to the View.
4. Put text in some cells and leave other cells blank.

## Tab Within A Row

1. Click in the Entry cell of the first visible row.
2. Press Tab.

Expected result: focus moves to the next editable cell on the right.

3. Type text.
4. Press Tab again.

Expected result: focus moves to the next cell on the right without inserting a tab character.

## Tab To Next Row

1. Click in the rightmost editable cell of a row.
2. Press Tab.

Expected result: focus moves to the leftmost editable cell in the next visible row.

## Shift-Tab To Previous Cell

1. Click in a user-column cell.
2. Press Shift-Tab.

Expected result: focus moves to the editable cell immediately to the left.

## Shift-Tab To Previous Row

1. Click in the leftmost editable cell of a row.
2. Press Shift-Tab.

Expected result: focus moves to the rightmost editable cell in the previous visible row.

## Non-Empty Cell Focus

1. Tab into a cell that already contains text.

Expected result: the insertion point appears at the right end of the existing text. The whole cell content is not selected.

## Edge Behavior

1. Click in the rightmost editable cell of the final visible row.
2. Press Tab.
3. Click in the leftmost editable cell of the first visible row.
4. Press Shift-Tab.

Expected result: the app does not insert a tab character into either cell and does not scroll unexpectedly.

## Autocomplete Interaction

1. In a secondary column, type the beginning of text that exists in the same row's Entry.
2. Confirm that the ghost completion appears.
3. Press Tab.

Expected result: Tab accepts the ghost completion instead of moving focus. A following Tab moves focus normally.
