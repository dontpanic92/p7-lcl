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
    procedure HandleChange(Sender: TObject);
  public
    procedure ClearCallback;
    procedure SetCallback(Runtime: Pointer; Token: QWord);
  end;

procedure ConfigureCallbacks(
  InvokeCallback: TP7InvokeRootedCallback;
  ReleaseCallback: TP7ReleaseRootedCallback
);
function ConsumeCallbackError: String;

implementation

uses
  SysUtils;

const
  P7_STATUS_OK = 0;

var
  InvokeRootedCallback: TP7InvokeRootedCallback;
  ReleaseRootedCallback: TP7ReleaseRootedCallback;
  CallbackError: String;

procedure ConfigureCallbacks(
  InvokeCallback: TP7InvokeRootedCallback;
  ReleaseCallback: TP7ReleaseRootedCallback
);
begin
  InvokeRootedCallback := InvokeCallback;
  ReleaseRootedCallback := ReleaseCallback;
end;

procedure InvokeEvent(Runtime: Pointer; Token: QWord);
var
  Status: TP7Status;
begin
  if (Token = 0) or not Assigned(InvokeRootedCallback) then
    Exit;
  Status := InvokeRootedCallback(Runtime, Token);
  if Status <> P7_STATUS_OK then
  begin
    CallbackError := Format('Protosept event callback failed with status %d', [Status]);
    Application.Terminate;
  end;
end;

procedure Release(Runtime: Pointer; var Token: QWord);
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

procedure TP7Button.HandleClick(Sender: TObject);
begin
  InvokeEvent(FCallbackRuntime, FCallback);
end;

procedure TP7Button.ClearCallback;
begin
  OnClick := nil;
  Release(FCallbackRuntime, FCallback);
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
  InvokeEvent(FCallbackRuntime, FCallback);
end;

procedure TP7Edit.ClearCallback;
begin
  OnChange := nil;
  Release(FCallbackRuntime, FCallback);
  FCallbackRuntime := nil;
end;

procedure TP7Edit.SetCallback(Runtime: Pointer; Token: QWord);
begin
  ClearCallback;
  FCallbackRuntime := Runtime;
  FCallback := Token;
  OnChange := @HandleChange;
end;

end.
