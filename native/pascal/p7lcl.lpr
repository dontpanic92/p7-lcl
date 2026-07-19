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
  P7LclPlatform,
  Interfaces,
  InterfaceBase,
  Forms,
  CustApp,
  Controls,
  LCLType,
  Graphics,
  StdCtrls,
  ExtCtrls,
  ComCtrls,
  Dialogs,
  Menus,
  Classes,
  {$IFDEF LCLCOCOA}
  CocoaAll,
  CocoaInt,
  {$ENDIF}
  {$IFDEF LCLGTK3}
  Gtk3Int,
  {$ENDIF}
  {$IFDEF LCLWIN32}
  Win32Int,
  {$ENDIF}
  SysUtils,
  P7LclAbi,
  P7LclObjects,
  P7LclEvents;

const
  OBJECT_TYPE_TAG: PAnsiChar = 'lcl.TObject';
  COMPONENT_TYPE_TAG: PAnsiChar = 'lcl.TComponent';
  CONTROL_TYPE_TAG: PAnsiChar = 'lcl.TControl';
  WIN_CONTROL_TYPE_TAG: PAnsiChar = 'lcl.TWinControl';
  FORM_TYPE_TAG: PAnsiChar = 'lcl.TForm';
  BUTTON_TYPE_TAG: PAnsiChar = 'lcl.TButton';
  CHECKBOX_TYPE_TAG: PAnsiChar = 'lcl.TCheckBox';
  RADIO_BUTTON_TYPE_TAG: PAnsiChar = 'lcl.TRadioButton';
  LABEL_TYPE_TAG: PAnsiChar = 'lcl.TLabel';
  EDIT_TYPE_TAG: PAnsiChar = 'lcl.TEdit';
  MEMO_TYPE_TAG: PAnsiChar = 'lcl.TMemo';
  LIST_BOX_TYPE_TAG: PAnsiChar = 'lcl.TListBox';
  COMBO_BOX_TYPE_TAG: PAnsiChar = 'lcl.TComboBox';
  PANEL_TYPE_TAG: PAnsiChar = 'lcl.TPanel';
  IMAGE_TYPE_TAG: PAnsiChar = 'lcl.TImage';
  TIMER_TYPE_TAG: PAnsiChar = 'lcl.TTimer';
  MAIN_MENU_TYPE_TAG: PAnsiChar = 'lcl.TMainMenu';
  MENU_ITEM_TYPE_TAG: PAnsiChar = 'lcl.TMenuItem';
  TOOL_BAR_TYPE_TAG: PAnsiChar = 'lcl.TToolBar';
  TOOL_BUTTON_TYPE_TAG: PAnsiChar = 'lcl.TToolButton';
  STATUS_BAR_TYPE_TAG: PAnsiChar = 'lcl.TStatusBar';
  OPEN_DIALOG_TYPE_TAG: PAnsiChar = 'lcl.TOpenDialog';
  SAVE_DIALOG_TYPE_TAG: PAnsiChar = 'lcl.TSaveDialog';
  GROUP_BOX_TYPE_TAG: PAnsiChar = 'lcl.TGroupBox';

