#!/usr/bin/env python3

from pathlib import Path
import argparse
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
METADATA = Path(__file__).with_name("bindings.json")

NATIVE_TYPES = {
    "int": "P7_TYPE_INT",
    "i32": "P7_TYPE_I32",
    "u32": "P7_TYPE_U32",
    "bool": "P7_TYPE_BOOL",
    "string": "P7_TYPE_STRING",
    "closure": "P7_TYPE_CLOSURE",
    "foreign": "P7_TYPE_FOREIGN",
}
PARAM_DIRECTIONS = {"in", "out", "inout"}
LIFETIMES = {"abstract", "owned", "owner_owned", "borrowed"}
PARENT_POLICIES = {"none", "fixed", "reparentable"}
VALUE_KINDS = {"enum", "flags", "scalar"}
CALLBACK_KINDS = {
    "property_get",
    "property_set",
    "bounds",
    "action",
    "event_set",
    "event_clear",
    "create_control",
    "free_control",
    "finalize_control",
}
CALLBACK_VALUE_KINDS = {"string", "bool", "int"}


class MetadataError(ValueError):
    pass


def require_unique(items: list[dict], field: str, label: str) -> None:
    seen: set[str] = set()
    for item in items:
        value = item.get(field)
        if not value:
            raise MetadataError(f"{label} is missing {field}")
        if value in seen:
            raise MetadataError(f"duplicate {label} {field}: {value}")
        seen.add(value)


