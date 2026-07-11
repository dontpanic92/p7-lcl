unit P7LclAbi;

{$mode objfpc}{$H+}
{$packrecords c}

interface

uses
  SysUtils;

const
  P7_NATIVE_ABI_VERSION = 1;

  P7_STATUS_OK = 0;
  P7_STATUS_ERROR = 1;
  P7_STATUS_INVALID_ARGUMENT = 2;
  P7_STATUS_TYPE_MISMATCH = 3;
  P7_STATUS_STALE_HANDLE = 4;
  P7_STATUS_PANIC = 5;

  P7_TYPE_ANY = 0;
  P7_TYPE_INT = 1;
  P7_TYPE_FLOAT = 2;
  P7_TYPE_BOOL = 3;
  P7_TYPE_STRING = 4;
  P7_TYPE_ARRAY = 5;
  P7_TYPE_TUPLE = 6;
  P7_TYPE_MAP = 7;
  P7_TYPE_CLOSURE = 8;
  P7_TYPE_FOREIGN = 9;
  P7_TYPE_I8 = 10;
  P7_TYPE_U8 = 11;
  P7_TYPE_I16 = 12;
  P7_TYPE_U16 = 13;
  P7_TYPE_I32 = 14;
  P7_TYPE_U32 = 15;
  P7_TYPE_I64 = 16;
  P7_TYPE_U64 = 17;

  P7_CALLBACK_UNIT = 0;
  P7_CALLBACK_INT = 1;
  P7_CALLBACK_FLOAT = 2;
  P7_CALLBACK_BOOL = 3;
  P7_CALLBACK_STRING = 4;
  P7_CALLBACK_FOREIGN = 5;

