# p7-lcl

Protosept bindings for the Lazarus Component Library (LCL).

The native binding currently provides:

- LCL application initialization.
- A generated foreign hierarchy matching `TObject` → `TComponent` →
  `TControl` → `TWinControl`, with forms and standard controls under their
  real bases.
- Owning `TForm` foreign values backed by a generation-safe Pascal object table.
- Forms with caption, bounds, main-menu attachment, show, close, and
  deterministic release.
- Form-owned buttons, checkbox/radio controls, labels, edits, memos, list and
  combo boxes, panels, group boxes, images, toolbars, status bars, file
  dialogs, menus, and timers.
- Generated owner/parent, name, geometry, visibility, enabled, focus,
  tab-order, align, anchor, and color operations for applicable controls.
- Persistent rooted click, change, keyboard, mouse, focus, close, and
  close-query callbacks, including typed sender handles, UTF-8 values,
  enum/flag payloads, re-entrant calls, and mutable event results.
- Checkbox and radio-button caption/state APIs with sender-aware change events
  and deterministic click helpers.
- Indexed string APIs for memo/list/combo data keep LCL-managed `TStrings`
  collections behind the native boundary.
- Menu hierarchy and state APIs, toolbar buttons, simple status-bar text,
  open/save dialog properties and execution, image loading/properties, and
  deterministic timer callbacks.
- Rooted form `OnShow`, `OnHide`, `OnActivate`, `OnDeactivate`, and `OnResize`
  lifecycle callbacks with synchronous error propagation.
- `examples/hello` is a separate executable package with a path dependency on
  the root library.
- Both packages have Protosept tests that exercise the native extension.

The current Protosept API is:

```p7
lcl.initialize();
let form = lcl.new_form();
lcl.register_main_form(form);
lcl.set_form_caption(form, "Hello");
lcl.set_form_bounds(form, 120, 120, 420, 220);
let label = lcl.new_label(form);
let edit = lcl.new_edit(form);
let button = lcl.new_button(form);
let panel = lcl.new_panel(form);
lcl.set_control_parent(label, panel);
lcl.set_control_parent(edit, panel);
lcl.set_control_parent(button, panel);
lcl.set_control_bounds(panel, 16, 16, 388, 160);
lcl.set_control_anchors(panel, lcl.Anchors.Left | lcl.Anchors.Right);
lcl.button_on_click(button, () => {
    lcl.set_label_caption(label, lcl.edit_text(edit));
});
lcl.show_form(form);
lcl.run(); // blocks until the form is closed
lcl.free_button(button);
lcl.free_edit(edit);
lcl.free_label(label);
lcl.free_form(form);
```

Hosts that own their event loop can call `lcl.process_messages()` instead of
`lcl.run()`. `lcl.process_messages_bounded(max_turns)` performs at most the
requested number of non-blocking pump turns. `lcl.invoke(callback)` executes
synchronously, while `lcl.queue(callback)` retains the closure until an LCL
message-pump turn.

Protosept and this binding are single-threaded; all LCL operations run on that
one runtime thread, so cross-thread calls are outside the execution model.
`lcl.initialize()` and `lcl.terminate()` are idempotent. A form must be selected
with `lcl.register_main_form(form)` before `lcl.run()`. Registration can be
changed until running starts, but an application loop runs only once and cannot
be restarted after it returns or is terminated.

`box<lcl.Form>` owns its form. Controls are returned as persistent non-owning
`handle<lcl.*>` values. Their LCL owner is the form, and owner destruction
invalidates every child handle before it can be used again.

Common operations accept base handles, so derived controls upcast implicitly;
checked `as handle<...>` downcasts validate the real LCL type tag. Owner and
parent getters return borrowed base handles with no finalizer. `Align`,
`Anchors`, and `Color` use fixed-width values; invalid align values, anchor
bits, negative extents, and tab orders produce explicit native errors.

Event setters root closures until the event is replaced, explicitly cleared,
or the owning form/control is released. Close-query and key-press callbacks
return replacement values for Pascal `var` parameters. Mouse callbacks receive
the sender, button, shift-state bits, and coordinates; focus and keyboard
callbacks receive dynamically typed sender handles that can be checked and
downcast.

Synchronous event-trigger helpers return callback failures immediately.
Failures from `lcl.queue()` or other asynchronous LCL dispatch are retained,
terminate the active application loop, and are returned as a native error by
the next `lcl.process_messages()` or `lcl.run()` call. The Pascal object table
validates slot generations on every call, so released or owner-destroyed
objects produce a native runtime trap instead of dereferencing stale memory.

Managed and platform-dependent Pascal records remain opaque. The current API
does not expose a point or rectangle record requiring a C-layout adapter;
coordinates and bounds cross the ABI as fixed-width scalar arguments.

`lcl.application_on_exception(callback)` roots a
`fn(string, string)` callback receiving the exception class and message.
Replace or clear it with `lcl.application_clear_on_exception()` when it is no
longer needed.

The `protosept` directory is intentionally untracked and points to the local
Protosept checkout used to build the CLI.

## Commands

Build the native extension first:

```bash
./scripts/build-native.sh
```

`generator/bindings.json` is the binding metadata source. It records the
Pascal and Protosept hierarchies independently, lifetime/parent policy,
properties, enum/set mappings, event signatures, parameter direction, and
platform/widgetset availability. The build validates this schema and
regenerates the Protosept API and Pascal registration table before compiling
the library.

Common string, Boolean, integer, bounds, action, and rooted event
installation/clearing callbacks are emitted into
`native/pascal/generated/callbacks.inc`. Standard-control creation, release,
and finalization are generated as well. Form lifecycle and event-trigger
callbacks remain custom Pascal where they require re-entrancy or application
ownership handling.

Check metadata validation, deterministic output, and checked-in generator
drift without building Lazarus:

```bash
./scripts/check-generated.sh
```

The frozen package, ownership, error, extension, and callback compatibility
contract is documented in [`docs/compatibility-abi.md`](docs/compatibility-abi.md).
After building the native library, verify older/newer `struct_size` behavior
and Rust/C/Free Pascal layouts with:

```bash
./scripts/check-abi.sh
```

The build uses `~/lazarus`, `/usr/local/bin/fpc`, and the Cocoa widgetset. It
passes `-ld_classic` because the current Apple linker rejects Objective-C
metadata emitted by this FPC/Lazarus toolchain.

Run the root library checks from this directory:

```bash
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- check .
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- build .
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- test .
```

Run the dependent example:

```bash
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- check examples/hello
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- build examples/hello
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- test examples/hello
cargo run --manifest-path protosept/Cargo.toml -p p7-cli -- run examples/hello
```

Running the root package with `p7 run` is rejected because it is a library.