def validate_metadata(metadata: dict) -> None:
    if metadata.get("schema_version") != 1:
        raise MetadataError("schema_version must be 1")

    foreign_types = metadata.get("foreign_types", [])
    functions = metadata.get("functions", [])
    value_types = metadata.get("value_types", [])
    properties = metadata.get("properties", [])
    events = metadata.get("events", [])
    generated_callbacks = metadata.get("generated_callbacks", [])
    known_widgetsets = set(metadata.get("known_widgetsets", []))

    require_unique(foreign_types, "p7_name", "foreign type")
    require_unique(foreign_types, "type_tag", "foreign type")
    require_unique(foreign_types, "pascal_class", "foreign type")
    require_unique(functions, "intrinsic", "function")
    exposed_functions = [item for item in functions if item.get("expose_p7", True)]
    require_unique(exposed_functions, "native_name", "function")
    require_unique(exposed_functions, "public_name", "function")
    require_unique(value_types, "p7_name", "value type")
    require_unique(properties, "name", "property")
    require_unique(events, "name", "event")
    require_unique(generated_callbacks, "callback", "generated callback")
    generated_targets: set[str] = set()
    for callback in generated_callbacks:
        target = callback.get("function") or callback.get("intrinsic")
        if not target:
            raise MetadataError("generated callback is missing function or intrinsic")
        if target in generated_targets:
            raise MetadataError(f"duplicate generated callback target: {target}")
        generated_targets.add(target)

    foreign_by_name = {item["p7_name"]: item for item in foreign_types}
    value_by_name = {item["p7_name"]: item for item in value_types}
    function_by_public = {item["public_name"]: item for item in exposed_functions}
    generated_by_function = {
        item["function"]: item
        for item in generated_callbacks
        if item.get("function")
    }
    generated_by_intrinsic = {
        item["intrinsic"]: item
        for item in generated_callbacks
        if item.get("intrinsic")
    }

    defaults = metadata.get("defaults", {})
    default_availability = defaults.get("availability", {})
    default_direction = defaults.get("parameter_direction", "in")
    if default_direction not in PARAM_DIRECTIONS:
        raise MetadataError(f"unsupported default parameter direction: {default_direction}")
    validate_availability(default_availability, known_widgetsets, "default availability")

    for foreign in foreign_types:
        p7_base = foreign.get("p7_base")
        pascal_base = foreign.get("pascal_base")
        if p7_base and p7_base not in foreign_by_name:
            raise MetadataError(
                f"foreign type {foreign['p7_name']} has unknown p7_base {p7_base}"
            )
        if p7_base and not pascal_base:
            raise MetadataError(
                f"foreign type {foreign['p7_name']} is missing pascal_base"
            )
        if not p7_base and pascal_base:
            raise MetadataError(
                f"root foreign type {foreign['p7_name']} cannot have pascal_base"
            )

        lifetime = foreign.get("lifetime")
        if lifetime not in LIFETIMES:
            raise MetadataError(
                f"foreign type {foreign['p7_name']} has invalid lifetime {lifetime}"
            )
        owner_type = foreign.get("owner_type")
        if lifetime == "owner_owned":
            if owner_type not in foreign_by_name:
                raise MetadataError(
                    f"foreign type {foreign['p7_name']} has invalid owner_type "
                    f"{owner_type}"
                )
        elif owner_type:
            raise MetadataError(
                f"foreign type {foreign['p7_name']} cannot declare owner_type "
                f"with lifetime {lifetime}"
            )

        parent_policy = foreign.get("parent_policy", "none")
        if parent_policy not in PARENT_POLICIES:
            raise MetadataError(
                f"foreign type {foreign['p7_name']} has invalid parent_policy "
                f"{parent_policy}"
            )
        parent_type = foreign.get("parent_type")
        if parent_policy == "none" and parent_type:
            raise MetadataError(
                f"foreign type {foreign['p7_name']} cannot declare parent_type"
            )
        if parent_policy != "none" and parent_type not in foreign_by_name:
            raise MetadataError(
                f"foreign type {foreign['p7_name']} has invalid parent_type "
                f"{parent_type}"
            )
        validate_availability(
            foreign.get("availability", default_availability),
            known_widgetsets,
            f"foreign type {foreign['p7_name']}",
        )

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visiting:
            raise MetadataError(f"foreign inheritance cycle involving {name}")
        if name in visited:
            return
        visiting.add(name)
        base = foreign_by_name[name].get("p7_base")
        if base:
            visit(base)
        visiting.remove(name)
        visited.add(name)

    for name in foreign_by_name:
        visit(name)

    for value_type in value_types:
        kind = value_type.get("kind")
        if kind not in VALUE_KINDS:
            raise MetadataError(
                f"value type {value_type['p7_name']} has invalid kind {kind}"
            )
        if value_type.get("wire_type") not in NATIVE_TYPES:
            raise MetadataError(
                f"value type {value_type['p7_name']} has unsupported wire type "
                f"{value_type.get('wire_type')}"
            )
        values = value_type.get("values", [])
        require_unique(values, "name", f"value in {value_type['p7_name']}")
        if kind in {"enum", "flags"} and not values:
            raise MetadataError(f"value type {value_type['p7_name']} has no values")

    for function in functions:
        function_name = function.get("public_name", function["intrinsic"])
        validate_availability(
            function.get("availability", default_availability),
            known_widgetsets,
            f"function {function_name}",
        )
        params = function.get("params")
        if not isinstance(params, list):
            raise MetadataError(f"function {function_name} has invalid params")
        require_unique(params, "name", f"parameter in {function_name}")
        for param in params:
            native = param.get("native")
            if native not in NATIVE_TYPES:
                raise MetadataError(
                    f"function {function_name} parameter {param['name']} "
                    f"has unsupported wire type {native}"
                )
            direction = param.get("direction", default_direction)
            if direction not in PARAM_DIRECTIONS:
                raise MetadataError(
                    f"function {function_name} parameter {param['name']} "
                    f"has invalid direction {direction}"
                )
        result_native = function.get("result_native")
        if result_native is not None and result_native not in NATIVE_TYPES:
            raise MetadataError(
                f"function {function_name} has unsupported result wire type "
                f"{result_native}"
            )

    for callback in generated_callbacks:
        function_name = callback.get("function")
        intrinsic = callback.get("intrinsic")
        if function_name and function_name not in function_by_public:
            raise MetadataError(
                f"generated callback references unknown function {function_name}"
            )
        if intrinsic and intrinsic not in {
            function["intrinsic"] for function in functions
        }:
            raise MetadataError(
                f"generated callback references unknown intrinsic {intrinsic}"
            )
        callback_target = function_name or intrinsic
        kind = callback.get("kind")
        if kind not in CALLBACK_KINDS:
            raise MetadataError(
                f"generated callback {callback_target} has invalid kind {kind}"
            )
        if kind in {"create_control", "free_control", "finalize_control"}:
            for field in ("type_tag", "pascal_class"):
                if not callback.get(field):
                    raise MetadataError(
                        f"generated callback {callback_target} is missing {field}"
                    )
            continue
        reader = callback.get("reader")
        if reader not in {"component", "control", "win_control", "object"}:
            raise MetadataError(
                f"generated callback {callback_target} has invalid reader {reader}"
            )
        if reader == "object":
            for field in ("type_tag", "pascal_class"):
                if not callback.get(field):
                    raise MetadataError(
                        f"generated callback {callback_target} is missing {field}"
                    )
        if kind in {"property_get", "property_set"}:
            value_kind = callback.get("value_kind")
            if value_kind not in CALLBACK_VALUE_KINDS:
                raise MetadataError(
                    f"generated callback {callback_target} has invalid value_kind "
                    f"{value_kind}"
                )
            if not callback.get("property"):
                raise MetadataError(
                    f"generated callback {callback_target} is missing property"
                )
        if kind == "action" and not callback.get("action"):
            raise MetadataError(
                f"generated callback {callback_target} is missing action"
            )
        if kind == "event_set" and not callback.get("set_method"):
            raise MetadataError(
                f"generated callback {callback_target} is missing set_method"
            )
        if kind == "event_clear" and not callback.get("clear_method"):
            raise MetadataError(
                f"generated callback {callback_target} is missing clear_method"
            )

    for function in exposed_functions:
        generated = function["public_name"] in generated_by_function
        if generated and not function.get("callback"):
            raise MetadataError(
                f"generated function {function['public_name']} is missing fallback callback"
            )

    for prop in properties:
        owner = prop.get("owner")
        if owner not in foreign_by_name:
            raise MetadataError(f"property {prop['name']} has unknown owner {owner}")
        getter = prop.get("getter")
        setter = prop.get("setter")
        mutable = prop.get("mutable")
        if getter and getter not in function_by_public:
            raise MetadataError(f"property {prop['name']} has unknown getter {getter}")
        if setter and setter not in function_by_public:
            raise MetadataError(f"property {prop['name']} has unknown setter {setter}")
        group_setter = prop.get("group_setter")
        if setter and group_setter:
            raise MetadataError(
                f"property {prop['name']} cannot have setter and group_setter"
            )
        if group_setter and group_setter not in function_by_public:
            raise MetadataError(
                f"property {prop['name']} has unknown group_setter {group_setter}"
            )
        if mutable and not (setter or group_setter):
            raise MetadataError(f"mutable property {prop['name']} has no setter")
        if not mutable and setter:
            raise MetadataError(f"read-only property {prop['name']} has a setter")
        if prop.get("wire_type") not in NATIVE_TYPES:
            raise MetadataError(
                f"property {prop['name']} has unsupported wire type "
                f"{prop.get('wire_type')}"
            )
        mapping = prop.get("mapping")
        if mapping and mapping not in value_by_name:
            raise MetadataError(f"property {prop['name']} has unknown mapping {mapping}")

    for event in events:
        owner = event.get("owner")
        if owner not in foreign_by_name:
            raise MetadataError(f"event {event['name']} has unknown owner {owner}")
        for field in ("setter", "clear"):
            target = event.get(field)
            if target not in function_by_public:
                raise MetadataError(
                    f"event {event['name']} has unknown {field} function {target}"
                )
        signature = event.get("signature", {})
        for param in signature.get("params", []):
            if param.get("direction", default_direction) not in PARAM_DIRECTIONS:
                raise MetadataError(
                    f"event {event['name']} has invalid parameter direction"
                )


