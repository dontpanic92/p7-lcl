unit P7LclEvents;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Controls,
  Forms,
  LCLType,
  StdCtrls;

type
  TP7Status = LongWord;
  TP7InvokeRootedCallback = function(Runtime: Pointer; Token: QWord): TP7Status; cdecl;
  TP7ReleaseRootedCallback = function(Runtime: Pointer; Token: QWord): TP7Status; cdecl;
  TP7CallbackValue = record
    Kind: LongWord;
    IntValue: Int64;
    FloatValue: Double;
    Bytes: PByte;
    Length: PtrUInt;
  end;
  PP7CallbackValue = ^TP7CallbackValue;
  TP7InvokeRootedCallbackValues = function(
    Runtime: Pointer;
    Token: QWord;
    Args: PP7CallbackValue;
    ArgCount: PtrUInt;
    Output: PP7CallbackValue
  ): TP7Status; cdecl;

  TP7Button = class(TButton)
  private
    FCallback: QWord;
    FCallbackRuntime: Pointer;
    FEnterCallback: QWord;
    FEnterRuntime: Pointer;
    FExitCallback: QWord;
    FExitRuntime: Pointer;
    FMouseDownCallback: QWord;
    FMouseDownRuntime: Pointer;
    procedure HandleClick(Sender: TObject);
    procedure HandleEnter(Sender: TObject);
    procedure HandleExit(Sender: TObject);
    procedure HandleMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  public
    procedure ClearAllCallbacks;
    procedure ClearCallback;
    procedure ClearEnterCallback;
    procedure ClearExitCallback;
    procedure ClearMouseDownCallback;
    procedure SetCallback(Runtime: Pointer; Token: QWord);
    procedure SetEnterCallback(Runtime: Pointer; Token: QWord);
    procedure SetExitCallback(Runtime: Pointer; Token: QWord);
    procedure SetMouseDownCallback(Runtime: Pointer; Token: QWord);
    procedure TriggerEnter;
    procedure TriggerExit;
    procedure TriggerMouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  end;

  TP7Edit = class(TEdit)
  private
    FCallback: QWord;
    FCallbackRuntime: Pointer;
    FKeyPressCallback: QWord;
    FKeyPressRuntime: Pointer;
    FKeyDownCallback: QWord;
    FKeyDownRuntime: Pointer;
    FUTF8KeyPressCallback: QWord;
    FUTF8KeyPressRuntime: Pointer;
    FEnterCallback: QWord;
    FEnterRuntime: Pointer;
    FExitCallback: QWord;
    FExitRuntime: Pointer;
    procedure HandleChange(Sender: TObject);
    procedure HandleEnter(Sender: TObject);
    procedure HandleExit(Sender: TObject);
    procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleKeyPress(Sender: TObject; var Key: Char);
    procedure HandleUTF8KeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
  public
    procedure ClearAllCallbacks;
    procedure ClearCallback;
    procedure ClearEnterCallback;
    procedure ClearExitCallback;
    procedure ClearKeyDownCallback;
    procedure ClearKeyPressCallback;
    procedure ClearUTF8KeyPressCallback;
    procedure SetCallback(Runtime: Pointer; Token: QWord);
    procedure SetEnterCallback(Runtime: Pointer; Token: QWord);
    procedure SetExitCallback(Runtime: Pointer; Token: QWord);
    procedure SetKeyDownCallback(Runtime: Pointer; Token: QWord);
    procedure SetKeyPressCallback(Runtime: Pointer; Token: QWord);
    procedure SetUTF8KeyPressCallback(Runtime: Pointer; Token: QWord);
    procedure TriggerEnter;
    procedure TriggerExit;
    procedure TriggerKeyDown(var Key: Word; Shift: TShiftState);
    procedure TriggerKeyPress(var Key: Char);
    procedure TriggerUTF8KeyPress(var UTF8Key: TUTF8Char);
  end;

procedure ConfigureCallbacks(
  InvokeCallback: TP7InvokeRootedCallback;
  ReleaseCallback: TP7ReleaseRootedCallback;
  InvokeCallbackValues: TP7InvokeRootedCallbackValues
);
function ConsumeCallbackError: String;
function EventCallbackActive: Boolean;
procedure InvokeVoidEvent(Runtime: Pointer; Token: QWord);
procedure QueueVoidEvent(Runtime: Pointer; Token: QWord);
procedure QueueObjectFree(Instance: TObject);
function InvokeNoArgIntEvent(Runtime: Pointer; Token: QWord; out Value: Int64): Boolean;
function InvokeIntEvent(Runtime: Pointer; Token: QWord; Input: Int64; out Value: Int64): Boolean;
procedure ReleaseEvent(Runtime: Pointer; var Token: QWord);

