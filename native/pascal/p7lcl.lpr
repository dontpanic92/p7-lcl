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
  Graphics,
  StdCtrls,
  ExtCtrls,
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
  P7_TYPE_I32 = 14;
  P7_TYPE_U32 = 15;

  OBJECT_TYPE_TAG: PAnsiChar = 'lcl.TObject';
  COMPONENT_TYPE_TAG: PAnsiChar = 'lcl.TComponent';
  CONTROL_TYPE_TAG: PAnsiChar = 'lcl.TControl';
  WIN_CONTROL_TYPE_TAG: PAnsiChar = 'lcl.TWinControl';
  FORM_TYPE_TAG: PAnsiChar = 'lcl.TForm';
  BUTTON_TYPE_TAG: PAnsiChar = 'lcl.TButton';
  LABEL_TYPE_TAG: PAnsiChar = 'lcl.TLabel';
  EDIT_TYPE_TAG: PAnsiChar = 'lcl.TEdit';
  PANEL_TYPE_TAG: PAnsiChar = 'lcl.TPanel';

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

  TP7Form = class(TForm)
  private
    FCloseCallback: QWord;
    FCloseRuntime: Pointer;
    FCloseQueryCallback: QWord;
    FCloseQueryRuntime: Pointer;
    FHandlingClose: Boolean;
    procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure HandleCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearCloseCallback;
    procedure ClearCloseQueryCallback;
    function IsHandlingClose: Boolean;
    procedure SetCloseCallback(Runtime: Pointer; Token: QWord);
    procedure SetCloseQueryCallback(Runtime: Pointer; Token: QWord);
  end;

var
  ApplicationInitialized: Boolean = False;
  UiThreadAssigned: Boolean = False;
  UiThreadId: TThreadID;

constructor TP7Form.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  OnClose := @HandleClose;
  OnCloseQuery := @HandleCloseQuery;
end;

procedure TP7Form.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FHandlingClose := True;
  try
    InvokeVoidEvent(FCloseRuntime, FCloseCallback);
  finally
    FHandlingClose := False;
  end;
  CloseAction := caHide;
  Application.Terminate;
end;

function TP7Form.IsHandlingClose: Boolean;
begin
  Result := FHandlingClose;
end;

procedure TP7Form.HandleCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  UpdatedValue: Int64;
begin
  if (FCloseQueryCallback <> 0) and
     InvokeNoArgIntEvent(FCloseQueryRuntime, FCloseQueryCallback, UpdatedValue) then
    CanClose := UpdatedValue <> 0;
end;

procedure TP7Form.ClearCloseCallback;
begin
  ReleaseEvent(FCloseRuntime, FCloseCallback);
  FCloseRuntime := nil;
end;

procedure TP7Form.ClearCloseQueryCallback;
begin
  ReleaseEvent(FCloseQueryRuntime, FCloseQueryCallback);
  FCloseQueryRuntime := nil;
end;

procedure TP7Form.SetCloseCallback(Runtime: Pointer; Token: QWord);
begin
  ClearCloseCallback;
  FCloseRuntime := Runtime;
  FCloseCallback := Token;
end;

procedure TP7Form.SetCloseQueryCallback(Runtime: Pointer; Token: QWord);
begin
  ClearCloseQueryCallback;
  FCloseQueryRuntime := Runtime;
  FCloseQueryCallback := Token;
end;

function ErrorStatus(Api: PP7CallApi; const MessageText: String): TP7Status;
var
  Separator: SizeInt;
  ClassText: String;
  DetailText: String;
  EncodedClass: UTF8String;
  EncodedDetail: UTF8String;