def validate_availability(
    availability: dict, known_widgetsets: set[str], label: str
) -> None:
    if not isinstance(availability, dict):
        raise MetadataError(f"{label} availability must be an object")
    widgetsets = availability.get("widgetsets", [])
    unknown = set(widgetsets) - known_widgetsets
    if unknown:
        raise MetadataError(
            f"{label} references unknown widgetsets: {', '.join(sorted(unknown))}"
        )


def generate_value_types(metadata: dict) -> list[str]:
    lines: list[str] = []
    for value_type in metadata["value_types"]:
        name = value_type["p7_name"]
        storage = value_type["p7_storage"]
        kind = value_type["kind"]
        conformances = "[BitOr, BitAnd, BitXor]" if kind == "flags" else ""
        lines.append(f"pub struct{conformances} {name}({storage}) {{")
        for value in value_type.get("values", []):
            lines.append(f'    pub {value["name"]} = Self({value["value"]});')
        if value_type.get("values"):
            lines.append("")
        if kind == "flags":
            lines.extend(
                [
                    "    pub fn bitor(ref self, rhs: Self) -> Self { Self(self.0 | rhs.0) }",
                    "    pub fn bitand(ref self, rhs: Self) -> Self { Self(self.0 & rhs.0) }",
                    "    pub fn bitxor(ref self, rhs: Self) -> Self { Self(self.0 ^ rhs.0) }",
                    "    pub fn contains(ref self, rhs: Self) -> bool {",
                    "        (self.0 & rhs.0) == rhs.0",
                    "    }",
                    f"    pub fn bits(ref self) -> {storage} {{ self.0 }}",
                ]
            )
        else:
            lines.append(f"    pub fn value(ref self) -> {storage} {{ self.0 }}")
        lines.extend(["}", ""])
    return lines


