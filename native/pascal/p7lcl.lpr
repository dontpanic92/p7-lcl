library p7lcl;

{$mode objfpc}{$H+}
{$packrecords c}
{$IFDEF DARWIN}
{$modeswitch objectivec1}
{$ENDIF}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms,
  Classes,
  {$IFDEF LCLCOCOA}
  CocoaAll,
  {$ENDIF}
  SysUtils,
  P7LclObjects;

const
  P7_NATIVE_ABI_VERSION = 1;

  P7_STATUS_OK = 0;
  P7_STATUS_ERROR = 1;
  P7_STATUS_INVALID_ARGUMENT = 2;
  P7_TYPE_ANY = 0;
  P7_TYPE_INT = 1;
  P7_TYPE_STRING = 4;
  P7_TYPE_FOREIGN = 9;

  FORM_TYPE_TAG: PAnsiChar = 'lcl.TForm';

type
  TP7Status = LongWord;
  TP7NativeType = LongWord;

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

  TP7HostApi = record
    AbiVersion: LongWord;
    StructSize: PtrUInt;
    Runtime: Pointer;
    RegisterFunction: TP7RegisterFunction;
    RegisterForeignType: TP7RegisterForeignType;
    InvalidateForeignHandle: TP7InvalidateRuntimeHandle;
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
  TP7GetForeignFn = function(
    Api: PP7CallApi;
    Value: TP7Value;
    TypeTag: PByte;
    TypeTagLength: PtrUInt;
    Output: PInt64
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
  end;

  TP7Form = class(TForm)
  private
    procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  ApplicationInitialized: Boolean = False;
  UiThreadAssigned: Boolean = False;
  UiThreadId: TThreadID;

constructor TP7Form.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  OnClose := @HandleClose;
end;

procedure TP7Form.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
  Application.Terminate;
end;

function ErrorStatus(Api: PP7CallApi; const MessageText: String): TP7Status;
var
  Encoded: UTF8String;
begin
  Encoded := UTF8Encode(MessageText);
  if Assigned(Api) and Assigned(Api^.SetError) then
    Api^.SetError(Api, PByte(PAnsiChar(Encoded)), Length(Encoded));
  Result := P7_STATUS_ERROR;
end;

procedure EnsureUiThread;
begin
  if not UiThreadAssigned then
  begin
    UiThreadAssigned := True;
    UiThreadId := GetCurrentThreadID
  end
  else if UiThreadId <> GetCurrentThreadID then
    raise Exception.Create('LCL operation called from a different thread');
end;

procedure EnsureApplication;
begin
  EnsureUiThread;
  if ApplicationInitialized then
    Exit;
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  {$IFDEF LCLCOCOA}
  NSApplication.sharedApplication.setActivationPolicy(
    NSApplicationActivationPolicyRegular
  );
  {$ENDIF}
  ApplicationInitialized := True;
end;

function ReadString(Api: PP7CallApi; Value: TP7Value; out Text: UTF8String): TP7Status;
var
  Required: PtrUInt;
begin
  Text := '';
  Required := 0;
  Result := Api^.CopyString(Api, Value, nil, 0, @Required);
  if Result <> P7_STATUS_OK then
    Exit;
  SetLength(Text, Required);
  if Required = 0 then
    Exit(P7_STATUS_OK);
  Result := Api^.CopyString(
    Api,
    Value,
    PByte(PAnsiChar(Text)),
    Required,
    @Required
  );
end;

function ReadForm(
  Api: PP7CallApi;
  Value: TP7Value;
  out Form: TForm
): TP7Status;
var
  Handle: Int64;
begin
  EnsureUiThread;
  Result := Api^.GetForeign(
    Api,
    Value,
    PByte(FORM_TYPE_TAG),
    StrLen(FORM_TYPE_TAG),
    @Handle
  );
  if Result <> P7_STATUS_OK then
    Exit;
  Form := TForm(FindObject(Handle, TForm));
end;

function ApplicationInitialize(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
begin
  try
    if ArgCount <> 0 then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    Result := P7_STATUS_OK;
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function ApplicationRun(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
begin
  try
    if ArgCount <> 0 then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    Application.Run;
    Result := P7_STATUS_OK;
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function FormCreate(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  Form: TForm;
  Handle: Int64;
begin
  Form := nil;
  Handle := 0;
  try
    if (ArgCount <> 0) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    Application.CreateForm(TP7Form, Form);
    Handle := AddObject(Form);
    Result := Api^.MakeForeignOwned(
      Api,
      PByte(FORM_TYPE_TAG),
      StrLen(FORM_TYPE_TAG),
      Handle,
      Output
    );
    if Result <> P7_STATUS_OK then
      ReleaseObject(Handle);
  except
    on E: Exception do
    begin
      if Handle <> 0 then
        ReleaseObject(Handle)
      else
        Form.Free;
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
    end;
  end;
end;

function FormSetCaption(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  Form: TForm;
  Caption: UTF8String;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then
      Exit;
    Result := ReadString(Api, PP7ValueArray(Args)^[1], Caption);
    if Result <> P7_STATUS_OK then
      Exit;
    Form.Caption := String(Caption);
    Result := P7_STATUS_OK;
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function FormCaption(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  Form: TForm;
  Caption: UTF8String;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then
      Exit;
    Caption := UTF8String(Form.Caption);
    Result := Api^.MakeString(
      Api,
      PByte(PAnsiChar(Caption)),
      Length(Caption),
      Output
    );
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function FormShow(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  Form: TForm;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then
      Exit;
    Form.Show;
    Application.BringToFront;
    {$IFDEF LCLCOCOA}
    NSApp.activateIgnoringOtherApps(True);
    {$ENDIF}
    Application.ProcessMessages;
    Result := P7_STATUS_OK;
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function FormFree(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  Handle: Int64;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureUiThread;
    Result := Api^.GetForeign(
      Api,
      PP7ValueArray(Args)^[0],
      PByte(FORM_TYPE_TAG),
      StrLen(FORM_TYPE_TAG),
      @Handle
    );
    if Result <> P7_STATUS_OK then
      Exit;
    ReleaseObject(Handle);
    Result := P7_STATUS_OK;
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function FormFinalize(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  Handle: Int64;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureUiThread;
    Result := Api^.GetInt(Api, PP7ValueArray(Args)^[0], @Handle);
    if Result <> P7_STATUS_OK then
      Exit;
    ReleaseObject(Handle);
    Result := P7_STATUS_OK;
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function RegisterFunction(
  Api: PP7HostApi;
  const Name: PAnsiChar;
  Params: PLongWord;
  ParamCount: PtrUInt;
  ResultType: LongWord;
  HasResult: Boolean;
  Callback: TP7NativeCallback
): TP7Status;
var
  Descriptor: TP7NativeFunctionDescriptor;
begin
  FillChar(Descriptor, SizeOf(Descriptor), 0);
  Descriptor.StructSize := SizeOf(Descriptor);
  Descriptor.Name := Name;
  Descriptor.Params := Params;
  Descriptor.ParamCount := ParamCount;
  Descriptor.ResultType := ResultType;
  Descriptor.HasResult := Ord(HasResult);
  Descriptor.Callback := Callback;
  Result := Api^.RegisterFunction(Api^.Runtime, @Descriptor);
end;

{$I generated/registration.inc}

function p7_extension_init_v1(Api: PP7HostApi): TP7Status; cdecl;
begin
  try
    if (Api = nil) or
       (Api^.AbiVersion <> P7_NATIVE_ABI_VERSION) or
       (Api^.StructSize < SizeOf(TP7HostApi)) then
      Exit(P7_STATUS_INVALID_ARGUMENT);

    Result := RegisterGeneratedFunctions(Api);
  except
    Result := P7_STATUS_ERROR;
  end;
end;

exports
  {$IFDEF DARWIN}
  p7_extension_init_v1 name '_p7_extension_init_v1';
  {$ELSE}
  p7_extension_init_v1 name 'p7_extension_init_v1';
  {$ENDIF}

begin
end.
