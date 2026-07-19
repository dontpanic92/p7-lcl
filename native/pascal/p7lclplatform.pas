unit P7LclPlatform;

{$mode objfpc}{$H+}

interface

procedure PrepareWidgetSetRuntime;
procedure PrepareWidgetSetShutdown;

implementation

{$IFDEF LCLCOCOA}
uses
  {$IFNDEF DisableCWString}
  cwstring,
  {$ENDIF}
  CocoaInt,
  CocoaWSFactory,
  CustApp,
  Forms,
  InterfaceBase;

var
  RetainedApplication: TApplication;
{$ENDIF}

{$IF DEFINED(LCLGTK3) AND DEFINED(LINUX)}
uses
  SysUtils;

const
  LibDl = 'libdl.so.2';
  RtldNow = $00002;
  RtldNoDelete = $01000;

type
  PDlInfo = ^TDlInfo;
  TDlInfo = record
    FileName: PAnsiChar;
    BaseAddress: Pointer;
    SymbolName: PAnsiChar;
    SymbolAddress: Pointer;
  end;

function dladdr(Address: Pointer; Info: PDlInfo): LongInt; cdecl;
  external LibDl name 'dladdr';
function dlclose(Handle: Pointer): LongInt; cdecl;
  external LibDl name 'dlclose';
function dlerror: PAnsiChar; cdecl;
  external LibDl name 'dlerror';
function dlopen(FileName: PAnsiChar; Flags: LongInt): Pointer; cdecl;
  external LibDl name 'dlopen';

procedure MakeProcessResident;
var
  ErrorMessage: PAnsiChar;
  Handle: Pointer;
  Info: TDlInfo;
begin
  FillChar(Info, SizeOf(Info), 0);
  if (dladdr(@PrepareWidgetSetShutdown, @Info) = 0) or
     (Info.FileName = nil) then
    raise Exception.Create('cannot locate the p7-lcl shared library');

  Handle := dlopen(Info.FileName, RtldNow or RtldNoDelete);
  if Handle = nil then
  begin
    ErrorMessage := dlerror;
    if ErrorMessage = nil then
      raise Exception.Create('cannot retain the p7-lcl shared library');
    raise Exception.Create(
      'cannot retain the p7-lcl shared library: ' + String(ErrorMessage)
    );
  end;
  if dlclose(Handle) <> 0 then
    raise Exception.Create('cannot release the p7-lcl residency handle');
end;
{$ENDIF}

procedure PrepareWidgetSetRuntime;
begin
  {$IFDEF LCLCOCOA}
  if (Application = nil) and Assigned(RetainedApplication) then
  begin
    Application := RetainedApplication;
    CustomApplication := Application;
  end;
  {$ENDIF}
end;

procedure PrepareWidgetSetShutdown;
begin
  {$IFDEF LCLCOCOA}
  if Assigned(Application) then
  begin
    RetainedApplication := Application;
    Application := nil;
    CustomApplication := nil;
  end;
  {$ENDIF}
end;

{$IFDEF LCLCOCOA}
initialization
  CreateWidgetset(TCocoaWidgetSet);
{$ENDIF}

{$IF DEFINED(LCLGTK3) AND DEFINED(LINUX)}
initialization
  MakeProcessResident;
{$ENDIF}

end.