implementation

uses
  P7LclObjects,
  SysUtils;

const
  P7_STATUS_OK = 0;
  P7_STATUS_TYPE_MISMATCH = 3;
  P7_CALLBACK_UNIT = 0;
  P7_CALLBACK_INT = 1;
  P7_CALLBACK_STRING = 4;
  P7_CALLBACK_FOREIGN = 5;

var
  InvokeRootedCallback: TP7InvokeRootedCallback;
  ReleaseRootedCallback: TP7ReleaseRootedCallback;
  InvokeRootedCallbackValues: TP7InvokeRootedCallbackValues;
  CallbackError: String;
  CallbackDepth: Integer;

type
  TP7QueuedEvent = class
  private
    FRuntime: Pointer;
    FToken: QWord;
    procedure ExecuteQueued(Data: PtrInt);
  public
    constructor Create(Runtime: Pointer; Token: QWord);
  end;

  TP7QueuedObjectFree = class
  private
    FInstance: TObject;
    procedure ExecuteQueued(Data: PtrInt);
  public
    constructor Create(Instance: TObject);
  end;

procedure ConfigureCallbacks(
  InvokeCallback: TP7InvokeRootedCallback;
  ReleaseCallback: TP7ReleaseRootedCallback;
  InvokeCallbackValues: TP7InvokeRootedCallbackValues
);
begin
  InvokeRootedCallback := InvokeCallback;
  ReleaseRootedCallback := ReleaseCallback;
  InvokeRootedCallbackValues := InvokeCallbackValues;
end;

procedure SetCallbackError(Status: TP7Status);
begin
  CallbackError := Format('Protosept event callback failed with status %d', [Status]);
  Application.Terminate;
end;

function ShiftStateBits(Shift: TShiftState): Int64;
var
  Item: TShiftStateEnum;
begin
  Result := 0;
  for Item in Shift do
    Result := Result or (Int64(1) shl Ord(Item));
end;

procedure SetIntArgument(var Argument: TP7CallbackValue; Value: Int64);
begin
  FillChar(Argument, SizeOf(Argument), 0);
  Argument.Kind := P7_CALLBACK_INT;
  Argument.IntValue := Value;
end;

procedure SetStringArgument(var Argument: TP7CallbackValue; const Value: UTF8String);
begin
  FillChar(Argument, SizeOf(Argument), 0);
  Argument.Kind := P7_CALLBACK_STRING;
  Argument.Bytes := PByte(PAnsiChar(Value));
  Argument.Length := Length(Value);
end;

function SetForeignArgument(var Argument: TP7CallbackValue; Instance: TObject;
  out TypeTag: UTF8String): Boolean;
var
  Handle: Int64;
begin
  FillChar(Argument, SizeOf(Argument), 0);
  Result := FindObjectHandle(Instance, Handle, TypeTag);
  if not Result then
  begin
    SetCallbackError(P7_STATUS_TYPE_MISMATCH);
    Exit;
  end;
  Argument.Kind := P7_CALLBACK_FOREIGN;
  Argument.IntValue := Handle;
  Argument.Bytes := PByte(PAnsiChar(TypeTag));
  Argument.Length := Length(TypeTag);
end;

function InvokeEventValues(Runtime: Pointer; Token: QWord;
  Args: PP7CallbackValue; ArgCount: PtrUInt; ExpectedKind: LongWord;
  out Output: TP7CallbackValue): Boolean;
var
  Status: TP7Status;
begin
  FillChar(Output, SizeOf(Output), 0);
  if (Token = 0) or not Assigned(InvokeRootedCallbackValues) then
    Exit(False);
  Inc(CallbackDepth);
  try
    Status := InvokeRootedCallbackValues(Runtime, Token, Args, ArgCount, @Output);
  finally
    Dec(CallbackDepth);
  end;
  Result := (Status = P7_STATUS_OK) and (Output.Kind = ExpectedKind);
  if not Result then
  begin
    if Status = P7_STATUS_OK then
      Status := P7_STATUS_TYPE_MISMATCH;
    SetCallbackError(Status);
  end;
end;

procedure InvokeVoidEvent(Runtime: Pointer; Token: QWord);
var
  Status: TP7Status;