def generate_p7(metadata: dict) -> str:
    lines = [
        "// Generated by generator/generate.py. Do not edit.",
        "",
        "import std.ffi;",
        "",
    ]
    lines.extend(generate_value_types(metadata))

    for foreign in metadata["foreign_types"]:
        base = foreign.get("p7_base")
        base_list = f"[{base}]" if base else ""
        finalizer = (
            f',\n    finalizer="{foreign["finalizer"]}"'
            if foreign.get("finalizer")
            else ""
        )
        lines.extend(
            [
                "@foreign(",
                f'    type_tag="{foreign["type_tag"]}",',
                f'    dispatcher="{foreign["dispatcher"]}"{finalizer},',
                ")",
                f'pub proto{base_list} {foreign["p7_name"]} {{',
                "}",
                "",
            ]
        )

    exposed = [item for item in metadata["functions"] if item.get("expose_p7", True)]
    for function in exposed:
        params = ", ".join(
            f'{param["name"]}: {param.get("native_p7", param["p7"])}'
            for param in function["params"]
        )
        result = (
            f' -> {function.get("native_result_p7", function["result_p7"])}'
            if "result_p7" in function
            else ""
        )
        lines.extend(
            [
                f'@intrinsic(name="{function["intrinsic"]}")',
                f'fn {function["native_name"]}({params}){result};',
                "",
            ]
        )

    for function in exposed:
        params = ", ".join(
            f'{param["name"]}: {param["p7"]}' for param in function["params"]
        )
        args = ", ".join(
            param.get("native_arg", param["name"]) for param in function["params"]
        )
        result = (
            f' -> {function["result_p7"]}' if "result_p7" in function else ""
        )
        lines.extend(
            [
                f'pub fn {function["public_name"]}({params}){result} {{',
                f'    {function.get("result_wrap", "")}{function["native_name"]}({args})'
                + function.get("result_wrap_suffix", ""),
                "}",
                "",
            ]
        )

    return "\n".join(lines)


