unit P7LclPlatform;

{$mode objfpc}{$H+}

interface

procedure PrepareWidgetSetShutdown;

implementation

{$IFDEF LCLGTK3}
uses
  InterfaceBase,
  LazGdk3,
  LazGLib2,
  LazGtk3;

var
  OriginalGtkPollFunction: TGPollFunc;
{$ENDIF}

procedure PrepareWidgetSetShutdown;
begin
  {$IFDEF LCLGTK3}
  if Assigned(WidgetSet) then
    while g_source_remove_by_user_data(WidgetSet) do
      ;
  g_main_context_set_poll_func(
    g_main_context_default,
    OriginalGtkPollFunction
  );
  gdk_event_handler_set(TGdkEventFunc(@gtk_main_do_event), nil, nil);
  {$ENDIF}
end;

{$IFDEF LCLGTK3}
initialization
  OriginalGtkPollFunction :=
    g_main_context_get_poll_func(g_main_context_default);
{$ENDIF}

end.