begin
  if (Token = 0) or not Assigned(InvokeRootedCallback) then
    Exit;
  Inc(CallbackDepth);
  try
    Status := InvokeRootedCallback(Runtime, Token);
  finally
    Dec(CallbackDepth);
  end;
  if Status <> P7_STATUS_OK then
    SetCallbackError(Status);
end;

constructor TP7QueuedObjectFree.Create(Instance: TObject);
begin
  inherited Create;
  FInstance := Instance;
end;

procedure TP7QueuedObjectFree.ExecuteQueued(Data: PtrInt);
begin
  try
    FInstance.Free;
  finally
    Free;
  end;
end;

procedure QueueObjectFree(Instance: TObject);
var
  QueuedFree: TP7QueuedObjectFree;
begin
  QueuedFree := TP7QueuedObjectFree.Create(Instance);
  try
    Application.QueueAsyncCall(@QueuedFree.ExecuteQueued, 0);
  except
    QueuedFree.Free;
    raise;
  end;
end;

constructor TP7QueuedEvent.Create(Runtime: Pointer; Token: QWord);
begin
  inherited Create;
  FRuntime := Runtime;
  FToken := Token;
end;

procedure TP7QueuedEvent.ExecuteQueued(Data: PtrInt);
begin
  try
    InvokeVoidEvent(FRuntime, FToken);
  finally
    ReleaseEvent(FRuntime, FToken);
    Free;
  end;
end;

procedure QueueVoidEvent(Runtime: Pointer; Token: QWord);
var
  QueuedEvent: TP7QueuedEvent;
begin
  QueuedEvent := TP7QueuedEvent.Create(Runtime, Token);
  try
    Application.QueueAsyncCall(@QueuedEvent.ExecuteQueued, 0);
  except
    QueuedEvent.Free;
    raise;
  end;
end;

function InvokeNoArgIntEvent(Runtime: Pointer; Token: QWord; out Value: Int64): Boolean;
var
  Output: TP7CallbackValue;
begin
  Result := InvokeEventValues(Runtime, Token, nil, 0, P7_CALLBACK_INT, Output);
  if Result then
    Value := Output.IntValue;
end;

function InvokeIntEvent(Runtime: Pointer; Token: QWord; Input: Int64; out Value: Int64): Boolean;
var
  Argument, Output: TP7CallbackValue;
begin
  SetIntArgument(Argument, Input);
  Result := InvokeEventValues(Runtime, Token, @Argument, 1, P7_CALLBACK_INT, Output);
  if Result then
    Value := Output.IntValue;
end;

procedure ReleaseEvent(Runtime: Pointer; var Token: QWord);
begin
  if (Token <> 0) and Assigned(ReleaseRootedCallback) then
    ReleaseRootedCallback(Runtime, Token);
  Token := 0;
end;

function ConsumeCallbackError: String;
begin
  Result := CallbackError;
  CallbackError := '';
end;

function EventCallbackActive: Boolean;
begin
  Result := CallbackDepth <> 0;
end;

procedure TP7Button.HandleClick(Sender: TObject);
begin
  InvokeVoidEvent(FCallbackRuntime, FCallback);
end;

procedure TP7Button.HandleEnter(Sender: TObject);
var
  Arguments: array[0..0] of TP7CallbackValue;
  Output: TP7CallbackValue;
  TypeTag: UTF8String;
begin
  if SetForeignArgument(Arguments[0], Self, TypeTag) then
    InvokeEventValues(FEnterRuntime, FEnterCallback, @Arguments[0], 1,
      P7_CALLBACK_UNIT, Output);
end;

procedure TP7Button.HandleExit(Sender: TObject);
var
  Arguments: array[0..0] of TP7CallbackValue;
  Output: TP7CallbackValue;
  TypeTag: UTF8String;
begin
  if SetForeignArgument(Arguments[0], Self, TypeTag) then
    InvokeEventValues(FExitRuntime, FExitCallback, @Arguments[0], 1,
      P7_CALLBACK_UNIT, Output);
end;

procedure TP7Button.HandleMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Arguments: array[0..4] of TP7CallbackValue;
  Output: TP7CallbackValue;
  TypeTag: UTF8String;
begin
  if not SetForeignArgument(Arguments[0], Self, TypeTag) then
    Exit;
  SetIntArgument(Arguments[1], Ord(Button));
  SetIntArgument(Arguments[2], ShiftStateBits(Shift));
  SetIntArgument(Arguments[3], X);
  SetIntArgument(Arguments[4], Y);
  InvokeEventValues(FMouseDownRuntime, FMouseDownCallback, @Arguments[0], 5,
    P7_CALLBACK_UNIT, Output);