def generate_pascal(metadata: dict) -> str:
    functions = metadata["functions"]
    lines = [
        "{ Generated by generator/generate.py. Do not edit. }",
        "",
        "function RegisterGeneratedFunctions(Api: PP7HostApi): TP7Status;",
        "var",
    ]
    for index, function in enumerate(functions):
        if function["params"]:
            lines.append(
                f'  Params{index}: array[0..{len(function["params"]) - 1}] of LongWord;'
            )
    lines.append("begin")

    for index, function in enumerate(functions):
        for param_index, param in enumerate(function["params"]):
            lines.append(
                f'  Params{index}[{param_index}] := {NATIVE_TYPES[param["native"]]};'
            )
        params = f"@Params{index}[0]" if function["params"] else "nil"
        result_type = NATIVE_TYPES.get(function.get("result_native", ""), "P7_TYPE_ANY")
        has_result = "True" if "result_native" in function else "False"
        generated = generated_by_public_or_intrinsic(metadata, function)
        callback = generated["callback"] if generated else function["callback"]
        lines.extend(
            [
                "  Result := RegisterFunction(",
                f"    Api, '{function['intrinsic']}', {params}, {len(function['params'])},",
                f"    {result_type}, {has_result}, @{callback}",
                "  );",
                "  if Result <> P7_STATUS_OK then Exit;",
            ]
        )

    for foreign in metadata["foreign_types"]:
        finalizer = (
            f"'{foreign['finalizer']}'" if foreign.get("finalizer") else "nil"
        )
        lines.extend(
            [
                "  Result := Api^.RegisterForeignType(",
                "    Api^.Runtime,",
                f"    '{foreign['type_tag']}',",
                f"    {finalizer}",
                "  );",
                "  if Result <> P7_STATUS_OK then Exit;",
            ]
        )
    lines.extend(["end;", ""])
    return "\n".join(lines)


def pascal_reader(callback: dict, value_index: int = 0) -> tuple[list[str], str]:
    reader = callback["reader"]
    if reader == "component":
        return (
            [
                "  Component: TComponent;",
                f"  Result := ReadComponent(Api, PP7ValueArray(Args)^[{value_index}], Component);",
            ],
            "Component",
        )
    if reader == "control":
        return (
            [
                "  Control: TControl;",
                f"  Result := ReadControl(Api, PP7ValueArray(Args)^[{value_index}], Control);",
            ],
            "Control",
        )
    if reader == "win_control":
        return (
            [
                "  Control: TWinControl;",
                f"  Result := ReadWinControl(Api, PP7ValueArray(Args)^[{value_index}], Control);",
            ],
            "Control",
        )
    pascal_class = callback["pascal_class"]
    type_tag = callback["type_tag"]
    return (
        [
            "  Instance: TObject;",
            f"  Result := ReadObject(Api, PP7ValueArray(Args)^[{value_index}], "
            f"{type_tag}, {pascal_class}, Instance);",
        ],
        f"{pascal_class}(Instance)",
    )


def generated_by_public_or_intrinsic(metadata: dict, function: dict):
    for item in metadata.get("generated_callbacks", []):
        if item.get("function") and item["function"] == function.get("public_name"):
            return item
        if item.get("intrinsic") and item["intrinsic"] == function["intrinsic"]:
            return item
    return None


