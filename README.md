# Structure

Structure is an Agenda-inspired personal information manager built around a write-it-now, structure-it-later workflow.

The core product idea is simple: capture free-form text immediately, then let categories, dates, people, projects, rules, and views emerge afterward without forcing a schema up front.

## Early Design Principles

- Local-first data ownership, with sync designed into the model from the beginning.
- One person, many devices; collaboration is not an initial goal.
- Encryption planned from the start, both for local storage and future sync packets.
- Views are editable lenses over the same underlying items, not static reports.
- Categories can act as tags, fields, values, hierarchy nodes, or view axes depending on context.
- Automatic assignment should be transparent, correctable, and useful without feeling magical in a bad way.
- macOS is the initial implementation target, with Windows, Linux, iOS, and Android considered in the architecture.

## Initial Platform Direction

The first implementation will begin on macOS. Longer-term portability should favor a shared core engine with platform-specific UI and OS service layers.

## Design Docs

- [Product Design](docs/product-design.md)
- [Capture Interaction Spec](docs/capture-interaction.md)
- [Data Model Sketch](docs/data-model.md)
- [Naming Notes](docs/naming.md)

## Prototype Build

Build the command-line Swift package:

```sh
swift build
```

Build the runnable macOS app bundle:

```sh
./scripts/build-macos-app.sh
```

### Xcode

Open `Structure.xcodeproj` in Xcode and select the **Structure** scheme. The
project builds the existing app sources directly, includes the `StructureTests`
unit-test target, links macOS's SQLite library, and keeps the bundle identifier
as `net.quantumpenguin.Structure`.

The current app bundle is written to:

```text
dist/Structure.app
```

The prototype stores local data at:

```text
~/Library/Application Support/Structure/Structure.sqlite
```

## Bundle identifier

The macOS app bundle uses `net.quantumpenguin.Structure`. Use the `net.quantumpenguin.*` namespace for new app and extension targets.
