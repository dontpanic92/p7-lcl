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
  Controls,
  StdCtrls,
  Classes,
  {$IFDEF LCLCOCOA}
  CocoaAll,
  {$ENDIF}
  SysUtils,
  P7LclObjects,
  P7LclEvents;

const
  P7_NATIVE_ABI_VERSION = 1;

  P7_STATUS_OK = 0;
  P7_STATUS_ERROR = 1;
  P7_STATUS_INVALID_ARGUMENT = 2;
  P7_TYPE_ANY = 0;
  P7_TYPE_INT = 1;
  P7_TYPE_BOOL = 3;
  P7_TYPE_STRING = 4;
  P7_TYPE_CLOSURE = 8;
  P7_TYPE_FOREIGN = 9;

  FORM_TYPE_TAG: PAnsiChar = 'lcl.TForm';
  BUTTON_TYPE_TAG: PAnsiChar = 'lcl.TButton';
  LABEL_TYPE_TAG: PAnsiChar = 'lcl.TLabel';
  EDIT_TYPE_TAG: PAnsiChar = 'lcl.TEdit';

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
  TP7InvokeRootedCallback = function(
    Runtime: Pointer;
    Token: QWord
  ): TP7Status; cdecl;
  TP7ReleaseRootedCallback = function(
    Runtime: Pointer;
    Token: QWord
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

function ReadObject(
  Api: PP7CallApi;
  Value: TP7Value;
  TypeTag: PAnsiChar;
  ExpectedClass: TClass;
  out Instance: TObject
): TP7Status;
var
  Handle: Int64;
begin
  EnsureUiThread;
  Result := Api^.GetForeign(
    Api,
    Value,
    PByte(TypeTag),
    StrLen(TypeTag),
    @Handle
  );
  if Result = P7_STATUS_OK then
    Instance := FindObject(Handle, ExpectedClass);
end;

function ReadInt(Api: PP7CallApi; Value: TP7Value; out Number: Integer): TP7Status;
var
  Wide: Int64;
begin
  Result := Api^.GetInt(Api, Value, @Wide);
  if Result = P7_STATUS_OK then
  begin
    if (Wide < Low(Integer)) or (Wide > High(Integer)) then
      Exit(ErrorStatus(Api, 'integer is outside the LCL coordinate range'));
    Number := Integer(Wide);
  end;
end;

function ReadBoolean(Api: PP7CallApi; Value: TP7Value; out Flag: Boolean): TP7Status;
var
  Raw: Byte;
begin
  Result := Api^.GetBool(Api, Value, @Raw);
  if Result = P7_STATUS_OK then
    Flag := Raw <> 0;
end;

function ReadBounds(
  Api: PP7CallApi;
  Args: PP7ValueArray;
  out ALeft, ATop, AWidth, AHeight: Integer
): TP7Status;
begin
  Result := ReadInt(Api, Args^[1], ALeft);
  if Result <> P7_STATUS_OK then Exit;
  Result := ReadInt(Api, Args^[2], ATop);
  if Result <> P7_STATUS_OK then Exit;
  Result := ReadInt(Api, Args^[3], AWidth);
  if Result <> P7_STATUS_OK then Exit;
  Result := ReadInt(Api, Args^[4], AHeight);
end;

function MakeOwnedObject(
  Api: PP7CallApi;
  Instance: TObject;
  TypeTag: PAnsiChar;
  Output: PP7Value
): TP7Status;
var
  Handle: Int64;
begin
  Handle := AddObject(Instance);
  Result := Api^.MakeForeignOwned(
    Api,
    PByte(TypeTag),
    StrLen(TypeTag),
    Handle,
    Output
  );
  if Result <> P7_STATUS_OK then
    ReleaseObject(Handle);
end;

function RetainEventCallback(
  Api: PP7CallApi;
  Value: TP7Value;
  out Token: QWord
): TP7Status;
begin
  Token := 0;
  Result := Api^.RetainCallback(Api, Value, @Token);
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
var
  CallbackError: String;
begin
  try
    if ArgCount <> 0 then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    Application.Run;
    CallbackError := ConsumeCallbackError;
    if CallbackError = '' then
      Result := P7_STATUS_OK
    else
      Result := ErrorStatus(Api, CallbackError);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function ApplicationTerminate(
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
    Application.Terminate;
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

function FormSetBounds(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  Form: TForm;
  ALeft, ATop, AWidth, AHeight: Integer;
begin
  try
    if (ArgCount <> 5) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadBounds(Api, PP7ValueArray(Args), ALeft, ATop, AWidth, AHeight);
    if Result <> P7_STATUS_OK then Exit;
    Form.SetBounds(ALeft, ATop, AWidth, AHeight);
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

function FormClose(
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
      if Result <> P7_STATUS_OK then Exit;
      Form.Close;
      Result := P7_STATUS_OK;
    except
      on E: Exception do
        Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
    end;
  end;

function ButtonCreate(
    Userdata: Pointer;
    Api: PP7CallApi;
    Args: PP7Value;
    ArgCount: PtrUInt;
    Output: PP7Value
  ): TP7Status; cdecl;
  var
    Form: TForm;
    Button: TP7Button;
  begin
    Button := nil;
    try
      if (ArgCount <> 1) or (Args = nil) or (Output = nil) then
        Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
      if Result <> P7_STATUS_OK then Exit;
      Button := TP7Button.Create(nil);
      Button.Parent := Form;
      Result := MakeOwnedObject(Api, Button, BUTTON_TYPE_TAG, Output);
    except
      on E: Exception do
      begin
        Button.Free;
        Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
      end;
    end;
  end;

  function ButtonSetCaption(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    Caption: UTF8String;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG, TP7Button, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadString(Api, PP7ValueArray(Args)^[1], Caption);
      if Result <> P7_STATUS_OK then Exit;
      TP7Button(Instance).Caption := String(Caption);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function ButtonSetBounds(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    ALeft, ATop, AWidth, AHeight: Integer;
  begin
    try
      if (ArgCount <> 5) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG, TP7Button, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBounds(Api, PP7ValueArray(Args), ALeft, ATop, AWidth, AHeight);
      if Result <> P7_STATUS_OK then Exit;
      TP7Button(Instance).SetBounds(ALeft, ATop, AWidth, AHeight);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function ButtonSetEnabled(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    Enabled: Boolean;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG, TP7Button, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBoolean(Api, PP7ValueArray(Args)^[1], Enabled);
      if Result <> P7_STATUS_OK then Exit;
      TP7Button(Instance).Enabled := Enabled;
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function ButtonSetOnClick(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    Token: QWord;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG, TP7Button, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := RetainEventCallback(Api, PP7ValueArray(Args)^[1], Token);
      if Result <> P7_STATUS_OK then Exit;
      TP7Button(Instance).SetCallback(Api^.Runtime, Token);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function ButtonClick(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    CallbackError: String;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG, TP7Button, Instance);
      if Result <> P7_STATUS_OK then Exit;
      TP7Button(Instance).Click;
      CallbackError := ConsumeCallbackError;
      if CallbackError = '' then
        Result := P7_STATUS_OK
      else
        Result := ErrorStatus(Api, CallbackError);
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function ButtonClearOnClick(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG, TP7Button, Instance);
      if Result <> P7_STATUS_OK then Exit;
      TP7Button(Instance).ClearCallback;
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function ButtonFree(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Handle: Int64;
    Button: TP7Button;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := Api^.GetForeign(Api, PP7ValueArray(Args)^[0], PByte(BUTTON_TYPE_TAG),
        StrLen(BUTTON_TYPE_TAG), @Handle);
      if Result <> P7_STATUS_OK then Exit;
      Button := TP7Button(FindObject(Handle, TP7Button));
      Button.ClearCallback;
      ReleaseObject(Handle);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function LabelCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Form: TForm;
    LabelControl: TLabel;
  begin
    LabelControl := nil;
    try
      if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
      if Result <> P7_STATUS_OK then Exit;
      LabelControl := TLabel.Create(nil);
      LabelControl.Parent := Form;
      Result := MakeOwnedObject(Api, LabelControl, LABEL_TYPE_TAG, Output);
    except on E: Exception do begin LabelControl.Free; Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end; end;
  end;

  function LabelSetCaption(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; Caption: UTF8String;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], LABEL_TYPE_TAG, TLabel, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadString(Api, PP7ValueArray(Args)^[1], Caption);
      if Result <> P7_STATUS_OK then Exit;
      TLabel(Instance).Caption := String(Caption);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function LabelCaption(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; Caption: UTF8String;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], LABEL_TYPE_TAG, TLabel, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Caption := UTF8String(TLabel(Instance).Caption);
      Result := Api^.MakeString(Api, PByte(PAnsiChar(Caption)), Length(Caption), Output);
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function LabelSetBounds(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; ALeft, ATop, AWidth, AHeight: Integer;
  begin
    try
      if (ArgCount <> 5) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], LABEL_TYPE_TAG, TLabel, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBounds(Api, PP7ValueArray(Args), ALeft, ATop, AWidth, AHeight);
      if Result <> P7_STATUS_OK then Exit;
      TLabel(Instance).SetBounds(ALeft, ATop, AWidth, AHeight);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function LabelFree(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Handle: Int64;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := Api^.GetForeign(Api, PP7ValueArray(Args)^[0], PByte(LABEL_TYPE_TAG),
        StrLen(LABEL_TYPE_TAG), @Handle);
      if Result <> P7_STATUS_OK then Exit;
      ReleaseObject(Handle);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Form: TForm; EditControl: TP7Edit;
  begin
    EditControl := nil;
    try
      if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
      if Result <> P7_STATUS_OK then Exit;
      EditControl := TP7Edit.Create(nil);
      EditControl.Parent := Form;
      Result := MakeOwnedObject(Api, EditControl, EDIT_TYPE_TAG, Output);
    except on E: Exception do begin EditControl.Free; Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end; end;
  end;

  function EditSetText(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; Text: UTF8String; CallbackError: String;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadString(Api, PP7ValueArray(Args)^[1], Text);
      if Result <> P7_STATUS_OK then Exit;
      TP7Edit(Instance).Text := String(Text);
      CallbackError := ConsumeCallbackError;
      if CallbackError = '' then
        Result := P7_STATUS_OK
      else
        Result := ErrorStatus(Api, CallbackError);
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditText(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; Text: UTF8String;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Text := UTF8String(TP7Edit(Instance).Text);
      Result := Api^.MakeString(Api, PByte(PAnsiChar(Text)), Length(Text), Output);
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditSetBounds(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; ALeft, ATop, AWidth, AHeight: Integer;
  begin
    try
      if (ArgCount <> 5) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBounds(Api, PP7ValueArray(Args), ALeft, ATop, AWidth, AHeight);
      if Result <> P7_STATUS_OK then Exit;
      TP7Edit(Instance).SetBounds(ALeft, ATop, AWidth, AHeight);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditSetOnChange(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; Token: QWord;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := RetainEventCallback(Api, PP7ValueArray(Args)^[1], Token);
      if Result <> P7_STATUS_OK then Exit;
      TP7Edit(Instance).SetCallback(Api^.Runtime, Token);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditFree(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Handle: Int64; EditControl: TP7Edit;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := Api^.GetForeign(Api, PP7ValueArray(Args)^[0], PByte(EDIT_TYPE_TAG),
        StrLen(EDIT_TYPE_TAG), @Handle);
      if Result <> P7_STATUS_OK then Exit;
      EditControl := TP7Edit(FindObject(Handle, TP7Edit));
      EditControl.ClearCallback;
      ReleaseObject(Handle);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditClearOnChange(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      TP7Edit(Instance).ClearCallback;
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
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

function ButtonFinalize(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Handle: Int64;
  Instance: TObject;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := Api^.GetInt(Api, PP7ValueArray(Args)^[0], @Handle);
    if Result <> P7_STATUS_OK then Exit;
    Instance := FindObjectOrNil(Handle, TP7Button);
    if Instance <> nil then TP7Button(Instance).ClearCallback;
    ReleaseObject(Handle);
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function LabelFinalize(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin
  Result := FormFinalize(Userdata, Api, Args, ArgCount, Output);
end;

function EditFinalize(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Handle: Int64;
  Instance: TObject;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := Api^.GetInt(Api, PP7ValueArray(Args)^[0], @Handle);
    if Result <> P7_STATUS_OK then Exit;
    Instance := FindObjectOrNil(Handle, TP7Edit);
    if Instance <> nil then TP7Edit(Instance).ClearCallback;
    ReleaseObject(Handle);
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
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

    ConfigureCallbacks(
      Api^.InvokeRootedCallback,
      Api^.ReleaseRootedCallback
    );
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