begin
  Separator := Pos(': ', MessageText);
  if Separator > 1 then
  begin
    ClassText := Copy(MessageText, 1, Separator - 1);
    DetailText := Copy(MessageText, Separator + 2, MaxInt)
  end
  else
  begin
    ClassText := '';
    DetailText := MessageText
  end;
  EncodedClass := UTF8Encode(ClassText);
  EncodedDetail := UTF8Encode(DetailText);
  if Assigned(Api)
    and (Api^.StructSize >= SizeOf(TP7CallApi))
    and Assigned(Api^.SetErrorDetails) then
    Api^.SetErrorDetails(
      Api,
      nil,
      0,
      PByte(PAnsiChar(EncodedClass)),
      Length(EncodedClass),
      PByte(PAnsiChar(EncodedDetail)),
      Length(EncodedDetail)
    )
  else if Assigned(Api) and Assigned(Api^.SetError) then
    Api^.SetError(
      Api,
      PByte(PAnsiChar(EncodedDetail)),
      Length(EncodedDetail)
    );
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
  Handle := AddObject(Instance, Api^.Runtime, UTF8String(TypeTag));
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

function MakeHandleObject(
  Api: PP7CallApi;
  Instance: TObject;
  TypeTag: PAnsiChar;
  Output: PP7Value
): TP7Status;
var
  Handle: Int64;
begin
  Handle := AddObject(Instance, Api^.Runtime, UTF8String(TypeTag));
  Result := Api^.MakeForeignHandle(
    Api,
    PByte(TypeTag),
    StrLen(TypeTag),
    Handle,
    Output
  );
  if Result <> P7_STATUS_OK then
    ReleaseObject(Handle);
end;

function MakeBorrowedObject(
  Api: PP7CallApi;
  Instance: TObject;
  TypeTag: PAnsiChar;
  Output: PP7Value
): TP7Status;
var
  Handle: Int64;
  DynamicTypeTag: UTF8String;
begin
  if not FindObjectHandle(Instance, Handle, DynamicTypeTag) then
    Exit(ErrorStatus(Api, 'LCL object is not registered'));
  Result := Api^.MakeForeignHandle(
    Api,
    PByte(TypeTag),
    StrLen(TypeTag),
    Handle,
    Output
  );
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

procedure ClearComponentCallbacks(Component: TComponent);
var
  Index: Integer;
begin
  if Component is TP7Button then
    TP7Button(Component).ClearCallback
  else if Component is TP7Edit then
  begin
    TP7Edit(Component).ClearCallback;
    TP7Edit(Component).ClearKeyPressCallback;
  end;
  for Index := 0 to Component.ComponentCount - 1 do
    ClearComponentCallbacks(Component.Components[Index]);
end;

procedure ReleaseControlObject(Handle: Int64);
var
  Instance: TObject;
begin
  if EventCallbackActive then
  begin
    Instance := DetachObject(Handle);
    if Instance <> nil then
      QueueObjectFree(Instance);
  end
  else
    ReleaseObject(Handle);
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