type
  TP7Status = LongWord;
  TP7NativeType = LongWord;

  TP7CallbackValue = record
    Kind: LongWord;
    IntValue: Int64;
    FloatValue: Double;
    Bytes: PByte;
    Length: PtrUInt;
  end;
  PP7CallbackValue = ^TP7CallbackValue;

  TP7Value = record
    Token: QWord;
  end;
  PP7Value = ^TP7Value;
  TP7ValueArray = array[0..(MaxInt div SizeOf(TP7Value)) - 1] of TP7Value;
  PP7ValueArray = ^TP7ValueArray;

  PP7CallApi = ^TP7CallApi;
  PP7HostApi = ^TP7HostApi;

  TP7NativeCallback = function(
    Userdata: Pointer;
    Api: PP7CallApi;
    Args: PP7Value;
    ArgCount: PtrUInt;
    Output: PP7Value
  ): TP7Status; cdecl;

  TP7DropUserdata = procedure(Userdata: Pointer); cdecl;

  TP7NativeFunctionDescriptor = record
    StructSize: PtrUInt;
    Name: PAnsiChar;
    Params: ^TP7NativeType;
    ParamCount: PtrUInt;
    ResultType: TP7NativeType;
    HasResult: Byte;
    Callback: TP7NativeCallback;
    Userdata: Pointer;
    DropUserdata: TP7DropUserdata;
  end;
  PP7NativeFunctionDescriptor = ^TP7NativeFunctionDescriptor;

  TP7RegisterFunction = function(
    Runtime: Pointer;
    Descriptor: PP7NativeFunctionDescriptor
  ): TP7Status; cdecl;

  TP7RegisterForeignType = function(
    Runtime: Pointer;
    TypeTag: PAnsiChar;
    Finalizer: PAnsiChar
  ): TP7Status; cdecl;

  TP7InvalidateRuntimeHandle = function(
    Runtime: Pointer;
    TypeTag: PByte;
    TypeTagLength: PtrUInt;
    Handle: Int64
  ): TP7Status; cdecl;
  TP7InvokeRootedCallback = function(
    Runtime: Pointer;
    Token: QWord
  ): TP7Status; cdecl;
  TP7ReleaseRootedCallback = function(
    Runtime: Pointer;
    Token: QWord
  ): TP7Status; cdecl;
  TP7InvokeRootedCallbackValues = function(
    Runtime: Pointer;
    Token: QWord;
    Args: PP7CallbackValue;
    ArgCount: PtrUInt;
    Output: PP7CallbackValue
  ): TP7Status; cdecl;

  TP7HostApi = record
    AbiVersion: LongWord;
    StructSize: PtrUInt;
    Runtime: Pointer;
    RegisterFunction: TP7RegisterFunction;
    RegisterForeignType: TP7RegisterForeignType;
    InvalidateForeignHandle: TP7InvalidateRuntimeHandle;
    InvokeRootedCallback: TP7InvokeRootedCallback;
    ReleaseRootedCallback: TP7ReleaseRootedCallback;
    InvokeRootedCallbackValues: TP7InvokeRootedCallbackValues;
  end;

  TP7ValueKindFn = function(Api: PP7CallApi; Value: TP7Value): LongWord; cdecl;
  TP7GetIntFn = function(
    Api: PP7CallApi;
    Value: TP7Value;
    Output: PInt64
  ): TP7Status; cdecl;
  TP7GetFloatFn = function(Api: PP7CallApi; Value: TP7Value; Output: PDouble): TP7Status; cdecl;
  TP7GetBoolFn = function(Api: PP7CallApi; Value: TP7Value; Output: PByte): TP7Status; cdecl;
  TP7CopyStringFn = function(
    Api: PP7CallApi;
    Value: TP7Value;
    Output: PByte;
    Capacity: PtrUInt;
    Length: PPtrUInt
  ): TP7Status; cdecl;
  TP7MakeIntFn = function(Api: PP7CallApi; Value: Int64; Output: PP7Value): TP7Status; cdecl;
  TP7MakeFloatFn = function(Api: PP7CallApi; Value: Double; Output: PP7Value): TP7Status; cdecl;
  TP7MakeBoolFn = function(Api: PP7CallApi; Value: Byte; Output: PP7Value): TP7Status; cdecl;
  TP7MakeStringFn = function(
    Api: PP7CallApi;
    Value: PByte;
    Length: PtrUInt;
    Output: PP7Value
  ): TP7Status; cdecl;
  TP7MakeForeignFn = function(
    Api: PP7CallApi;
    TypeTag: PByte;
    TypeTagLength: PtrUInt;
    Handle: Int64;
    Output: PP7Value
  ): TP7Status; cdecl;
  TP7InvalidateCallHandleFn = function(
    Api: PP7CallApi;
    TypeTag: PByte;
    TypeTagLength: PtrUInt;
    Handle: Int64
  ): TP7Status; cdecl;
  TP7InvokeCallbackFn = function(
    Api: PP7CallApi;
    Callback: TP7Value;
    Args: PP7Value;
    ArgCount: PtrUInt;
    Output: PP7Value
  ): TP7Status; cdecl;
  TP7SetErrorFn = function(
    Api: PP7CallApi;
    Message: PByte;
    Length: PtrUInt
  ): TP7Status; cdecl;
  TP7SetErrorDetailsFn = function(
    Api: PP7CallApi;
    OperationName: PByte;
    OperationLength: PtrUInt;
    ErrorClass: PByte;
    ErrorClassLength: PtrUInt;
    Message: PByte;
    MessageLength: PtrUInt
  ): TP7Status; cdecl;
  TP7GetForeignFn = function(
    Api: PP7CallApi;
    Value: TP7Value;
    TypeTag: PByte;
    TypeTagLength: PtrUInt;
    Output: PInt64
  ): TP7Status; cdecl;
  TP7RetainCallbackFn = function(
    Api: PP7CallApi;
    Value: TP7Value;
    Output: PQWord
  ): TP7Status; cdecl;

  TP7CallApi = record
    AbiVersion: LongWord;
    StructSize: PtrUInt;
    Context: Pointer;
    ValueKind: TP7ValueKindFn;
    GetInt: TP7GetIntFn;
    GetFloat: TP7GetFloatFn;
    GetBool: TP7GetBoolFn;
    CopyString: TP7CopyStringFn;
    MakeInt: TP7MakeIntFn;
    MakeFloat: TP7MakeFloatFn;
    MakeBool: TP7MakeBoolFn;
    MakeString: TP7MakeStringFn;
    MakeForeignOwned: TP7MakeForeignFn;
    MakeForeignRef: TP7MakeForeignFn;
    MakeForeignHandle: TP7MakeForeignFn;
    InvalidateForeignHandle: TP7InvalidateCallHandleFn;
    InvokeCallback: TP7InvokeCallbackFn;
    SetError: TP7SetErrorFn;
    GetForeign: TP7GetForeignFn;
    RetainCallback: TP7RetainCallbackFn;
    Runtime: Pointer;
    SetErrorDetails: TP7SetErrorDetailsFn;
  end;

