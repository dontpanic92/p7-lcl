# p7-lcl

Protosept bindings for the Lazarus Component Library (LCL).

The repository currently contains a package-system scaffold:

- The root `lcl` package is a library with a small mock public API.
- `examples/hello` is a separate executable package with a path dependency on
  the root library.
- Both packages have Protosept tests that exercise cross-package calls.

The `protosept` directory is intentionally untracked and points to the local
Protosept checkout used to build the CLI.

## Commands

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
