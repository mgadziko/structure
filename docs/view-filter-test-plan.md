# View Criteria Test Plan

This plan verifies the View Criteria workflow.

## Setup

1. Launch `dist/Structure.app`.
2. Open a Library with several Entries.
3. Use or create a user-created View with at least one secondary column.
4. Enter repeated values in that column, such as `Proposal`, `Budget`, and `Pledge`.

## Create Single Criteria

1. Open the user-created View.
2. Choose `View > View Criteria...`.
3. Select the secondary column.
4. Begin typing an existing value from that column, such as `Pro`.
5. Confirm the value field offers autocomplete suggestions from the selected column.
6. Complete or enter `Proposal`.
7. Click `Apply`.

Expected result: the View shows only Entries whose selected column value is exactly `Proposal`, ignoring capitalization differences.

## Create Multiple Criteria

1. Open the same user-created View.
2. Choose `View > View Criteria...`.
3. Leave the existing `Project = Proposal` row in place.
4. Use the blank row below it to add another criterion, such as `People = Sarah Wells`.
5. Confirm the second value field offers autocomplete suggestions from the selected `People` column.
6. Click `Apply`.

Expected result: the View shows only Entries matching both criteria. The relationship is `AND`, not `OR`.

## Edit Multiple Criteria

1. Open a View that already has multiple Criteria.
2. Choose `View > View Criteria...`.

Expected result: every existing Criterion row is pre-populated with its selected column and value.

3. Click the remove control on one existing Criterion row.
4. Click `Apply`.

Expected result: only that Criterion is removed. The other Criteria remain active.

## Filter Indicator

1. Look near the View pulldown.

Expected result: a quiet indicator appears showing the current criteria, such as `Project = Proposal and People = Sarah Wells`.

2. Look at the filtered column headings.

Expected result: every column heading used by Criteria is green. In Dark Mode it should be a brighter green; in Light Mode it should be darker.

## Criteria Toolbar Buttons

1. Use the Add Criteria button beside the View pulldown.

Expected result: it opens the same `View Criteria` dialog as the View menu command.

2. Use the Clear Criteria button beside the View pulldown.

Expected result: it asks for confirmation before clearing criteria.

## Header Criteria Shortcut

1. Apply Criteria to a column.
2. Look at that column heading.
3. Click the Criteria icon beside the green heading.

Expected result: the `View Criteria` dialog opens directly.

## Clear Criteria

1. Choose `View > View Criteria...`.
2. Click `Clear`.

Expected result: the View returns to showing all Entries for that View.

3. Apply criteria again.
4. Choose `View > Clear Criteria`.

Expected result: Structure shows `Clear Criteria Are you sure?` with `Cancel` and `OK`.

5. Click `OK`.

Expected result: the criteria clears.

## Persistence

1. Apply multiple Criteria to a user-created View.
2. Quit Structure.
3. Relaunch Structure.
4. Open the same View.

Expected result: the Criteria are still active and the filter indicator is visible.

## All Entries

1. Open `All Entries`.
2. Open the View menu.

Expected result: `View Criteria...` is unavailable for `All Entries`.

3. Confirm Add Criteria and Clear Criteria buttons are unavailable or inert for `All Entries`.

## Per-View Criteria

1. Apply Criteria to one user-created View.
2. Switch to another View.

Expected result: the second View does not inherit the first View's Criteria unless it already had its own Criteria set.

3. Switch back to the first View.

Expected result: the first View's Criteria are restored.

## Save Criteria as Category Rule

1. In a user-created View, make sure at least one visible column is defined as `Category`.
2. Apply Criteria that identify a meaningful set of rows, such as `Project = Proposal`.
3. Choose `View > Save Criteria as Category Rule...`.
4. Select the Category column to fill, such as `People`.
5. Enter a Category value, such as `Sarah Wells`.
6. Click `Save Rule`.

Expected result: matching Entries whose target Category cell is empty are filled with the chosen Category value.

7. Edit another Entry so it newly matches the saved Criteria.

Expected result: the target Category cell is filled automatically if it was empty.

8. Repeat with an Entry whose target Category cell already has a different value.

Expected result: the existing explicit Category value is preserved and not overwritten by the rule.

## Column And Sort Behavior

1. Apply Criteria to a View.
2. Sort the visible rows by a column heading.

Expected result: sorting happens within the filtered rows only.

3. Edit a cell so that it no longer matches the Criteria.

Expected result: after editing ends or the View refreshes, that row no longer appears in the filtered View.
