# Boolean Criteria Design

Structure's first boolean Criteria behavior is intentionally modest:

- Criteria from different columns are combined as `AND`.
- Multiple Criteria from the same column are combined as `OR`.

Example:

```text
Project = Proposal
Project = Budget
People = Sarah
```

This means:

```text
(Project = Proposal OR Project = Budget) AND People = Sarah
```

This preserves the current simple Criteria dialog while making same-column values useful. It also avoids an early jump into a full query-builder UI.

## Future Operators

The planned generalized model is Criteria groups:

- `ALL`: every child criterion/group must match.
- `ANY`: at least one child criterion/group must match.
- `NONE`: no child criterion/group may match.
- `EXACTLY ONE`: one and only one child criterion/group must match.

`NOT` should probably appear in the user interface as `Exclude` or `None of these` rather than as programming language syntax. `XOR` should probably appear as `Exactly one of these` for the same reason.

## Data Model Direction

The current persisted `view_criteria` rows can represent the first same-column OR behavior without a schema change. A later generalized boolean model will need persisted Criteria groups with stable IDs, parent/child order, and an operator per group.

Until that exists, the default interpretation is:

```text
ALL column groups
ANY values inside each column group
```

Category Rules should follow the same interpretation as Views so saved rules and visible filters do not diverge.
