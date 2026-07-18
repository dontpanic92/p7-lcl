# LCL example gallery

Each directory is an executable Protosept package with a path dependency on the
root `lcl` library. Run commands from the repository root after building the
native extension with `./scripts/build-native.sh`.

| Example | Purpose |
|---|---|
| [`hello`](hello/) | Minimal form, panel, label, edit, button, and callbacks. |
| [`layout`](layout/) | Hierarchy, ownership, parenting, bounds, align, anchors, colors, visibility, focus, tab order, and base-handle use. |
| [`input-events`](input-events/) | Buttons, edits, memo, checkbox/radio controls, typed senders, focus, keyboard, UTF-8, mouse, click, and change events. |
| [`collections`](collections/) | List-box and combo-box indexed item operations and selection events. |
| [`application`](application/) | Main-form registration, lifecycle events, close query, exceptions, invoke/queue, bounded pumping, run, and termination. |
| [`desktop-components`](desktop-components/) | Menus, toolbar, status bar, dialogs, images, group boxes, and timers. |
| [`showcase`](showcase/) | A cohesive desktop application containing every concrete component exposed by the binding. |

## Automated validation

Check, build, and test every package without opening interactive windows:

```bash
./scripts/check-examples.sh
```

To work with one package:

```bash
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- check examples/layout
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- build examples/layout
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- test examples/layout
```

Replace `layout` with any directory listed above.

## Manual runs

Run an executable with:

```bash
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- run examples/showcase
```

Use this checklist on the supported Cocoa baseline:

1. `hello`: edit the text, press **Copy text**, and close the form.
2. `layout`: resize the window, toggle the label, and move focus between the
   edit and button.
3. `input-events`: edit text, copy it to the memo, toggle enabled state, choose
   both radio buttons, and exercise keyboard and mouse input.
4. `collections`: select, add, and remove list items and change the combo-box
   selection.
5. `application`: resize and activate the form, disable **Allow close** to
   verify close-query cancellation, then re-enable it and close.
6. `desktop-components`: use both toolbar buttons, open the native file
   dialogs, confirm timer status updates, and close the form.
7. `showcase`: add and select list items, switch options, load the checked-in
   XPM fixture, try both native dialogs, resize the layout, and close cleanly.

The fixture-loading actions use paths relative to the repository root, so run
the examples from that directory.

## Coverage

Across the focused examples and showcase, the gallery covers all concrete
foreign types: `Form`, `Button`, `CheckBox`, `RadioButton`, `Label`, `Edit`,
`Memo`, `ListBox`, `ComboBox`, `Panel`, `Image`, `Timer`, `MainMenu`,
`MenuItem`, `ToolBar`, `ToolButton`, `StatusBar`, `OpenDialog`, `SaveDialog`,
and `GroupBox`.

It also demonstrates the major cross-cutting workflows: application lifecycle,
component ownership, control parenting, common geometry/state/layout APIs,
foreign inheritance and downcasts, indexed collections, rooted callbacks,
typed event senders, mutable keyboard/close-query results, synchronous and
queued dispatch, exception callbacks, deterministic cleanup, and native UI
interactions.