end;

procedure TP7Button.ClearAllCallbacks;
begin
  ClearCallback;
  ClearEnterCallback;
  ClearExitCallback;
  ClearMouseDownCallback;
end;

procedure TP7Button.ClearCallback;
begin
  OnClick := nil;
  ReleaseEvent(FCallbackRuntime, FCallback);
  FCallbackRuntime := nil;
end;

procedure TP7Button.ClearEnterCallback;
begin
  OnEnter := nil;
  ReleaseEvent(FEnterRuntime, FEnterCallback);
  FEnterRuntime := nil;
end;

procedure TP7Button.ClearExitCallback;
begin
  OnExit := nil;
  ReleaseEvent(FExitRuntime, FExitCallback);
  FExitRuntime := nil;
end;

procedure TP7Button.ClearMouseDownCallback;
begin
  OnMouseDown := nil;
  ReleaseEvent(FMouseDownRuntime, FMouseDownCallback);
  FMouseDownRuntime := nil;
end;

procedure TP7Button.SetCallback(Runtime: Pointer; Token: QWord);
begin
  ClearCallback;
  FCallbackRuntime := Runtime;
  FCallback := Token;
  OnClick := @HandleClick;
end;

procedure TP7Button.SetEnterCallback(Runtime: Pointer; Token: QWord);
begin
  ClearEnterCallback;
  FEnterRuntime := Runtime;
  FEnterCallback := Token;
  OnEnter := @HandleEnter;
end;

procedure TP7Button.SetExitCallback(Runtime: Pointer; Token: QWord);
begin
  ClearExitCallback;
  FExitRuntime := Runtime;
  FExitCallback := Token;
  OnExit := @HandleExit;
end;

procedure TP7Button.SetMouseDownCallback(Runtime: Pointer; Token: QWord);
begin
  ClearMouseDownCallback;
  FMouseDownRuntime := Runtime;
  FMouseDownCallback := Token;
  OnMouseDown := @HandleMouseDown;
end;

procedure TP7Button.TriggerEnter;
begin
  DoEnter;
end;

procedure TP7Button.TriggerExit;
begin
  DoExit;
end;

procedure TP7Button.TriggerMouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  MouseDown(Button, Shift, X, Y);
end;

procedure TP7Edit.HandleChange(Sender: TObject);
begin
  InvokeVoidEvent(FCallbackRuntime, FCallback);
end;

procedure TP7Edit.HandleEnter(Sender: TObject);
var
  Arguments: array[0..0] of TP7CallbackValue;
  Output: TP7CallbackValue;
  TypeTag: UTF8String;
begin
  if SetForeignArgument(Arguments[0], Self, TypeTag) then
    InvokeEventValues(FEnterRuntime, FEnterCallback, @Arguments[0], 1,
      P7_CALLBACK_UNIT, Output);
end;

procedure TP7Edit.HandleExit(Sender: TObject);
var
  Arguments: array[0..0] of TP7CallbackValue;
  Output: TP7CallbackValue;
  TypeTag: UTF8String;
begin
  if SetForeignArgument(Arguments[0], Self, TypeTag) then
    InvokeEventValues(FExitRuntime, FExitCallback, @Arguments[0], 1,
      P7_CALLBACK_UNIT, Output);
end;

procedure TP7Edit.HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Arguments: array[0..2] of TP7CallbackValue;
  Output: TP7CallbackValue;
  TypeTag: UTF8String;
begin
  if not SetForeignArgument(Arguments[0], Self, TypeTag) then
    Exit;
  SetIntArgument(Arguments[1], Key);
  SetIntArgument(Arguments[2], ShiftStateBits(Shift));
  if InvokeEventValues(FKeyDownRuntime, FKeyDownCallback, @Arguments[0], 3,
    P7_CALLBACK_INT, Output) then
    if (Output.IntValue < 0) or (Output.IntValue > High(Word)) then
      Key := 0
    else
      Key := Word(Output.IntValue);
end;

procedure TP7Edit.ClearCallback;
begin
  OnChange := nil;
  ReleaseEvent(FCallbackRuntime, FCallback);
  FCallbackRuntime := nil;
end;

procedure TP7Edit.ClearAllCallbacks;
begin
  ClearCallback;
  ClearEnterCallback;
  ClearExitCallback;
  ClearKeyDownCallback;
  ClearKeyPressCallback;
  ClearUTF8KeyPressCallback;
