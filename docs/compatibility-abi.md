# Compatibility and ABI Contract

This document freezes the compatibility surface for p7-lcl 0.1.x. Changes to
the items below require an explicit compatibility review, updated assertions,
and a versioning decision.

## Package and generated metadata

- `p7.toml` defines package `lcl` version `0.1.0` as a library and loads
  `native/lib/libp7lcl.dylib`.
- `p7.lock` uses lockfile version 1 and contains the root path package without
  external dependencies. The CLI-maintained source checksum changes when
  tracked package inputs change; the package identity, source, and dependency
  shape are stable.
- `examples/hello/p7.toml` depends on the root package through `../..`.
- `generator/bindings.json` schema version 1 is authoritative for foreign
  inheritance, ownership, parent policy, signatures, and generated output.
  Generated files must match it exactly.

## Extension ABI

p7-lcl implements Protosept native extension ABI v1 and exports only
`p7_extension_init_v1`. The normative declarations are
`protosept/p7/include/protosept_extension.h`; the matching Pascal declarations
are centralized in `native/pascal/p7lclabi.pas`.

All ABI structures are C-layout and append-only. Consumers accept a larger
`struct_size` and validate the prefix through the last field they use. p7-lcl
requires `P7HostApi` through `invoke_rooted_callback_values`; it rejects a
shorter table or an ABI version other than 1. The runtime rejects truncated
`P7NativeFunctionDescriptor` values and accepts descriptors with appended
fields.

`P7Value` remains an opaque 64-bit token. Native function descriptors and API
tables contain only fixed-width scalars, pointers, and C function pointers; no
Rust or Pascal managed type crosses the boundary.

## Callback ABI

Rooted callback tokens are runtime-owned, monotonic, and explicitly released.
The runtime pointer and callback operations are single-threaded and valid only
until runtime teardown.

`P7CallbackValue.kind` is frozen as:

| Kind | Value | Payload |
|---|---:|---|
| Unit | 0 | no payload |
| Int | 1 | `int_value` |
| Float | 2 | `float_value` |
| Bool | 3 | `int_value` as 0/1 |
| String | 4 | UTF-8 `bytes` and `length` |
| Foreign | 5 | host handle in `int_value`, UTF-8 type tag in `bytes`/`length` |

Strings and foreign values are callback inputs only. Callback output supports
unit, integer, and float; Boolean replacement values use integer 0/1.
Unknown kinds return `P7_STATUS_TYPE_MISMATCH`.

## Ownership and inheritance

`box<Form>` owns its native form. Other public LCL values are persistent
non-owning handles owned by their declared LCL owner. Explicit release or owner
destruction invalidates all matching handles before native memory can be
reused. Re-entrant event destruction is queued until the active callback
returns.

The foreign hierarchy and ownership rules are generated exclusively from
`bindings.json`. Base upcasts are implicit; downcasts validate the dynamic type
tag. Owner and parent getters return borrowed handles without finalizers.
Managed LCL collections and platform-dependent Pascal records remain opaque.

## Structured errors

Every native callback returns a `P7Status`. A failing callback records UTF-8
error-class and message fields with `set_error_details` when that appended
field is present; the operation field is currently empty. Older call tables
fall back to `set_error`.
Error state is scoped to one native invocation and preserved across nested
callback re-entry. No Pascal, Rust, C++, or other exception may unwind across
the C ABI.

## Raw C FFI decision

A general user-facing raw C FFI facility is not required by p7-lcl. The
versioned native extension ABI already provides typed registration, values,
callbacks, foreign handles, invalidation, and structured errors. Raw C FFI
therefore remains an independent Protosept language proposal and is outside
this package's scope.

## Required checks

`./scripts/check-abi.sh` verifies current, truncated, and extended host tables;
truncated and extended function descriptors; and matching Rust, C, and Free
Pascal record sizes and offsets. `./scripts/check-generated.sh` verifies the
manifest/lockfile contract, metadata validation, and deterministic generated
outputs.
