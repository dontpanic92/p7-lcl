unit P7LclEvents;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Forms,
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
    procedure HandleClick(Sender: TObject);
  public
    procedure ClearCallback;
    procedure SetCallback(Runtime: Pointer; Token: QWord);
  end;

  TP7Edit = class(TEdit)
  private
    FCallback: QWord;
    FCallbackRuntime: Pointer;
    FKeyPressCallback: QWord;
    FKeyPressRuntime: Pointer;
    procedure HandleChange(Sender: TObject);
    procedure HandleKeyPress(Sender: TObject; var Key: Char);
  public
    procedure ClearCallback;
    procedure ClearKeyPressCallback;
    procedure SetCallback(Runtime: Pointer; Token: QWord);
    procedure SetKeyPressCallback(Runtime: Pointer; Token: QWord);
    procedure TriggerKeyPress(var Key: Char);
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
  SysUtils;

const
  P7_STATUS_OK = 0;
  P7_CALLBACK_INT = 1;

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
  Status: TP7Status;
begin
  FillChar(Output, SizeOf(Output), 0);
  if not Assigned(InvokeRootedCallbackValues) then
  begin
    SetCallbackError(1);
    Exit(False);
  end;
  Inc(CallbackDepth);
  try
    Status := InvokeRootedCallbackValues(Runtime, Token, nil, 0, @Output);
  finally
    Dec(CallbackDepth);
  end;
  Result := (Status = P7_STATUS_OK) and (Output.Kind = P7_CALLBACK_INT);
  if Result then
    Value := Output.IntValue
  else
    SetCallbackError(Status);
end;

function InvokeIntEvent(Runtime: Pointer; Token: QWord; Input: Int64; out Value: Int64): Boolean;
var
  Argument, Output: TP7CallbackValue;
  Status: TP7Status;
begin
  FillChar(Argument, SizeOf(Argument), 0);
  FillChar(Output, SizeOf(Output), 0);
  if not Assigned(InvokeRootedCallbackValues) then
  begin
    SetCallbackError(1);
    Exit(False);
  end;
  Argument.Kind := P7_CALLBACK_INT;
  Argument.IntValue := Input;
  Inc(CallbackDepth);
  try
    Status := InvokeRootedCallbackValues(Runtime, Token, @Argument, 1, @Output);
  finally
    Dec(CallbackDepth);
  end;
  Result := (Status = P7_STATUS_OK) and (Output.Kind = P7_CALLBACK_INT);
  if Result then
    Value := Output.IntValue
  else
    SetCallbackError(Status);
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

procedure TP7Button.ClearCallback;
begin
  OnClick := nil;
  ReleaseEvent(FCallbackRuntime, FCallback);
  FCallbackRuntime := nil;
end;

procedure TP7Button.SetCallback(Runtime: Pointer; Token: QWord);
begin
  ClearCallback;
  FCallbackRuntime := Runtime;
  FCallback := Token;
  OnClick := @HandleClick;
end;

procedure TP7Edit.HandleChange(Sender: TObject);
begin
  InvokeVoidEvent(FCallbackRuntime, FCallback);
end;

procedure TP7Edit.ClearCallback;
begin
  OnChange := nil;
  ReleaseEvent(FCallbackRuntime, FCallback);
  FCallbackRuntime := nil;
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

procedure TP7Edit.ClearKeyPressCallback;
begin
  OnKeyPress := nil;
  ReleaseEvent(FKeyPressRuntime, FKeyPressCallback);
  FKeyPressRuntime := nil;
end;

procedure TP7Edit.SetKeyPressCallback(Runtime: Pointer; Token: QWord);
begin
  ClearKeyPressCallback;
  FKeyPressRuntime := Runtime;
  FKeyPressCallback := Token;
  OnKeyPress := @HandleKeyPress;
end;

procedure TP7Edit.TriggerKeyPress(var Key: Char);
begin
  KeyPress(Key);
end;

procedure TP7Edit.SetCallback(Runtime: Pointer; Token: QWord);
begin
  ClearCallback;
  FCallbackRuntime := Runtime;
  FCallback := Token;
  OnChange := @HandleChange;
end;

end.