function P7HostApiRequiredSize: PtrUInt;
function P7CallApiHasSetErrorDetails(Api: PP7CallApi): Boolean;
procedure P7AssertAbiLayout;

implementation

function FieldEnd(const RecordAddress, FieldAddress: Pointer;
  FieldSize: PtrUInt): PtrUInt;
begin
  Result := PtrUInt(FieldAddress) - PtrUInt(RecordAddress) + FieldSize;
end;

function P7HostApiRequiredSize: PtrUInt;
var
  Api: TP7HostApi;
begin
  Result := FieldEnd(@Api, @Api.InvokeRootedCallbackValues,
    SizeOf(Api.InvokeRootedCallbackValues));
end;

function P7CallApiHasSetErrorDetails(Api: PP7CallApi): Boolean;
var
  Layout: TP7CallApi;
  RequiredSize: PtrUInt;
begin
  RequiredSize := FieldEnd(@Layout, @Layout.SetErrorDetails,
    SizeOf(Layout.SetErrorDetails));
  Result := Assigned(Api) and (Api^.StructSize >= RequiredSize);
end;

procedure RequireLayout(const Name: String; Actual, Expected: PtrUInt);
begin
  if Actual <> Expected then
    raise Exception.CreateFmt('%s ABI layout mismatch: expected %d, got %d',
      [Name, Expected, Actual]);
end;

procedure P7AssertAbiLayout;
var
  CallbackValue: TP7CallbackValue;
  Descriptor: TP7NativeFunctionDescriptor;
  HostApi: TP7HostApi;
  CallApi: TP7CallApi;
begin
  if SizeOf(Pointer) <> 8 then
    Exit;

  RequireLayout('P7CallbackValue.size', SizeOf(TP7CallbackValue), 40);
  RequireLayout('P7CallbackValue.int_value',
    PtrUInt(@CallbackValue.IntValue) - PtrUInt(@CallbackValue), 8);
  RequireLayout('P7CallbackValue.float_value',
    PtrUInt(@CallbackValue.FloatValue) - PtrUInt(@CallbackValue), 16);
  RequireLayout('P7CallbackValue.bytes',
    PtrUInt(@CallbackValue.Bytes) - PtrUInt(@CallbackValue), 24);
  RequireLayout('P7CallbackValue.length',
    PtrUInt(@CallbackValue.Length) - PtrUInt(@CallbackValue), 32);

  RequireLayout('P7Value.size', SizeOf(TP7Value), 8);
  RequireLayout('P7NativeFunctionDescriptor.size',
    SizeOf(TP7NativeFunctionDescriptor), 64);
  RequireLayout('P7NativeFunctionDescriptor.callback',
    PtrUInt(@Descriptor.Callback) - PtrUInt(@Descriptor), 40);
  RequireLayout('P7NativeFunctionDescriptor.drop_userdata',
    PtrUInt(@Descriptor.DropUserdata) - PtrUInt(@Descriptor), 56);

  RequireLayout('P7HostApi.size', SizeOf(TP7HostApi), 72);
  RequireLayout('P7HostApi.struct_size',
    PtrUInt(@HostApi.StructSize) - PtrUInt(@HostApi), 8);
  RequireLayout('P7HostApi.invoke_rooted_callback_values',
    PtrUInt(@HostApi.InvokeRootedCallbackValues) - PtrUInt(@HostApi), 64);

  RequireLayout('P7CallApi.size', SizeOf(TP7CallApi), 176);
  RequireLayout('P7CallApi.struct_size',
    PtrUInt(@CallApi.StructSize) - PtrUInt(@CallApi), 8);
  RequireLayout('P7CallApi.set_error_details',
    PtrUInt(@CallApi.SetErrorDetails) - PtrUInt(@CallApi), 168);
end;

end.