def generate_control_lifecycle_callback(callback: dict) -> list[str]:
    kind = callback["kind"]
    callback_name = callback["callback"]
    pascal_class = callback["pascal_class"]
    type_tag = callback["type_tag"]
    clear_methods = callback.get("clear_methods", [])
    lines = [
        f"function {callback_name}(Userdata: Pointer; Api: PP7CallApi;",
        "  Args: PP7Value; ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;",
        "var",
    ]
    if kind == "create_control":
        lines.extend(
            [
                "  Form: TForm;",
                f"  Instance: {pascal_class};",
                "begin",
                "  Instance := nil;",
                "  try",
                "    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then",
                "      Exit(P7_STATUS_INVALID_ARGUMENT);",
                "    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);",
                "    if Result <> P7_STATUS_OK then Exit;",
                f"    Instance := {pascal_class}.Create(Form);",
                "    Instance.Parent := Form;",
                f"    Result := MakeHandleObject(Api, Instance, {type_tag}, Output);",
                "    if Result = P7_STATUS_OK then Instance := nil;",
                "  except",
                "    on E: Exception do",
                "    begin",
                "      Instance.Free;",
                "      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);",
                "    end;",
                "  end;",
                "end;",
                "",
            ]
        )
        return lines

    lines.append("  Handle: Int64;")
    lines.append("  Instance: TObject;")
    lines.extend(
        [
            "begin",
            "  try",
            "    if (ArgCount <> 1) or (Args = nil) then"
            if kind == "free_control"
            else "    if (ArgCount <> 2) or (Args = nil) then",
            "      Exit(P7_STATUS_INVALID_ARGUMENT);",
        ]
    )
    if kind == "free_control":
        lines.extend(
            [
                f"    Result := Api^.GetForeign(Api, PP7ValueArray(Args)^[0], "
                f"PByte({type_tag}), StrLen({type_tag}), @Handle);",
                "    if Result <> P7_STATUS_OK then Exit;",
                f"    Instance := FindObject(Handle, {pascal_class});",
            ]
        )
    else:
        lines.extend(
            [
                "    Result := Api^.GetInt(Api, PP7ValueArray(Args)^[0], @Handle);",
                "    if Result <> P7_STATUS_OK then Exit;",
                f"    Instance := FindObjectOrNil(Handle, {pascal_class});",
            ]
        )
    if clear_methods:
        lines.append("    if Instance <> nil then")
        lines.append("    begin")
        for method in clear_methods:
            lines.append(f"      {pascal_class}(Instance).{method};")
        lines.append("    end;")
    lines.append(
        "    ReleaseControlObject(Handle);"
        if kind == "free_control"
        else "    ReleaseObject(Handle);"
    )
    lines.extend(
        [
            "    Result := P7_STATUS_OK;",
            "  except",
            "    on E: Exception do",
            "      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);",
            "  end;",
            "end;",
            "",
        ]
    )
    return lines


