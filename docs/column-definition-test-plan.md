# Column Definition Test Plan

This plan tests the first Column Definition workflow: changing an existing undefined column into a Category-like column while preserving the frictionless capture model and assignment-backed persistence.

## Scope

Test these behaviors:

- column creation remains frictionless
- Column Info is available after a column exists
- changing a column kind persists
- changing a column to Category preserves existing values
- reused columns across Views show the same values
- editing a reused column value updates the shared value
- duplicate column names are still prevented within a View
- sorting and editing stability still behave as expected

## Procedure

### 1. Fresh Launch

1. Open Structure.
2. Confirm the previous Library opens, or create a new test Library from `File > New Library`.
3. Confirm the window title shows the active Library name.

Expected result: Structure opens without migration errors.

### 2. Frictionless Entry Creation

1. In the current View, press `Command-E`.
2. Type `Call Sarah about the proposal`.
3. Press `Command-E`.
4. Type `Ask John about the budget`.
5. Press `Command-E`.
6. Type `Review pledge totals`.

Expected result: each `Command-E` creates a new Entry and moves typing focus into it.

### 3. Add Undefined Column

1. Click the `+` near the Entry heading.
2. Create a column named `People`.
3. Enter `Sarah` in the People cell for the Sarah Entry.
4. Enter `John` in the People cell for the John Entry.
5. Leave the third People cell blank.

Expected result: the column is immediately editable and does not require a definition at creation time.

### 4. Define Column As Category

1. Control-click or right-click the `People` column heading.
2. Choose `Column Info...`.
3. Change Kind to `Category`.
4. Click `Apply`.

Expected result: the column remains visible, existing Sarah/John values remain, and the app does not require any additional setup.

### 5. Persistence Across Relaunch

1. Quit Structure.
2. Relaunch Structure.
3. Reopen the test Library if necessary.

Expected result: the People column still appears, its values remain, and its Kind remains Category when reopened through `Column Info...`.

### 6. Reuse Column In Another View

1. Choose `File > New View`.
2. Confirm the new View starts with only the Entry column.
3. Click the `+` near the Entry heading.
4. Select or type the existing column name `People`.

Expected result: the People column appears in the new View and shows Sarah/John values from the original View.

### 7. Shared Value Editing

1. In the new View, change `Sarah` to `Sarah Wells`.
2. Open the original View.

Expected result: the original View also shows `Sarah Wells`, proving both Views share the same assignment-backed column definition.

### 8. Duplicate Prevention

1. In a View that already shows People, click `+`.
2. Try to add another column named `People`.

Expected result: the View should not create a duplicate People column.

### 9. Sorting And Editing Stability

1. Click the People heading once.
2. Confirm rows sort ascending by People value.
3. Click the People heading again.
4. Confirm rows sort descending.
5. Click into a People cell and type a multi-word value.

Expected result: sorting works after heading clicks, but the row does not jump away while actively editing.

## Notes To Record

During testing, note:

- whether `Column Info...` is discoverable enough
- whether right-click/control-click feels acceptable as the first inspector path
- whether Category as a kind needs visible indication in the heading
- whether the Kind menu needs explanatory text beyond the current brief description
- whether `Tab` behavior remains predictable in secondary columns