function ApplicationProcessMessages(
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
    Application.ProcessMessages;
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

function ApplicationInvoke(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  Token: QWord;
  CallbackError: String;
begin
  Token := 0;
  try
    if ArgCount <> 1 then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    Result := RetainEventCallback(Api, PP7ValueArray(Args)^[0], Token);
    if Result <> P7_STATUS_OK then
      Exit;
    InvokeVoidEvent(Api^.Runtime, Token);
    ReleaseEvent(Api^.Runtime, Token);
    CallbackError := ConsumeCallbackError;
    if CallbackError = '' then
      Result := P7_STATUS_OK
    else
      Result := ErrorStatus(Api, CallbackError);
  except
    on E: Exception do
    begin
      if Token <> 0 then
        ReleaseEvent(Api^.Runtime, Token);
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
    end;
  end;
end;

function ApplicationQueue(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  Token: QWord;
begin
  Token := 0;
  try
    if ArgCount <> 1 then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    Result := RetainEventCallback(Api, PP7ValueArray(Args)^[0], Token);
    if Result <> P7_STATUS_OK then
      Exit;
    QueueVoidEvent(Api^.Runtime, Token);
    Token := 0;
    Result := P7_STATUS_OK;
  except
    on E: Exception do
    begin
      if Token <> 0 then
        ReleaseEvent(Api^.Runtime, Token);
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
    end;
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

function ReadComponent(Api: PP7CallApi; Value: TP7Value;
  out Component: TComponent): TP7Status;
var
  Instance: TObject;
begin
  Result := ReadObject(Api, Value, COMPONENT_TYPE_TAG, TComponent, Instance);
  if Result = P7_STATUS_OK then
    Component := TComponent(Instance);
end;

function ReadControl(Api: PP7CallApi; Value: TP7Value;
  out Control: TControl): TP7Status;
var
  Instance: TObject;
begin
  Result := ReadObject(Api, Value, CONTROL_TYPE_TAG, TControl, Instance);
  if Result = P7_STATUS_OK then
    Control := TControl(Instance);
end;

function ReadWinControl(Api: PP7CallApi; Value: TP7Value;
  out Control: TWinControl): TP7Status;
var
  Instance: TObject;
begin
  Result := ReadObject(Api, Value, WIN_CONTROL_TYPE_TAG, TWinControl, Instance);
  if Result = P7_STATUS_OK then
    Control := TWinControl(Instance);
end;

function MakeInteger(Api: PP7CallApi; Value: Integer;
  Output: PP7Value): TP7Status;
begin
  Result := Api^.MakeInt(Api, Value, Output);
end;

function MakeBoolean(Api: PP7CallApi; Value: Boolean;
  Output: PP7Value): TP7Status;
begin
  Result := Api^.MakeBool(Api, Ord(Value), Output);
end;

function ComponentSetName(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Component: TComponent;
  Name: UTF8String;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadComponent(Api, PP7ValueArray(Args)^[0], Component);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadString(Api, PP7ValueArray(Args)^[1], Name);
    if Result <> P7_STATUS_OK then Exit;
    Component.Name := String(Name);
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ComponentName(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Component: TComponent;
  Name: UTF8String;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadComponent(Api, PP7ValueArray(Args)^[0], Component);
    if Result <> P7_STATUS_OK then Exit;
    Name := UTF8String(Component.Name);
    Result := Api^.MakeString(Api, PByte(PAnsiChar(Name)), Length(Name), Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ComponentOwner(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Component: TComponent;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadComponent(Api, PP7ValueArray(Args)^[0], Component);
    if Result <> P7_STATUS_OK then Exit;
    if Component.Owner = nil then
      Exit(ErrorStatus(Api, 'LCL component has no owner'));
    Result := MakeBorrowedObject(Api, Component.Owner, COMPONENT_TYPE_TAG, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlParent(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    if Control.Parent = nil then
      Exit(ErrorStatus(Api, 'LCL control has no parent'));
    Result := MakeBorrowedObject(Api, Control.Parent, WIN_CONTROL_TYPE_TAG, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlSetParent(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Control: TControl;
  Parent: TWinControl;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadWinControl(Api, PP7ValueArray(Args)^[1], Parent);
    if Result <> P7_STATUS_OK then Exit;
    if Control = Parent then
      Exit(ErrorStatus(Api, 'a control cannot parent itself'));
    Control.Parent := Parent;
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlSetBounds(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Control: TControl;
  ALeft, ATop, AWidth, AHeight: Integer;
begin
  try
    if (ArgCount <> 5) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadBounds(Api, PP7ValueArray(Args), ALeft, ATop, AWidth, AHeight);
    if Result <> P7_STATUS_OK then Exit;
    if (AWidth < 0) or (AHeight < 0) then
      Exit(ErrorStatus(Api, 'control width and height must be non-negative'));
    Control.SetBounds(ALeft, ATop, AWidth, AHeight);
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlLeft(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := MakeInteger(Api, Control.Left, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlTop(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := MakeInteger(Api, Control.Top, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlWidth(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := MakeInteger(Api, Control.Width, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlHeight(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := MakeInteger(Api, Control.Height, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlVisible(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := MakeBoolean(Api, Control.Visible, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlSetVisible(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl; Value: Boolean;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadBoolean(Api, PP7ValueArray(Args)^[1], Value);
    if Result <> P7_STATUS_OK then Exit;
    Control.Visible := Value;
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlEnabled(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := MakeBoolean(Api, Control.Enabled, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlSetEnabled(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl; Value: Boolean;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadBoolean(Api, PP7ValueArray(Args)^[1], Value);
    if Result <> P7_STATUS_OK then Exit;
    Control.Enabled := Value;
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlShow(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Control.Show;
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlHide(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Control.Hide;
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlAlign(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := MakeInteger(Api, Ord(Control.Align), Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlSetAlign(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl; Value: Integer;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[1], Value);
    if Result <> P7_STATUS_OK then Exit;
    if (Value < Ord(Low(TAlign))) or (Value > Ord(High(TAlign))) then
      Exit(ErrorStatus(Api, 'invalid TAlign value'));
    Control.Align := TAlign(Value);
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function AnchorsToBits(const Anchors: TAnchors): LongWord;
begin
  Result := 0;
  if akTop in Anchors then Result := Result or 1;
  if akLeft in Anchors then Result := Result or 2;
  if akRight in Anchors then Result := Result or 4;
  if akBottom in Anchors then Result := Result or 8;
end;

function ControlAnchors(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := Api^.MakeInt(Api, AnchorsToBits(Control.Anchors), Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlSetAnchors(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl; Wide: Int64; Value: LongWord; Anchors: TAnchors;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Result := Api^.GetInt(Api, PP7ValueArray(Args)^[1], @Wide);
    if Result <> P7_STATUS_OK then Exit;
    if (Wide < 0) or (Wide > 15) then
      Exit(ErrorStatus(Api, 'invalid TAnchors bit set'));
    Value := LongWord(Wide);
    Anchors := [];
    if Value and 1 <> 0 then Include(Anchors, akTop);
    if Value and 2 <> 0 then Include(Anchors, akLeft);
    if Value and 4 <> 0 then Include(Anchors, akRight);
    if Value and 8 <> 0 then Include(Anchors, akBottom);
    Control.Anchors := Anchors;
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlColor(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := Api^.MakeInt(Api, Control.Color, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ControlSetColor(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TControl; Value: Integer;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[1], Value);
    if Result <> P7_STATUS_OK then Exit;
    Control.Color := TColor(Value);
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function WinControlCanFocus(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TWinControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadWinControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := MakeBoolean(Api, Control.CanFocus, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function WinControlSetFocus(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TWinControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadWinControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    if not Control.CanFocus then Exit(ErrorStatus(Api, 'LCL control cannot receive focus'));
    Control.SetFocus;
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function WinControlTabOrder(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TWinControl;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadWinControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result = P7_STATUS_OK then Result := MakeInteger(Api, Control.TabOrder, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function WinControlSetTabOrder(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Control: TWinControl; Value: Integer;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadWinControl(Api, PP7ValueArray(Args)^[0], Control);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[1], Value);
    if Result <> P7_STATUS_OK then Exit;
    if Value < 0 then Exit(ErrorStatus(Api, 'tab order must be non-negative'));
    Control.TabOrder := Value;
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
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
    Handle := AddObject(Form, Api^.Runtime, UTF8String(FORM_TYPE_TAG));
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
    CallbackError: String;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then
        Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
      if Result <> P7_STATUS_OK then Exit;
      Form.Close;
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

function FormSetOnClose(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
      ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
    var
      Form: TForm;
      Token: QWord;
    begin
      try
        if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
        Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
        if Result <> P7_STATUS_OK then Exit;
        Result := RetainEventCallback(Api, PP7ValueArray(Args)^[1], Token);
        if Result <> P7_STATUS_OK then Exit;
        TP7Form(Form).SetCloseCallback(Api^.Runtime, Token);
        Result := P7_STATUS_OK;
      except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
    end;

    function FormClearOnClose(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
      ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
    var
      Form: TForm;
    begin
      try
        if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
        Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
        if Result <> P7_STATUS_OK then Exit;
        TP7Form(Form).ClearCloseCallback;
        Result := P7_STATUS_OK;
      except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
    end;

    function FormSetOnCloseQuery(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
      ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
    var
      Form: TForm;
      Token: QWord;
    begin
      try
        if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
        Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
        if Result <> P7_STATUS_OK then Exit;
        Result := RetainEventCallback(Api, PP7ValueArray(Args)^[1], Token);
        if Result <> P7_STATUS_OK then Exit;
        TP7Form(Form).SetCloseQueryCallback(Api^.Runtime, Token);
        Result := P7_STATUS_OK;
      except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
    end;

    function FormClearOnCloseQuery(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
      ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
    var
      Form: TForm;
    begin
      try
        if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
        Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
        if Result <> P7_STATUS_OK then Exit;
        TP7Form(Form).ClearCloseQueryCallback;
        Result := P7_STATUS_OK;
      except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
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
      Button := TP7Button.Create(Form);
      Button.Parent := Form;
      Result := MakeHandleObject(Api, Button, BUTTON_TYPE_TAG, Output);
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

  function ButtonSetVisible(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    Visible: Boolean;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG, TP7Button, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBoolean(Api, PP7ValueArray(Args)^[1], Visible);
      if Result <> P7_STATUS_OK then Exit;
      TP7Button(Instance).Visible := Visible;
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
      ReleaseControlObject(Handle);
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
      LabelControl := TLabel.Create(Form);
      LabelControl.Parent := Form;
      Result := MakeHandleObject(Api, LabelControl, LABEL_TYPE_TAG, Output);
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
      ReleaseControlObject(Handle);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function LabelSetVisible(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    Visible: Boolean;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], LABEL_TYPE_TAG, TLabel, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBoolean(Api, PP7ValueArray(Args)^[1], Visible);
      if Result <> P7_STATUS_OK then Exit;
      TLabel(Instance).Visible := Visible;
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
      EditControl := TP7Edit.Create(Form);
      EditControl.Parent := Form;
      Result := MakeHandleObject(Api, EditControl, EDIT_TYPE_TAG, Output);
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

  function EditSetEnabled(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    Enabled: Boolean;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBoolean(Api, PP7ValueArray(Args)^[1], Enabled);
      if Result <> P7_STATUS_OK then Exit;
      TP7Edit(Instance).Enabled := Enabled;
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditSetVisible(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    Visible: Boolean;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBoolean(Api, PP7ValueArray(Args)^[1], Visible);
      if Result <> P7_STATUS_OK then Exit;
      TP7Edit(Instance).Visible := Visible;
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditSetFocus(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      TP7Edit(Instance).SetFocus;
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

  function EditSetOnKeyPress(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    Token: QWord;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := RetainEventCallback(Api, PP7ValueArray(Args)^[1], Token);
      if Result <> P7_STATUS_OK then Exit;
      TP7Edit(Instance).SetKeyPressCallback(Api^.Runtime, Token);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditClearOnKeyPress(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      TP7Edit(Instance).ClearKeyPressCallback;
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function EditSendKeyPress(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Instance: TObject;
    KeyCode: Integer;
    Key: Char;
    CallbackError: String;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG, TP7Edit, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadInt(Api, PP7ValueArray(Args)^[1], KeyCode);
      if Result <> P7_STATUS_OK then Exit;
      if (KeyCode < 0) or (KeyCode > High(Byte)) then
        Exit(ErrorStatus(Api, 'key code is outside the character range'));
      Key := Char(KeyCode);
      TP7Edit(Instance).TriggerKeyPress(Key);
      CallbackError := ConsumeCallbackError;
      if CallbackError <> '' then
        Exit(ErrorStatus(Api, CallbackError));
      Result := Api^.MakeInt(Api, Ord(Key), Output);
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
      EditControl.ClearKeyPressCallback;
      ReleaseControlObject(Handle);
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

  function PanelCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var
    Form: TForm;
    Panel: TPanel;
  begin
    Panel := nil;
    try
      if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
      if Result <> P7_STATUS_OK then Exit;
      Panel := TPanel.Create(Form);
      Panel.Parent := Form;
      Result := MakeHandleObject(Api, Panel, PANEL_TYPE_TAG, Output);
    except on E: Exception do begin Panel.Free; Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end; end;
  end;

  function PanelSetCaption(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; Caption: UTF8String;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], PANEL_TYPE_TAG, TPanel, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadString(Api, PP7ValueArray(Args)^[1], Caption);
      if Result <> P7_STATUS_OK then Exit;
      TPanel(Instance).Caption := String(Caption);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function PanelSetBounds(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; ALeft, ATop, AWidth, AHeight: Integer;
  begin
    try
      if (ArgCount <> 5) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], PANEL_TYPE_TAG, TPanel, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBounds(Api, PP7ValueArray(Args), ALeft, ATop, AWidth, AHeight);
      if Result <> P7_STATUS_OK then Exit;
      TPanel(Instance).SetBounds(ALeft, ATop, AWidth, AHeight);
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function PanelSetEnabled(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; Enabled: Boolean;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], PANEL_TYPE_TAG, TPanel, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBoolean(Api, PP7ValueArray(Args)^[1], Enabled);
      if Result <> P7_STATUS_OK then Exit;
      TPanel(Instance).Enabled := Enabled;
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function PanelSetVisible(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Instance: TObject; Visible: Boolean;
  begin
    try
      if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := ReadObject(Api, PP7ValueArray(Args)^[0], PANEL_TYPE_TAG, TPanel, Instance);
      if Result <> P7_STATUS_OK then Exit;
      Result := ReadBoolean(Api, PP7ValueArray(Args)^[1], Visible);
      if Result <> P7_STATUS_OK then Exit;
      TPanel(Instance).Visible := Visible;
      Result := P7_STATUS_OK;
    except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
  end;

  function PanelFree(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
    ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
  var Handle: Int64;
  begin
    try
      if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
      Result := Api^.GetForeign(Api, PP7ValueArray(Args)^[0], PByte(PANEL_TYPE_TAG),
        StrLen(PANEL_TYPE_TAG), @Handle);
      if Result <> P7_STATUS_OK then Exit;
      ReleaseControlObject(Handle);
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
  Form: TP7Form;
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
    Form := TP7Form(FindObject(Handle, TP7Form));
    Form.ClearCloseCallback;
    Form.ClearCloseQueryCallback;
    ClearComponentCallbacks(Form);
    if Form.IsHandlingClose then
    begin
      Form := TP7Form(DetachObject(Handle));
      Form.Release;
    end
    else
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
  Instance: TObject;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureUiThread;
    Result := Api^.GetInt(Api, PP7ValueArray(Args)^[0], @Handle);
    if Result <> P7_STATUS_OK then
      Exit;
    Instance := FindObjectOrNil(Handle, TP7Form);
    if Instance <> nil then
    begin
      TP7Form(Instance).ClearCloseCallback;
      TP7Form(Instance).ClearCloseQueryCallback;
      ClearComponentCallbacks(TP7Form(Instance));
    end;
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
    if Instance <> nil then
    begin
      TP7Edit(Instance).ClearCallback;
      TP7Edit(Instance).ClearKeyPressCallback;
    end;

    ReleaseObject(Handle);
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function PanelFinalize(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin
  Result := LabelFinalize(Userdata, Api, Args, ArgCount, Output);
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
      Api^.ReleaseRootedCallback,
      Api^.InvokeRootedCallbackValues
    );
    ConfigureObjectInvalidation(Api^.InvalidateForeignHandle);
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
