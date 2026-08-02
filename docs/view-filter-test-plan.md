# View Filter Test Plan

This plan verifies the first-pass View Criteria workflow.

## Setup

1. Launch `dist/Structure.app`.
2. Open a Library with several Entries.
3. Use or create a user-created View with at least one secondary column.
4. Enter repeated values in that column, such as `Proposal`, `Budget`, and `Pledge`.

## Create Criteria

1. Open the user-created View.
2. Choose `View > View Criteria...`.
3. Select the secondary column.
4. Begin typing an existing value from that column, such as `Pro`.
5. Confirm the value field offers autocomplete suggestions from the selected column.
6. Complete or enter `Proposal`.
7. Click `Apply`.

Expected result: the View shows only Entries whose selected column value is exactly `Proposal`, ignoring capitalization differences.

## Filter Indicator

1. Look near the View pulldown.

Expected result: a quiet indicator appears showing the current criteria, such as `Project = Proposal`.

2. Look at the filtered column heading.

Expected result: the column heading for the criteria column is green. In Dark Mode it should be a brighter green; in Light Mode it should be darker.

## Criteria Toolbar Buttons

1. Use the Add Criteria button beside the View pulldown.

Expected result: it opens the same `View Criteria` dialog as the View menu command.

2. Use the Clear Criteria button beside the View pulldown.

Expected result: it asks for confirmation before clearing criteria.

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

1. Apply criteria to a user-created View.
2. Quit Structure.
3. Relaunch Structure.
4. Open the same View.

Expected result: the criteria is still active and the filter indicator is visible.

## All Entries

1. Open `All Entries`.
2. Open the View menu.

Expected result: `View Criteria...` is unavailable for `All Entries`.

3. Confirm Add Criteria and Clear Criteria buttons are unavailable or inert for `All Entries`.

## Per-View Criteria

1. Apply criteria to one user-created View.
2. Switch to another View.

Expected result: the second View does not inherit the first View's criteria unless it already had its own criteria set.

## Column And Sort Behavior

1. Apply criteria to a View.
2. Sort the visible rows by a column heading.

Expected result: sorting happens within the filtered rows only.

3. Edit a cell so that it no longer matches the criteria.

Expected result: after editing ends or the View refreshes, that row no longer appears in the filtered View.
