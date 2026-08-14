# View Criteria Test Plan

This plan verifies the View Criteria workflow.

## Setup

1. Launch `dist/Structure.app`.
2. Open a Library with several Entries.
3. Use or create a user-created View with at least one secondary column.
4. Enter repeated values in that column, such as `Proposal`, `Budget`, and `Pledge`.

## Create Single Criteria

1. Open the user-created View.
2. Choose `Criteria > Add/Modify Criteria`.
3. Select the secondary column.
4. Begin typing an existing value from that column, such as `Pro`.
5. Confirm the value field offers autocomplete suggestions from the selected column.
6. Complete or enter `Proposal`.
7. Click `Apply`.

Expected result: the View shows only Entries whose selected column value is exactly `Proposal`, ignoring capitalization differences.

## Create Multiple Criteria

1. Open the same user-created View.
2. Choose `Criteria > Add/Modify Criteria`.
3. Leave the existing `Project = Proposal` row in place.
4. Use the blank row below it to add another criterion, such as `People = Sarah Wells`.
5. Confirm the second value field offers autocomplete suggestions from the selected `People` column.
6. Click `Apply`.

Expected result: the View shows only Entries matching both criteria. The relationship is `AND`, not `OR`.

## Edit Multiple Criteria

1. Open a View that already has multiple Criteria.
2. Choose `Criteria > Add/Modify Criteria`.

Expected result: every existing Criterion row is pre-populated with its selected column and value.

3. Click the remove control on one existing Criterion row.
4. Click `Apply`.

Expected result: only that Criterion is removed. The other Criteria remain active.

## Active Criteria Status

1. Choose `Criteria > Show Active Criteria`.

Expected result: Structure displays every active criteria, such as `Project = Proposal` and `People = Sarah Wells`.

2. Look at the filtered column headings.

Expected result: every column heading used by Criteria is green. In Dark Mode it should be a brighter green; in Light Mode it should be darker.

## Header Criteria Shortcut

1. Apply Criteria to a column.
2. Look at that column heading.
3. Click the Criteria icon beside the green heading.

Expected result: the `Add/Modify Criteria` dialog opens directly.

## Remove Criteria

1. Apply multiple Criteria to a View.
2. Choose `Criteria > Remove Criteria`.

Expected result: Structure shows a removal dialog with checkboxes for each active Criteria.

3. Check one Criteria and click `Remove Selected`.

Expected result: only the checked Criteria is removed.

4. Reopen `Criteria > Remove Criteria`, click `Select All`, then click `Remove Selected`.

Expected result: all active Criteria are removed.

## Persistence

1. Apply multiple Criteria to a user-created View.
2. Quit Structure.
3. Relaunch Structure.
4. Open the same View.

Expected result: the Criteria are still active and the filter indicator is visible.

## All Entries

1. Open `All Entries`.
2. Open the View menu.

Expected result: `Add/Modify Criteria` is unavailable for `All Entries`.

3. Open the Criteria menu.

Expected result: `Add/Modify Criteria` and `Remove Criteria` are unavailable for `All Entries`.

## Criteria Menu

1. Open the `Criteria` menu.

Expected result: the menu contains `Show Active Criteria`, `Add/Modify Criteria`, `Remove Criteria`, and `Save Criteria as Category Rule...`.

2. Choose `Criteria > Add/Modify Criteria`.

Expected result: the Criteria dialog shows existing Criteria rows and one blank row, with no Clear All command in the dialog.

3. Choose `Criteria > Remove Criteria`.

Expected result: the removal dialog shows active Criteria in a scrolling checkbox list with `Select All`, `Cancel`, and `Remove Selected`.

## Window Frame Persistence

1. Move and resize the Structure window.
2. Quit Structure.
3. Relaunch Structure.

Expected result: the window reopens at the previous size and position rather than centered.

## Per-View Criteria

1. Apply Criteria to one user-created View.
2. Switch to another View.

Expected result: the second View does not inherit the first View's Criteria unless it already had its own Criteria set.

3. Switch back to the first View.

Expected result: the first View's Criteria are restored.

## Save Criteria as Category Rule

1. In a user-created View, make sure at least one visible column is defined as `Category`.
2. Apply Criteria that identify a meaningful set of rows, such as `Project = Proposal`.
3. Choose `Criteria > Save Criteria as Category Rule...`.
4. Select the Category column to fill, such as `People`.
5. Enter a Category value, such as `Sarah Wells`.
6. Click `Save Rule`.

Expected result: matching Entries whose target Category cell is empty are filled with the chosen Category value.

7. Edit another Entry so it newly matches the saved Criteria.

Expected result: the target Category cell is filled automatically if it was empty.

8. Repeat with an Entry whose target Category cell already has a different value.

Expected result: the existing explicit Category value is preserved and not overwritten by the rule.

## Assignment Inspector

1. Save a Criteria-based Category Rule that fills a Category cell.
2. Look at a cell filled by the rule.

Expected result: the cell shows a subtle rule-created assignment badge.

3. Click the badge.

Expected result: Structure opens an Assignment inspector showing the column, value, source, and rule detail.

4. Click `Make Explicit`.

Expected result: the cell keeps the same value, but it is now treated as an explicit user assignment and the rule-created badge disappears.

## Column And Sort Behavior

1. Apply Criteria to a View.
2. Sort the visible rows by a column heading.

Expected result: sorting happens within the filtered rows only.

3. Edit a cell so that it no longer matches the Criteria.

Expected result: after editing ends or the View refreshes, that row no longer appears in the filtered View.
