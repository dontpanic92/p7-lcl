unit P7LclPlatform;

{$mode objfpc}{$H+}

interface

procedure PrepareWidgetSetShutdown;

implementation

{$IFDEF LCLGTK3}
uses
  LazGdk3,
  LazGLib2;

var
  OriginalGtkPollFunction: TGPollFunc;
{$ENDIF}

procedure PrepareWidgetSetShutdown;
begin
  {$IFDEF LCLGTK3}
  g_main_context_set_poll_func(
    g_main_context_default,
    OriginalGtkPollFunction
  );
  gdk_event_handler_set(nil, nil, nil);
  {$ENDIF}
end;

{$IFDEF LCLGTK3}
initialization
  OriginalGtkPollFunction :=
    g_main_context_get_poll_func(g_main_context_default);
{$ENDIF}

end.