type
  TP7ExtensionState = (pesUninitialized, pesActive, pesShuttingDown, pesShutdown);

  TP7Form = class(TForm)
  private
    FCloseCallback: QWord;
    FCloseRuntime: Pointer;
    FCloseQueryCallback: QWord;
    FCloseQueryRuntime: Pointer;
    FShowCallback: QWord;
    FShowRuntime: Pointer;
    FHideCallback: QWord;
    FHideRuntime: Pointer;
    FActivateCallback: QWord;
    FActivateRuntime: Pointer;
    FDeactivateCallback: QWord;
    FDeactivateRuntime: Pointer;
    FResizeCallback: QWord;
    FResizeRuntime: Pointer;
    FHandlingClose: Boolean;
    procedure HandleActivate(Sender: TObject);
    procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure HandleCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure HandleDeactivate(Sender: TObject);
    procedure HandleHide(Sender: TObject);
    procedure HandleResize(Sender: TObject);
    procedure HandleShow(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClearActivateCallback;
    procedure ClearAllCallbacks;
    procedure ClearCloseCallback;
    procedure ClearCloseQueryCallback;
    procedure ClearDeactivateCallback;
    procedure ClearHideCallback;
    procedure ClearResizeCallback;
    procedure ClearShowCallback;
    function IsHandlingClose: Boolean;
    procedure SetActivateCallback(Runtime: Pointer; Token: QWord);
    procedure SetCloseCallback(Runtime: Pointer; Token: QWord);
    procedure SetCloseQueryCallback(Runtime: Pointer; Token: QWord);
    procedure SetDeactivateCallback(Runtime: Pointer; Token: QWord);
    procedure SetHideCallback(Runtime: Pointer; Token: QWord);
    procedure SetResizeCallback(Runtime: Pointer; Token: QWord);
    procedure SetShowCallback(Runtime: Pointer; Token: QWord);
  end;

var
  ApplicationInitialized: Boolean = False;
  ApplicationRunStarted: Boolean = False;
  ApplicationRunCompleted: Boolean = False;
  ApplicationTerminateRequested: Boolean = False;
  RegisteredMainForm: TP7Form = nil;
  ApplicationEvents: TP7ApplicationEvents = nil;
  ExtensionState: TP7ExtensionState = pesUninitialized;

constructor TP7Form.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  OnActivate := @HandleActivate;
  OnClose := @HandleClose;
  OnCloseQuery := @HandleCloseQuery;
  OnDeactivate := @HandleDeactivate;
  OnHide := @HandleHide;
  OnResize := @HandleResize;
  OnShow := @HandleShow;
end;

destructor TP7Form.Destroy;
begin
  if RegisteredMainForm = Self then
    RegisteredMainForm := nil;
  ClearAllCallbacks;
  inherited Destroy;
end;

procedure TP7Form.HandleActivate(Sender: TObject);
begin
  InvokeVoidEvent(FActivateRuntime, FActivateCallback);
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

procedure TP7Form.HandleDeactivate(Sender: TObject);
begin
  InvokeVoidEvent(FDeactivateRuntime, FDeactivateCallback);
end;

procedure TP7Form.HandleHide(Sender: TObject);
begin
  InvokeVoidEvent(FHideRuntime, FHideCallback);
end;

procedure TP7Form.HandleResize(Sender: TObject);
begin
  InvokeVoidEvent(FResizeRuntime, FResizeCallback);
end;

procedure TP7Form.HandleShow(Sender: TObject);
begin
  InvokeVoidEvent(FShowRuntime, FShowCallback);
end;

procedure TP7Form.ClearActivateCallback;
begin
  ReleaseEvent(FActivateRuntime, FActivateCallback);
  FActivateRuntime := nil;
end;

procedure TP7Form.ClearAllCallbacks;
begin
  ClearActivateCallback;
  ClearCloseCallback;
  ClearCloseQueryCallback;
  ClearDeactivateCallback;
  ClearHideCallback;
  ClearResizeCallback;
  ClearShowCallback;
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

procedure TP7Form.ClearDeactivateCallback;
begin
  ReleaseEvent(FDeactivateRuntime, FDeactivateCallback);
  FDeactivateRuntime := nil;
end;

procedure TP7Form.ClearHideCallback;
begin
  ReleaseEvent(FHideRuntime, FHideCallback);
  FHideRuntime := nil;
end;

procedure TP7Form.ClearResizeCallback;
begin
  ReleaseEvent(FResizeRuntime, FResizeCallback);
  FResizeRuntime := nil;
end;

procedure TP7Form.ClearShowCallback;
begin
  ReleaseEvent(FShowRuntime, FShowCallback);
  FShowRuntime := nil;
end;

procedure TP7Form.SetActivateCallback(Runtime: Pointer; Token: QWord);
begin
  ClearActivateCallback;
  FActivateRuntime := Runtime;
  FActivateCallback := Token;
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

procedure TP7Form.SetDeactivateCallback(Runtime: Pointer; Token: QWord);
begin
  ClearDeactivateCallback;
  FDeactivateRuntime := Runtime;
  FDeactivateCallback := Token;
end;

procedure TP7Form.SetHideCallback(Runtime: Pointer; Token: QWord);
begin
  ClearHideCallback;
  FHideRuntime := Runtime;
  FHideCallback := Token;
end;

procedure TP7Form.SetResizeCallback(Runtime: Pointer; Token: QWord);
begin
  ClearResizeCallback;
  FResizeRuntime := Runtime;
  FResizeCallback := Token;
end;

procedure TP7Form.SetShowCallback(Runtime: Pointer; Token: QWord);
begin
  ClearShowCallback;
  FShowRuntime := Runtime;
  FShowCallback := Token;
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
  if P7CallApiHasSetErrorDetails(Api) and Assigned(Api^.SetErrorDetails) then
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

procedure EnsureApplication;
begin
  if ApplicationInitialized then
  begin
    if ApplicationEvents = nil then
      ApplicationEvents := TP7ApplicationEvents.Create;
    Exit;
  end;
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.ShowMainForm := False;
  Application.Initialize;
  {$IFDEF LCLCOCOA}
  NSApplication.sharedApplication.setActivationPolicy(
    NSApplicationActivationPolicyRegular
  );
  {$ENDIF}
  ApplicationEvents := TP7ApplicationEvents.Create;
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

function ReadMouseButton(Api: PP7CallApi; Value: TP7Value;
  out Button: TMouseButton): TP7Status;
var
  Raw: Integer;
begin
  Result := ReadInt(Api, Value, Raw);
  if Result <> P7_STATUS_OK then
    Exit;
  if (Raw < Ord(Low(TMouseButton))) or (Raw > Ord(High(TMouseButton))) then
    Exit(ErrorStatus(Api, 'invalid mouse button value'));
  Button := TMouseButton(Raw);
end;

function ReadShiftState(Api: PP7CallApi; Value: TP7Value;
  out Shift: TShiftState): TP7Status;
var
  Raw: Integer;
begin
  Result := ReadInt(Api, Value, Raw);
  if Result <> P7_STATUS_OK then
    Exit;
  if (Raw < 0) or ((Raw and not $7F) <> 0) then
    Exit(ErrorStatus(Api, 'invalid shift-state bits'));
  Shift := [];
  if (Raw and (1 shl Ord(ssShift))) <> 0 then Include(Shift, ssShift);
  if (Raw and (1 shl Ord(ssAlt))) <> 0 then Include(Shift, ssAlt);
  if (Raw and (1 shl Ord(ssCtrl))) <> 0 then Include(Shift, ssCtrl);
  if (Raw and (1 shl Ord(ssLeft))) <> 0 then Include(Shift, ssLeft);
  if (Raw and (1 shl Ord(ssRight))) <> 0 then Include(Shift, ssRight);
  if (Raw and (1 shl Ord(ssMiddle))) <> 0 then Include(Shift, ssMiddle);
  if (Raw and (1 shl Ord(ssDouble))) <> 0 then Include(Shift, ssDouble);
end;

function FinishSynchronousEvent(Api: PP7CallApi): TP7Status;
var
  CallbackError: String;
begin
  CallbackError := ConsumeCallbackError;
  if CallbackError = '' then
    Result := P7_STATUS_OK
  else
    Result := ErrorStatus(Api, CallbackError);
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
    TP7Button(Component).ClearAllCallbacks
  else if Component is TP7CheckBox then
    TP7CheckBox(Component).ClearChangeCallback
  else if Component is TP7RadioButton then
    TP7RadioButton(Component).ClearChangeCallback
  else if Component is TP7Memo then
    TP7Memo(Component).ClearChangeCallback
  else if Component is TP7ListBox then
    TP7ListBox(Component).ClearSelectionCallback
  else if Component is TP7ComboBox then
    TP7ComboBox(Component).ClearChangeCallback
  else if Component is TP7Timer then
    TP7Timer(Component).ClearTimerCallback
  else if Component is TP7MenuItem then
    TP7MenuItem(Component).ClearClickCallback
  else if Component is TP7ToolButton then
    TP7ToolButton(Component).ClearClickCallback
  else if Component is TP7Edit then
    TP7Edit(Component).ClearAllCallbacks;
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
    if ApplicationRunStarted or ApplicationRunCompleted then
      Exit(ErrorStatus(Api, 'application run cannot be restarted'));
    if ApplicationTerminateRequested then
      Exit(ErrorStatus(Api, 'application was terminated before run'));
    if RegisteredMainForm = nil then
      Exit(ErrorStatus(Api, 'application main form is not registered'));
    ApplicationRunStarted := True;
    RegisteredMainForm.Show;
    Application.Run;
    ApplicationRunStarted := False;
    ApplicationRunCompleted := True;
    CallbackError := ConsumeCallbackError;
    if CallbackError = '' then
      Result := P7_STATUS_OK
    else
      Result := ErrorStatus(Api, CallbackError);
  except
    on E: Exception do
    begin
      ApplicationRunStarted := False;
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
    end;
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

function ApplicationProcessMessagesBounded(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  MaxTurns, Turn: Integer;
  CallbackError: String;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    Result := ReadInt(Api, PP7ValueArray(Args)^[0], MaxTurns);
    if Result <> P7_STATUS_OK then Exit;
    if MaxTurns < 0 then
      Exit(ErrorStatus(Api, 'message-pump turn count must be non-negative'));
    for Turn := 1 to MaxTurns do
    begin
      Application.ProcessMessages;
      CallbackError := ConsumeCallbackError;
      if CallbackError <> '' then
        Exit(ErrorStatus(Api, CallbackError));
      if Application.Terminated then
        Break;
    end;
    if Application.Terminated and (MaxTurns > 0) then
      Result := Api^.MakeInt(Api, Turn, Output)
    else
      Result := Api^.MakeInt(Api, MaxTurns, Output);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function ApplicationRegisterMainForm(
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
    EnsureApplication;
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then Exit;
    if ApplicationRunStarted or ApplicationRunCompleted then
      Exit(ErrorStatus(Api, 'application main form cannot change after run starts'));
    RegisteredMainForm := TP7Form(Form);
    Result := P7_STATUS_OK;
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function ApplicationMainForm(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
begin
  try
    if (ArgCount <> 0) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    if RegisteredMainForm = nil then
      Exit(ErrorStatus(Api, 'application main form is not registered'));
    Result := MakeBorrowedObject(Api, RegisteredMainForm, FORM_TYPE_TAG, Output);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function ApplicationSetOnException(
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
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    Result := RetainEventCallback(Api, PP7ValueArray(Args)^[0], Token);
    if Result <> P7_STATUS_OK then Exit;
    ApplicationEvents.SetExceptionCallback(Api^.Runtime, Token);
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

function ApplicationClearOnException(
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
    ApplicationEvents.ClearExceptionCallback;
    Result := P7_STATUS_OK;
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function ApplicationRaiseException(
  Userdata: Pointer;
  Api: PP7CallApi;
  Args: PP7Value;
  ArgCount: PtrUInt;
  Output: PP7Value
): TP7Status; cdecl;
var
  MessageText: UTF8String;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    EnsureApplication;
    Result := ReadString(Api, PP7ValueArray(Args)^[0], MessageText);
    if Result <> P7_STATUS_OK then Exit;
    ApplicationEvents.TriggerException(String(MessageText));
    Result := FinishSynchronousEvent(Api);
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
    if ApplicationTerminateRequested then
      Exit(P7_STATUS_OK);
    ApplicationTerminateRequested := True;
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
  CallbackError: String;
begin
  try
    if (ArgCount <> 5) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadBounds(Api, PP7ValueArray(Args), ALeft, ATop, AWidth, AHeight);
    if Result <> P7_STATUS_OK then Exit;
    Form.SetBounds(ALeft, ATop, AWidth, AHeight);
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
  CallbackError: String;
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
    Form.ClearAllCallbacks;
    ClearComponentCallbacks(Form);
    if Form.IsHandlingClose then
    begin
      Form := TP7Form(DetachObject(Handle));
      Form.Release;
    end
    else if EventCallbackActive then
    begin
      Form := TP7Form(DetachObject(Handle));
      QueueObjectFree(Form);
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
    Result := Api^.GetInt(Api, PP7ValueArray(Args)^[0], @Handle);
    if Result <> P7_STATUS_OK then
      Exit;
    Instance := FindObjectOrNil(Handle, TP7Form);
    if Instance <> nil then
    begin
      TP7Form(Instance).ClearAllCallbacks;
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

function ButtonSendEnter(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG,
      TP7Button, Instance);
    if Result <> P7_STATUS_OK then
      Exit;
    TP7Button(Instance).TriggerEnter;
    Result := FinishSynchronousEvent(Api);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function ButtonSendExit(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG,
      TP7Button, Instance);
    if Result <> P7_STATUS_OK then
      Exit;
    TP7Button(Instance).TriggerExit;
    Result := FinishSynchronousEvent(Api);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function ButtonSendMouseDown(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
  Button: TMouseButton;
  Shift: TShiftState;
  X, Y: Integer;
begin
  try
    if (ArgCount <> 5) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], BUTTON_TYPE_TAG,
      TP7Button, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadMouseButton(Api, PP7ValueArray(Args)^[1], Button);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadShiftState(Api, PP7ValueArray(Args)^[2], Shift);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[3], X);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[4], Y);
    if Result <> P7_STATUS_OK then Exit;
    TP7Button(Instance).TriggerMouseDown(Button, Shift, X, Y);
    Result := FinishSynchronousEvent(Api);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function EditSendEnter(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG,
      TP7Edit, Instance);
    if Result <> P7_STATUS_OK then Exit;
    TP7Edit(Instance).TriggerEnter;
    Result := FinishSynchronousEvent(Api);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function EditSendExit(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG,
      TP7Edit, Instance);
    if Result <> P7_STATUS_OK then Exit;
    TP7Edit(Instance).TriggerExit;
    Result := FinishSynchronousEvent(Api);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function EditSendKeyDown(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
  KeyValue: Integer;
  Key: Word;
  Shift: TShiftState;
begin
  try
    if (ArgCount <> 3) or (Args = nil) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG,
      TP7Edit, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[1], KeyValue);
    if Result <> P7_STATUS_OK then Exit;
    if (KeyValue < 0) or (KeyValue > High(Word)) then
      Exit(ErrorStatus(Api, 'key code is outside the Word range'));
    Result := ReadShiftState(Api, PP7ValueArray(Args)^[2], Shift);
    if Result <> P7_STATUS_OK then Exit;
    Key := Word(KeyValue);
    TP7Edit(Instance).TriggerKeyDown(Key, Shift);
    Result := FinishSynchronousEvent(Api);
    if Result <> P7_STATUS_OK then Exit;
    Result := Api^.MakeInt(Api, Key, Output);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function EditSendUTF8KeyPress(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
  EncodedKey: UTF8String;
  Key: TUTF8Char;
begin
  try
    if (ArgCount <> 2) or (Args = nil) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], EDIT_TYPE_TAG,
      TP7Edit, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadString(Api, PP7ValueArray(Args)^[1], EncodedKey);
    if Result <> P7_STATUS_OK then Exit;
    Key := TUTF8Char(EncodedKey);
    TP7Edit(Instance).TriggerUTF8KeyPress(Key);
    Result := FinishSynchronousEvent(Api);
    if Result <> P7_STATUS_OK then Exit;
    EncodedKey := UTF8String(Key);
    Result := Api^.MakeString(Api, PByte(PAnsiChar(EncodedKey)),
      Length(EncodedKey), Output);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function CheckBoxClick(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], CHECKBOX_TYPE_TAG,
      TP7CheckBox, Instance);
    if Result <> P7_STATUS_OK then Exit;
    TP7CheckBox(Instance).TriggerClick;
    Result := FinishSynchronousEvent(Api);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function RadioButtonClick(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], RADIO_BUTTON_TYPE_TAG,
      TP7RadioButton, Instance);
    if Result <> P7_STATUS_OK then Exit;
    TP7RadioButton(Instance).TriggerClick;
    Result := FinishSynchronousEvent(Api);
  except
    on E: Exception do
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
  end;
end;

function CollectionItems(Instance: TObject): TStrings;
begin
  if Instance is TP7ListBox then
    Result := TP7ListBox(Instance).Items
  else if Instance is TP7ComboBox then
    Result := TP7ComboBox(Instance).Items
  else
    raise Exception.Create('control does not expose indexed string items');
end;

function CollectionItemCount(Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value; TypeTag: PAnsiChar;
  ExpectedClass: TClass): TP7Status;
var
  Instance: TObject;
begin
  if (ArgCount <> 1) or (Args = nil) or (Output = nil) then
    Exit(P7_STATUS_INVALID_ARGUMENT);
  Result := ReadObject(Api, PP7ValueArray(Args)^[0], TypeTag, ExpectedClass, Instance);
  if Result <> P7_STATUS_OK then Exit;
  Result := Api^.MakeInt(Api, CollectionItems(Instance).Count, Output);
end;

function CollectionItem(Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value; TypeTag: PAnsiChar;
  ExpectedClass: TClass): TP7Status;
var
  Instance: TObject;
  Index: Integer;
  Value: UTF8String;
  Items: TStrings;
begin
  if (ArgCount <> 2) or (Args = nil) or (Output = nil) then
    Exit(P7_STATUS_INVALID_ARGUMENT);
  Result := ReadObject(Api, PP7ValueArray(Args)^[0], TypeTag, ExpectedClass, Instance);
  if Result <> P7_STATUS_OK then Exit;
  Result := ReadInt(Api, PP7ValueArray(Args)^[1], Index);
  if Result <> P7_STATUS_OK then Exit;
  Items := CollectionItems(Instance);
  if (Index < 0) or (Index >= Items.Count) then
    Exit(ErrorStatus(Api, 'item index is out of range'));
  Value := UTF8String(Items[Index]);
  Result := Api^.MakeString(Api, PByte(PAnsiChar(Value)), Length(Value), Output);
end;

function CollectionAddItem(Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value; TypeTag: PAnsiChar;
  ExpectedClass: TClass): TP7Status;
var
  Instance: TObject;
  Value: UTF8String;
  Index: Integer;
begin
  if (ArgCount <> 2) or (Args = nil) or (Output = nil) then
    Exit(P7_STATUS_INVALID_ARGUMENT);
  Result := ReadObject(Api, PP7ValueArray(Args)^[0], TypeTag, ExpectedClass, Instance);
  if Result <> P7_STATUS_OK then Exit;
  Result := ReadString(Api, PP7ValueArray(Args)^[1], Value);
  if Result <> P7_STATUS_OK then Exit;
  Index := CollectionItems(Instance).Add(String(Value));
  Result := Api^.MakeInt(Api, Index, Output);
end;

function CollectionSetItem(Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; TypeTag: PAnsiChar; ExpectedClass: TClass): TP7Status;
var
  Instance: TObject;
  Index: Integer;
  Value: UTF8String;
  Items: TStrings;
begin
  if (ArgCount <> 3) or (Args = nil) then
    Exit(P7_STATUS_INVALID_ARGUMENT);
  Result := ReadObject(Api, PP7ValueArray(Args)^[0], TypeTag, ExpectedClass, Instance);
  if Result <> P7_STATUS_OK then Exit;
  Result := ReadInt(Api, PP7ValueArray(Args)^[1], Index);
  if Result <> P7_STATUS_OK then Exit;
  Result := ReadString(Api, PP7ValueArray(Args)^[2], Value);
  if Result <> P7_STATUS_OK then Exit;
  Items := CollectionItems(Instance);
  if (Index < 0) or (Index >= Items.Count) then
    Exit(ErrorStatus(Api, 'item index is out of range'));
  Items[Index] := String(Value);
  Result := P7_STATUS_OK;
end;

function CollectionDeleteItem(Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; TypeTag: PAnsiChar; ExpectedClass: TClass): TP7Status;
var
  Instance: TObject;
  Index: Integer;
  Items: TStrings;
begin
  if (ArgCount <> 2) or (Args = nil) then
    Exit(P7_STATUS_INVALID_ARGUMENT);
  Result := ReadObject(Api, PP7ValueArray(Args)^[0], TypeTag, ExpectedClass, Instance);
  if Result <> P7_STATUS_OK then Exit;
  Result := ReadInt(Api, PP7ValueArray(Args)^[1], Index);
  if Result <> P7_STATUS_OK then Exit;
  Items := CollectionItems(Instance);
  if (Index < 0) or (Index >= Items.Count) then
    Exit(ErrorStatus(Api, 'item index is out of range'));
  Items.Delete(Index);
  Result := P7_STATUS_OK;
end;

function CollectionClearItems(Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; TypeTag: PAnsiChar; ExpectedClass: TClass): TP7Status;
var
  Instance: TObject;
begin
  if (ArgCount <> 1) or (Args = nil) then
    Exit(P7_STATUS_INVALID_ARGUMENT);
  Result := ReadObject(Api, PP7ValueArray(Args)^[0], TypeTag, ExpectedClass, Instance);
  if Result <> P7_STATUS_OK then Exit;
  CollectionItems(Instance).Clear;
  Result := P7_STATUS_OK;
end;

function MemoTriggerChange(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], MEMO_TYPE_TAG, TP7Memo, Instance);
    if Result <> P7_STATUS_OK then Exit;
    TP7Memo(Instance).TriggerChange;
    Result := FinishSynchronousEvent(Api);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ListBoxItemCount(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionItemCount(Api, Args, ArgCount, Output, LIST_BOX_TYPE_TAG, TP7ListBox); end;
function ListBoxItem(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionItem(Api, Args, ArgCount, Output, LIST_BOX_TYPE_TAG, TP7ListBox); end;
function ListBoxAddItem(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionAddItem(Api, Args, ArgCount, Output, LIST_BOX_TYPE_TAG, TP7ListBox); end;
function ListBoxSetItem(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionSetItem(Api, Args, ArgCount, LIST_BOX_TYPE_TAG, TP7ListBox); end;
function ListBoxDeleteItem(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionDeleteItem(Api, Args, ArgCount, LIST_BOX_TYPE_TAG, TP7ListBox); end;
function ListBoxClearItems(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionClearItems(Api, Args, ArgCount, LIST_BOX_TYPE_TAG, TP7ListBox); end;

function ListBoxItemIndex(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], LIST_BOX_TYPE_TAG, TP7ListBox, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := Api^.MakeInt(Api, TP7ListBox(Instance).ItemIndex, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ListBoxSelectIndex(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject; Index: Integer;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], LIST_BOX_TYPE_TAG, TP7ListBox, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[1], Index);
    if Result <> P7_STATUS_OK then Exit;
    if (Index < -1) or (Index >= TP7ListBox(Instance).Items.Count) then
      Exit(ErrorStatus(Api, 'item index is out of range'));
    TP7ListBox(Instance).SelectIndex(Index);
    Result := FinishSynchronousEvent(Api);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ComboBoxItemCount(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionItemCount(Api, Args, ArgCount, Output, COMBO_BOX_TYPE_TAG, TP7ComboBox); end;
function ComboBoxItem(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionItem(Api, Args, ArgCount, Output, COMBO_BOX_TYPE_TAG, TP7ComboBox); end;
function ComboBoxAddItem(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionAddItem(Api, Args, ArgCount, Output, COMBO_BOX_TYPE_TAG, TP7ComboBox); end;
function ComboBoxSetItem(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionSetItem(Api, Args, ArgCount, COMBO_BOX_TYPE_TAG, TP7ComboBox); end;
function ComboBoxDeleteItem(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionDeleteItem(Api, Args, ArgCount, COMBO_BOX_TYPE_TAG, TP7ComboBox); end;
function ComboBoxClearItems(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
begin Result := CollectionClearItems(Api, Args, ArgCount, COMBO_BOX_TYPE_TAG, TP7ComboBox); end;

function ComboBoxItemIndex(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], COMBO_BOX_TYPE_TAG, TP7ComboBox, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := Api^.MakeInt(Api, TP7ComboBox(Instance).ItemIndex, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ComboBoxSelectIndex(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject; Index: Integer;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], COMBO_BOX_TYPE_TAG, TP7ComboBox, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[1], Index);
    if Result <> P7_STATUS_OK then Exit;
    if (Index < -1) or (Index >= TP7ComboBox(Instance).Items.Count) then
      Exit(ErrorStatus(Api, 'item index is out of range'));
    TP7ComboBox(Instance).SelectIndex(Index);
    Result := FinishSynchronousEvent(Api);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ImageLoadFromFile(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Instance: TObject;
  FileName: UTF8String;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], IMAGE_TYPE_TAG, TImage, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadString(Api, PP7ValueArray(Args)^[1], FileName);
    if Result <> P7_STATUS_OK then Exit;
    TImage(Instance).Picture.LoadFromFile(String(FileName));
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ImageClear(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], IMAGE_TYPE_TAG, TImage, Instance);
    if Result <> P7_STATUS_OK then Exit;
    TImage(Instance).Picture.Clear;
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ImagePictureWidth(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], IMAGE_TYPE_TAG, TImage, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := Api^.MakeInt(Api, TImage(Instance).Picture.Width, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ImagePictureHeight(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], IMAGE_TYPE_TAG, TImage, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := Api^.MakeInt(Api, TImage(Instance).Picture.Height, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function TimerCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var
  Form: TForm;
  Timer: TP7Timer;
begin
  Timer := nil;
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then Exit;
    Timer := TP7Timer.Create(Form);
    Result := MakeHandleObject(Api, Timer, TIMER_TYPE_TAG, Output);
    if Result <> P7_STATUS_OK then Timer.Free;
  except
    on E: Exception do
    begin
      Timer.Free;
      Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message);
    end;
  end;
end;

function TimerSetInterval(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject; Interval: Integer;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], TIMER_TYPE_TAG, TP7Timer, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[1], Interval);
    if Result <> P7_STATUS_OK then Exit;
    if Interval <= 0 then Exit(ErrorStatus(Api, 'timer interval must be positive'));
    TP7Timer(Instance).Interval := Cardinal(Interval);
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function TimerInterval(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], TIMER_TYPE_TAG, TP7Timer, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := Api^.MakeInt(Api, TP7Timer(Instance).Interval, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function TimerTrigger(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], TIMER_TYPE_TAG, TP7Timer, Instance);
    if Result <> P7_STATUS_OK then Exit;
    TP7Timer(Instance).TriggerTimer;
    Result := FinishSynchronousEvent(Api);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function MainMenuCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Form: TForm; Menu: TMainMenu;
begin
  Menu := nil;
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then Exit;
    Menu := TMainMenu.Create(Form);
    Result := MakeHandleObject(Api, Menu, MAIN_MENU_TYPE_TAG, Output);
    if Result <> P7_STATUS_OK then Menu.Free;
  except on E: Exception do begin Menu.Free; Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end; end;
end;

function FormSetMainMenu(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Form: TForm; Instance: TObject;
begin
  try
    if (ArgCount <> 2) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadObject(Api, PP7ValueArray(Args)^[1], MAIN_MENU_TYPE_TAG, TMainMenu, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Form.Menu := TMainMenu(Instance);
    Result := P7_STATUS_OK;
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function MenuItemCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject; Item: TP7MenuItem;
begin
  Item := nil;
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], MAIN_MENU_TYPE_TAG, TMainMenu, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Item := TP7MenuItem.Create(TMainMenu(Instance));
    TMainMenu(Instance).Items.Add(Item);
    Result := MakeHandleObject(Api, Item, MENU_ITEM_TYPE_TAG, Output);
    if Result <> P7_STATUS_OK then Item.Free;
  except on E: Exception do begin Item.Free; Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end; end;
end;

function SubMenuItemCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject; Item: TP7MenuItem; Owner: TComponent;
begin
  Item := nil;
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], MENU_ITEM_TYPE_TAG, TP7MenuItem, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Owner := TComponent(Instance).Owner;
    Item := TP7MenuItem.Create(Owner);
    TP7MenuItem(Instance).Add(Item);
    Result := MakeHandleObject(Api, Item, MENU_ITEM_TYPE_TAG, Output);
    if Result <> P7_STATUS_OK then Item.Free;
  except on E: Exception do begin Item.Free; Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end; end;
end;

function MenuItemCount(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], MENU_ITEM_TYPE_TAG, TP7MenuItem, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := Api^.MakeInt(Api, TP7MenuItem(Instance).Count, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function MenuItemChild(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject; Index: Integer; Child: TMenuItem;
begin
  try
    if (ArgCount <> 2) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], MENU_ITEM_TYPE_TAG, TP7MenuItem, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := ReadInt(Api, PP7ValueArray(Args)^[1], Index);
    if Result <> P7_STATUS_OK then Exit;
    if (Index < 0) or (Index >= TP7MenuItem(Instance).Count) then
      Exit(ErrorStatus(Api, 'menu item index is out of range'));
    Child := TP7MenuItem(Instance).Items[Index];
    Result := MakeBorrowedObject(Api, Child, MENU_ITEM_TYPE_TAG, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function MenuItemClick(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], MENU_ITEM_TYPE_TAG, TP7MenuItem, Instance);
    if Result <> P7_STATUS_OK then Exit;
    TP7MenuItem(Instance).TriggerClick;
    Result := FinishSynchronousEvent(Api);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ToolButtonCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject; Button: TP7ToolButton;
begin
  Button := nil;
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], TOOL_BAR_TYPE_TAG, TToolBar, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Button := TP7ToolButton.Create(TToolBar(Instance));
    Button.Parent := TToolBar(Instance);
    Result := MakeHandleObject(Api, Button, TOOL_BUTTON_TYPE_TAG, Output);
    if Result <> P7_STATUS_OK then Button.Free;
  except on E: Exception do begin Button.Free; Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end; end;
end;

function ToolBarButtonCount(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], TOOL_BAR_TYPE_TAG, TToolBar, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := Api^.MakeInt(Api, TToolBar(Instance).ButtonCount, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function ToolButtonClick(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], TOOL_BUTTON_TYPE_TAG, TP7ToolButton, Instance);
    if Result <> P7_STATUS_OK then Exit;
    TP7ToolButton(Instance).TriggerClick;
    Result := FinishSynchronousEvent(Api);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function OpenDialogCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Form: TForm; Dialog: TOpenDialog;
begin
  Dialog := nil;
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then Exit;
    Dialog := TOpenDialog.Create(Form);
    Result := MakeHandleObject(Api, Dialog, OPEN_DIALOG_TYPE_TAG, Output);
    if Result <> P7_STATUS_OK then Dialog.Free;
  except on E: Exception do begin Dialog.Free; Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end; end;
end;

function SaveDialogCreate(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Form: TForm; Dialog: TSaveDialog;
begin
  Dialog := nil;
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadForm(Api, PP7ValueArray(Args)^[0], Form);
    if Result <> P7_STATUS_OK then Exit;
    Dialog := TSaveDialog.Create(Form);
    Result := MakeHandleObject(Api, Dialog, SAVE_DIALOG_TYPE_TAG, Output);
    if Result <> P7_STATUS_OK then Dialog.Free;
  except on E: Exception do begin Dialog.Free; Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end; end;
end;

function OpenDialogExecute(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], OPEN_DIALOG_TYPE_TAG, TOpenDialog, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := MakeBoolean(Api, TOpenDialog(Instance).Execute, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

function SaveDialogExecute(Userdata: Pointer; Api: PP7CallApi; Args: PP7Value;
  ArgCount: PtrUInt; Output: PP7Value): TP7Status; cdecl;
var Instance: TObject;
begin
  try
    if (ArgCount <> 1) or (Args = nil) or (Output = nil) then Exit(P7_STATUS_INVALID_ARGUMENT);
    Result := ReadObject(Api, PP7ValueArray(Args)^[0], SAVE_DIALOG_TYPE_TAG, TSaveDialog, Instance);
    if Result <> P7_STATUS_OK then Exit;
    Result := MakeBoolean(Api, TSaveDialog(Instance).Execute, Output);
  except on E: Exception do Result := ErrorStatus(Api, E.ClassName + ': ' + E.Message); end;
end;

{$I generated/callbacks.inc}

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

procedure PrepareLclRuntime;
begin
  if Application = nil then
  begin
    Application := TApplication.Create(nil);
    CustomApplication := Application;
  end;
  if WidgetSet = nil then
  begin
    {$IFDEF LCLCOCOA}
    CreateWidgetset(TCocoaWidgetSet);
    {$ENDIF}
    {$IFDEF LCLGTK3}
    CreateWidgetset(TGtk3WidgetSet);
    {$ENDIF}
    {$IFDEF LCLWIN32}
    CreateWidgetset(TWin32WidgetSet);
    {$ENDIF}
  end;
end;

procedure CleanupObjectForShutdown(Instance: TObject);
begin
  if Instance is TP7Timer then
    TP7Timer(Instance).Enabled := False;
  if Instance is TP7Form then
    TP7Form(Instance).ClearAllCallbacks;
  if Instance is TComponent then
    ClearComponentCallbacks(TComponent(Instance));
end;

function p7_extension_shutdown_v1(Api: PP7HostApi): TP7Status; cdecl;
begin
  if ExtensionState = pesShutdown then
    Exit(P7_STATUS_OK);
  if ExtensionState = pesShuttingDown then
    Exit(P7_STATUS_ERROR);
  if (Api = nil) or
     (Api^.AbiVersion <> P7_NATIVE_ABI_VERSION) or
     (Api^.StructSize < P7HostApiRequiredSize) then
    Exit(P7_STATUS_INVALID_ARGUMENT);

  ExtensionState := pesShuttingDown;
  Result := P7_STATUS_ERROR;
  try
    try
      if ApplicationRunStarted and (Application <> nil) then
        Application.Terminate;
      BeginEventShutdown;
      FreeAndNil(ApplicationEvents);
      ShutdownObjectTable(@CleanupObjectForShutdown);
      RegisteredMainForm := nil;
      {$IFNDEF LCLCOCOA}
      ApplicationInitialized := False;
      {$ENDIF}
      ApplicationRunStarted := False;
      ApplicationRunCompleted := False;
      ApplicationTerminateRequested := False;
      PrepareWidgetSetShutdown;
      ExtensionState := pesShutdown;
      Result := P7_STATUS_OK;
    except
      Result := P7_STATUS_ERROR;
    end;
  finally
    ConfigureObjectInvalidation(nil);
    FinishEventShutdown;
  end;
end;

function p7_extension_init_v1(Api: PP7HostApi): TP7Status; cdecl;
begin
  try
    P7AssertAbiLayout;
    if (Api = nil) or
       (Api^.AbiVersion <> P7_NATIVE_ABI_VERSION) or
       (Api^.StructSize < P7HostApiRequiredSize) then
      Exit(P7_STATUS_INVALID_ARGUMENT);
    if ExtensionState in [pesActive, pesShuttingDown] then
      Exit(P7_STATUS_ERROR);

    PrepareLclRuntime;
    PrepareObjectTable;
    ConfigureCallbacks(
      Api^.InvokeRootedCallback,
      Api^.ReleaseRootedCallback,
      Api^.InvokeRootedCallbackValues
    );
    ConfigureObjectInvalidation(Api^.InvalidateForeignHandle);
    Result := RegisterGeneratedFunctions(Api);
    if Result = P7_STATUS_OK then
      ExtensionState := pesActive;
  except
    Result := P7_STATUS_ERROR;
  end;
end;

exports
  {$IFDEF DARWIN}
  p7_extension_init_v1 name '_p7_extension_init_v1',
  p7_extension_shutdown_v1 name '_p7_extension_shutdown_v1';
  {$ELSE}
  p7_extension_init_v1 name 'p7_extension_init_v1',
  p7_extension_shutdown_v1 name 'p7_extension_shutdown_v1';
  {$ENDIF}

begin
end.