def generate_pascal_callback(callback: dict) -> list[str]:
    kind = callback["kind"]
    if kind in {"create_control", "free_control", "finalize_control"}:
        return generate_control_lifecycle_callback(callback)
    arg_count = (
        5
        if kind == "bounds"
        else (2 if kind in {"property_set", "event_set"} else 1)
    )
    needs_output = kind == "property_get"
    reader_lines, target = pascal_reader(callback)
    declarations = [reader_lines[0]]
    setup = reader_lines[1:]

    if kind == "property_set":
        value_kind = callback["value_kind"]
        declarations.append(
            {"string": "  Value: UTF8String;", "bool": "  Value: Boolean;", "int": "  Value: Integer;"}[
                value_kind
            ]
        )
    elif kind == "property_get" and callback["value_kind"] == "string":
        declarations.append("  Value: UTF8String;")
    elif kind == "bounds":
        declarations.append("  ALeft, ATop, AWidth, AHeight: Integer;")
    elif kind == "event_set":
        declarations.append("  Token: QWord;")

    guard = f"    if (ArgCount <> {arg_count}) or (Args = nil)"
    if needs_output:
        guard += " or (Output = nil)"
    guard += " then Exit(P7_STATUS_INVALID_ARGUMENT);"

    body = [
        f"function {callback['callback']}(Userdata: Pointer; Api: PP7CallApi;",
        "  Args: PP7Value; ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;",
        "var",
        *declarations,
        "begin",
        *(["  Token := 0;"] if kind == "event_set" else []),
        "  try",
        guard,
        *[f"    {line.strip()}" for line in setup],
        "    if Result <> P7_STATUS_OK then Exit;",
    ]

    if kind == "property_set":
        value_kind = callback["value_kind"]
        read_value = {
            "string": "ReadString",
            "bool": "ReadBoolean",
            "int": "ReadInt",
        }[value_kind]
        body.extend(
            [
                f"    Result := {read_value}(Api, PP7ValueArray(Args)^[1], Value);",
                "    if Result <> P7_STATUS_OK then Exit;",
                f"    {target}.{callback['property']} := "
                + ("String(Value);" if value_kind == "string" else "Value;"),
                "    Result := P7_STATUS_OK;",
            ]
        )
    elif kind == "property_get":
        value_kind = callback["value_kind"]
        prop = callback["property"]
        if value_kind == "string":
            body.extend(
                [
                    f"    Value := UTF8String({target}.{prop});",
                    "    Result := Api^.MakeString(Api, PByte(PAnsiChar(Value)), "
                    "Length(Value), Output);",
                ]
            )
        elif value_kind == "bool":
            body.append(f"    Result := MakeBoolean(Api, {target}.{prop}, Output);")
        else:
            body.append(f"    Result := MakeInteger(Api, {target}.{prop}, Output);")
    elif kind == "bounds":
        body.extend(
            [
                "    Result := ReadBounds(Api, PP7ValueArray(Args), "
                "ALeft, ATop, AWidth, AHeight);",
                "    if Result <> P7_STATUS_OK then Exit;",
                f"    {target}.SetBounds(ALeft, ATop, AWidth, AHeight);",
                "    Result := P7_STATUS_OK;",
            ]
        )
    elif kind == "action":
        body.extend(
            [
                f"    {target}.{callback['action']};",
                "    Result := P7_STATUS_OK;",
            ]
        )
    elif kind == "event_set":
        body.extend(
            [
                "    Result := RetainEventCallback(Api, "
                "PP7ValueArray(Args)^[1], Token);",
                "    if Result <> P7_STATUS_OK then Exit;",
                f"    {target}.{callback['set_method']}(Api^.Runtime, Token);",
                "    Token := 0;",
                "    Result := P7_STATUS_OK;",
            ]
        )
    else:
        body.extend(
            [
                f"    {target}.{callback['clear_method']};",
                "    Result := P7_STATUS_OK;",
            ]
        )

    body.extend(["  except", "    on E: Exception do", "    begin"])
    if kind == "event_set":
        body.extend(
            [
                "      if Token <> 0 then",
                "        ReleaseEvent(Api^.Runtime, Token);",
            ]
        )
    body.extend(
        [
            "      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);",
            "    end;",
            "  end;",
            "end;",
            "",
        ]
    )
    return body


def generate_pascal_callbacks(metadata: dict) -> str:
    lines = ["{ Generated by generator/generate.py. Do not edit. }", ""]
    for callback in metadata.get("generated_callbacks", []):
        lines.extend(generate_pascal_callback(callback))
    return "\n".join(lines)


def render_outputs(metadata: dict) -> dict[Path, str]:
    return {
        ROOT / "src/mod.p7": generate_p7(metadata),
        ROOT / "native/pascal/generated/callbacks.inc": generate_pascal_callbacks(
            metadata
        ),
        ROOT / "native/pascal/generated/registration.inc": generate_pascal(metadata),
    }


def load_metadata(path: Path = METADATA) -> dict:
    with path.open(encoding="utf-8") as source:
        metadata = json.load(source)
    validate_metadata(metadata)
    return metadata


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if checked-in generated files differ from bindings.json",
    )
    parser.add_argument("--metadata", type=Path, default=METADATA)
    args = parser.parse_args()

    try:
        outputs = render_outputs(load_metadata(args.metadata))
    except (MetadataError, json.JSONDecodeError) as error:
        print(f"generator metadata error: {error}", file=sys.stderr)
        return 2

    stale: list[Path] = []
    for path, contents in outputs.items():
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != contents:
                stale.append(path.relative_to(ROOT))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents, encoding="utf-8")

    if stale:
        print(
            "generated files are stale: " + ", ".join(str(path) for path in stale),
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
