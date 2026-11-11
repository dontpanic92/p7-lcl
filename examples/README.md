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
| [`showcase`](showcase/) | A cohesive desktop application containing every concrete component exposed by the binding, with retained shared callback state. |

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

## Managed references in the showcase

[`showcase/src/session.p7`](showcase/src/session.p7) installs the existing Add
button and timer callbacks around one mutable `State` local. It returns `&state`
to the caller and captures `&state.added` and `&state.ticks` directly in the
native-rooted callbacks. Those field references retain the original owner after
`session.install` returns: Add increments the added-item count,
the timer increments the tick count, and both display the current counts in the
status bar. **File > Clear output** calls `session.reset`, replacing `*state`
with `State(0, 0)`. Already-installed callbacks see the replacement rather than
a stale snapshot.

`lcl.new_form()` returns `&lcl.Form` directly. Its native implementation still
allocates an owned foreign cell, but neither construction nor form-operation
signatures expose that implementation box. Normalization preserves its identity
and finalizer; no projected referent is copied or reboxed. Child controls and
event senders remain `handle<lcl.*>` because their native LCL owner, not the
script reference, controls their lifetime. Do not convert an unowned child
handle into `&lcl.*`.

Run the showcase checks on a native desktop (or GTK3 under Xvfb):

```bash
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- test examples/showcase
```

The tests exercise the actual shared session callbacks after setup returns,
reset through an alias, a field reference across whole-state replacement, and
queued native dispatch. A separate smoke test invokes the same application
runner as `main`, shows its full window, enters the LCL event loop, and terminates
through a queued callback without waiting for manual interaction. The runner's
`on_ready` hook queues termination after the initial show/focus work, because
showing an LCL form can itself pump queued callbacks before `run` starts.

The root package's `tests/test_retained_boundaries.p7` additionally drives real
native event roots with a protocol-packaged field projection whose enclosing
record owns a form.
Allocation pressure triggers collection after setup exits; the callback still
sees replacement state. Clearing or replacing the callback, or destroying its
button, releases the owner so its form finalizes and its child handle is rejected.

## Manual runs

Run an executable with:

```bash
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- run examples/showcase
```

Use this checklist on the supported Cocoa, GTK3, or Win32 baseline:

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
7. `showcase`: add and select list items, observe shared Add/timer counters in
   the status bar, choose **File > Clear output**, and verify the next Add/timer
   events continue from zero. Switch options, load the checked-in XPM fixture,
   try both native dialogs, resize the layout, and close cleanly.

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
