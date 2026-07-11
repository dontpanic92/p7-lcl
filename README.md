# p7-lcl

Protosept bindings for the Lazarus Component Library (LCL).

The native binding currently provides:

- LCL application initialization.
- Owning `TForm` foreign values backed by a generation-safe Pascal object table.
- Forms with caption, bounds, show, close, and deterministic release.
- Form-owned `TButton`, `TLabel`, `TEdit`, and `TPanel` controls with common
  text, bounds, visibility, enabled, and focus operations.
- Persistent rooted `OnClick`, `OnChange`, `OnClose`, `OnCloseQuery`, and
  `OnKeyPress` callbacks, including re-entrant calls and mutable event results.
- `examples/hello` is a separate executable package with a path dependency on
  the root library.
- Both packages have Protosept tests that exercise the native extension.

The current Protosept API is:

```p7
lcl.initialize();
let form = lcl.new_form();
lcl.set_form_caption(form, "Hello");
lcl.set_form_bounds(form, 120, 120, 420, 220);
let label = lcl.new_label(form);
let edit = lcl.new_edit(form);
let button = lcl.new_button(form);
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
`lcl.run()`. `lcl.invoke(callback)` executes synchronously after verifying the
designated UI thread, while `lcl.queue(callback)` retains the closure until the
next LCL message-pump turn.

`box<lcl.Form>` owns its form. Controls are returned as persistent non-owning
`handle<lcl.*>` values. Their LCL owner is the form, and owner destruction
invalidates every child handle before it can be used again.

Event setters root closures until the event is replaced, explicitly cleared,
or the owning form/control is released. Close-query and key-press callbacks
return replacement values for Pascal `var` parameters. The Pascal object table
validates slot generations on every call, so released or owner-destroyed
objects produce a native runtime trap instead of dereferencing stale memory.

The `protosept` directory is intentionally untracked and points to the local
Protosept checkout used to build the CLI.

## Commands

Build the native extension first:

```bash
./scripts/build-native.sh
```

`generator/bindings.json` is the binding metadata source. The build regenerates
the Protosept API and Pascal registration table before compiling the library.

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