end;

procedure TP7Edit.ClearEnterCallback;
begin
  OnEnter := nil;
  ReleaseEvent(FEnterRuntime, FEnterCallback);
  FEnterRuntime := nil;
end;

procedure TP7Edit.ClearExitCallback;
begin
  OnExit := nil;
  ReleaseEvent(FExitRuntime, FExitCallback);
  FExitRuntime := nil;
end;

procedure TP7Edit.ClearKeyDownCallback;
begin
  OnKeyDown := nil;
  ReleaseEvent(FKeyDownRuntime, FKeyDownCallback);
  FKeyDownRuntime := nil;
end;

procedure TP7Edit.HandleKeyPress(Sender: TObject; var Key: Char);
var
  UpdatedValue: Int64;
begin
  if (FKeyPressCallback <> 0) and
     InvokeIntEvent(FKeyPressRuntime, FKeyPressCallback, Ord(Key), UpdatedValue) then
  begin
    if (UpdatedValue < 0) or (UpdatedValue > High(Byte)) then
      Key := #0
    else
      Key := Char(UpdatedValue);
  end;
end;

procedure TP7Edit.HandleUTF8KeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
var
  Arguments: array[0..1] of TP7CallbackValue;
  Output: TP7CallbackValue;
  TypeTag, EncodedKey: UTF8String;
begin
  if not SetForeignArgument(Arguments[0], Self, TypeTag) then
    Exit;
  EncodedKey := UTF8String(UTF8Key);
  SetStringArgument(Arguments[1], EncodedKey);
  InvokeEventValues(FUTF8KeyPressRuntime, FUTF8KeyPressCallback, @Arguments[0], 2,
    P7_CALLBACK_UNIT, Output);
end;

procedure TP7Edit.ClearKeyPressCallback;
begin
  OnKeyPress := nil;
  ReleaseEvent(FKeyPressRuntime, FKeyPressCallback);
  FKeyPressRuntime := nil;
end;

procedure TP7Edit.ClearUTF8KeyPressCallback;
begin
  OnUTF8KeyPress := nil;
  ReleaseEvent(FUTF8KeyPressRuntime, FUTF8KeyPressCallback);
  FUTF8KeyPressRuntime := nil;
end;

procedure TP7Edit.SetKeyPressCallback(Runtime: Pointer; Token: QWord);
begin
  ClearKeyPressCallback;
  FKeyPressRuntime := Runtime;
  FKeyPressCallback := Token;
  OnKeyPress := @HandleKeyPress;
end;

procedure TP7Edit.SetEnterCallback(Runtime: Pointer; Token: QWord);
begin
  ClearEnterCallback;
  FEnterRuntime := Runtime;
  FEnterCallback := Token;
  OnEnter := @HandleEnter;
end;

procedure TP7Edit.SetExitCallback(Runtime: Pointer; Token: QWord);
begin
  ClearExitCallback;
  FExitRuntime := Runtime;
  FExitCallback := Token;
  OnExit := @HandleExit;
end;

procedure TP7Edit.SetKeyDownCallback(Runtime: Pointer; Token: QWord);
begin
  ClearKeyDownCallback;
  FKeyDownRuntime := Runtime;
  FKeyDownCallback := Token;
  OnKeyDown := @HandleKeyDown;
end;

procedure TP7Edit.SetUTF8KeyPressCallback(Runtime: Pointer; Token: QWord);
begin
  ClearUTF8KeyPressCallback;
  FUTF8KeyPressRuntime := Runtime;
  FUTF8KeyPressCallback := Token;
  OnUTF8KeyPress := @HandleUTF8KeyPress;
end;

procedure TP7Edit.TriggerEnter;
begin
  DoEnter;
end;

procedure TP7Edit.TriggerExit;
begin
  DoExit;
end;

procedure TP7Edit.TriggerKeyDown(var Key: Word; Shift: TShiftState);
begin
  KeyDown(Key, Shift);
end;

procedure TP7Edit.TriggerKeyPress(var Key: Char);
begin
  KeyPress(Key);
end;

procedure TP7Edit.TriggerUTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  UTF8KeyPress(UTF8Key);
end;

procedure TP7Edit.SetCallback(Runtime: Pointer; Token: QWord);
begin
  ClearCallback;
  FCallbackRuntime := Runtime;
  FCallback := Token;
  OnChange := @HandleChange;
end;

end.
