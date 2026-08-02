# View Behavior Test Plan

This plan verifies the current View-level behavior in the macOS prototype.

## Setup

1. Launch `dist/Structure.app`.
2. Open a Library with more than one View.
3. Use or create a View with enough columns to overflow the window width.
4. Use or create at least one Category column with repeated values such as `Brown`, `Blue`, and `Red`.

## Launch And Open Library Position

1. Quit Structure.
2. Relaunch Structure.

Expected result: the View opens with the leftmost row number, Created column, and Entry column visible.

3. Use `File > Open Library`.

Expected result: the opened Library's View also starts at the left edge. Extra columns should overflow to the right.

## Horizontal Scrolling

1. Narrow the View window until some right-side columns no longer fit.

Expected result: a horizontal scrollbar appears at the bottom of the View area.

2. Scroll horizontally.

Expected result: column headers and Entry rows move together.

3. Scroll back to the far left.

Expected result: the row number, Created, and Entry columns are visible again.

## Vertical Top Pinning

1. Use a View with fewer rows than can fill the visible window height.
2. Make the window taller.

Expected result: rows remain pinned near the top of the View area instead of centering vertically.

## View Pulldown

1. Open the View pulldown above the formatting bar.

Expected result: the control shows the current View name.

2. Choose another View.

Expected result: Structure opens that View without changing Libraries.

3. Open the View pulldown again.

Expected result: other Views are listed alphabetically, and the current View is not repeated as a selectable item.

4. Choose `New ...`.

Expected result: Structure creates and opens a new View.

## View Rename

1. Click the pencil button beside the View pulldown.
2. Rename the current View.

Expected result: the View name changes and persists after quit/relaunch.

## Category Column Autocomplete

1. In a Category column, type the beginning of an existing Category value with different casing, such as `bro` when `Brown` already exists.

Expected result: the ghost completion preserves the original Category capitalization.

2. Press Tab.

Expected result: the cell accepts the Category value as `Brown`, not `brown`.

3. Confirm that Category suggestions come from prior Category values before same-row Entry words.

## Markdown Storage Smoke Test

This checkpoint adds optional Markdown storage fields but does not expose Markdown editing in the UI yet.

1. Create or edit normal Entry and column text.
2. Quit and relaunch Structure.

Expected result: existing rich text and plain text behavior remains unchanged.

3. Run the automated tests.

Expected result: Entry and column Markdown fields round-trip in storage-level tests while older databases without those fields still migrate.
