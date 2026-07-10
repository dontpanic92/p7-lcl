# p7-lcl

Protosept bindings for the Lazarus Component Library (LCL).

The first native vertical slice provides:

- LCL application initialization.
- Owning `TForm` foreign values backed by a generation-safe Pascal object table.
- Form creation, caption access, display, and deterministic release.
- `examples/hello` is a separate executable package with a path dependency on
  the root library.
- Both packages have Protosept tests that exercise the native extension.

The current Protosept API is:

```p7
lcl.initialize();
let form = lcl.new_form();
lcl.set_form_caption(form, "Hello");
lcl.show_form(form);
lcl.run(); // blocks until the form is closed
lcl.free_form(form);
```

`box<lcl.Form>` owns an unowned `TForm`. The Pascal object table validates the
slot generation on every call, so using a released form produces a native
runtime trap instead of dereferencing stale memory.

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
