unit P7LclObjects;

{$mode objfpc}{$H+}

interface

type
  TP7InvalidateRuntimeHandle = function(
    Runtime: Pointer;
    TypeTag: PByte;
    TypeTagLength: PtrUInt;
    Handle: Int64
  ): LongWord; cdecl;
  TP7ObjectCleanup = procedure(Instance: TObject);

procedure ConfigureObjectInvalidation(InvalidateHandle: TP7InvalidateRuntimeHandle);
procedure PrepareObjectTable;
function AddObject(Instance: TObject; Runtime: Pointer; const TypeTag: UTF8String): Int64;
function FindObject(Handle: Int64; ExpectedClass: TClass): TObject;
function FindObjectOrNil(Handle: Int64; ExpectedClass: TClass): TObject;
function FindObjectHandle(Instance: TObject; out Handle: Int64;
  out TypeTag: UTF8String): Boolean;
function DetachObject(Handle: Int64): TObject;
procedure ReleaseObject(Handle: Int64);
procedure ShutdownObjectTable(Cleanup: TP7ObjectCleanup);

implementation

uses
  Classes,
  SysUtils;

type
  TObjectSlotNotifier = class(TComponent)
  private
    FIndex: Integer;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AIndex: Integer);
  end;

  TObjectSlot = record
    Instance: TObject;
    Generation: LongWord;
    Runtime: Pointer;
    TypeTag: UTF8String;
    Notifier: TObjectSlotNotifier;
  end;

var
  ObjectSlots: array of TObjectSlot;
  InvalidateRuntimeHandle: TP7InvalidateRuntimeHandle;
  ObjectTableShuttingDown: Boolean;

procedure ConfigureObjectInvalidation(InvalidateHandle: TP7InvalidateRuntimeHandle);
begin
  InvalidateRuntimeHandle := InvalidateHandle;
end;

procedure PrepareObjectTable;
begin
  if Length(ObjectSlots) <> 0 then
    raise Exception.Create('LCL object table is not empty during initialization');
  ObjectTableShuttingDown := False;
end;

function EncodeHandle(Index, Generation: LongWord): Int64;
begin
  Result := Int64((QWord(Generation) shl 32) or QWord(Index + 1));
end;

function DecodeHandle(Handle: Int64; out Index, Generation: LongWord): Boolean;
var
  Raw: QWord;
begin
  Raw := QWord(Handle);
  Generation := LongWord(Raw shr 32);
  Index := LongWord(Raw and $FFFFFFFF);
  Result := (Generation <> 0) and (Index <> 0);
  if Result then
    Dec(Index);
end;

procedure InvalidateSlot(Index: Integer);
var
  Handle: Int64;
  EncodedTag: UTF8String;
begin
  if (Index < 0) or (Index > High(ObjectSlots)) or
     (ObjectSlots[Index].Instance = nil) then
    Exit;
  Handle := EncodeHandle(LongWord(Index), ObjectSlots[Index].Generation);
  EncodedTag := ObjectSlots[Index].TypeTag;
  if not ObjectTableShuttingDown and
     Assigned(InvalidateRuntimeHandle) and
     (ObjectSlots[Index].Runtime <> nil) and
     (EncodedTag <> '') then
    InvalidateRuntimeHandle(
      ObjectSlots[Index].Runtime,
      PByte(PAnsiChar(EncodedTag)),
      Length(EncodedTag),
      Handle
    );
  ObjectSlots[Index].Instance := nil;
  ObjectSlots[Index].Runtime := nil;
  ObjectSlots[Index].TypeTag := '';
  Inc(ObjectSlots[Index].Generation);
  if ObjectSlots[Index].Generation = 0 then
    ObjectSlots[Index].Generation := 1;
end;

constructor TObjectSlotNotifier.Create(AIndex: Integer);
begin
  inherited Create(nil);
  FIndex := AIndex;
end;

procedure TObjectSlotNotifier.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and
     (FIndex >= 0) and
     (FIndex <= High(ObjectSlots)) and
     (ObjectSlots[FIndex].Instance = AComponent) then
    InvalidateSlot(FIndex);
end;

function AddObject(Instance: TObject; Runtime: Pointer; const TypeTag: UTF8String): Int64;
var
  Index: Integer;
begin
  for Index := 0 to High(ObjectSlots) do
    if ObjectSlots[Index].Instance = nil then
    begin
      if ObjectSlots[Index].Generation = 0 then
        ObjectSlots[Index].Generation := 1;
      ObjectSlots[Index].Instance := Instance;
      ObjectSlots[Index].Runtime := Runtime;
      ObjectSlots[Index].TypeTag := TypeTag;
      if ObjectSlots[Index].Notifier = nil then
        ObjectSlots[Index].Notifier := TObjectSlotNotifier.Create(Index);
      if Instance is TComponent then
        TComponent(Instance).FreeNotification(ObjectSlots[Index].Notifier);
      Exit(EncodeHandle(LongWord(Index), ObjectSlots[Index].Generation));
    end;

  Index := Length(ObjectSlots);
  SetLength(ObjectSlots, Index + 1);
  ObjectSlots[Index].Generation := 1;
  ObjectSlots[Index].Instance := Instance;
  ObjectSlots[Index].Runtime := Runtime;
  ObjectSlots[Index].TypeTag := TypeTag;
  ObjectSlots[Index].Notifier := TObjectSlotNotifier.Create(Index);
  if Instance is TComponent then
    TComponent(Instance).FreeNotification(ObjectSlots[Index].Notifier);
  Result := EncodeHandle(LongWord(Index), 1);
end;

function FindObject(Handle: Int64; ExpectedClass: TClass): TObject;
var
  Index, Generation: LongWord;
begin
  if not DecodeHandle(Handle, Index, Generation) or
     (Index >= LongWord(Length(ObjectSlots))) or
     (ObjectSlots[Index].Generation <> Generation) or
     (ObjectSlots[Index].Instance = nil) then
    raise Exception.Create('stale LCL object handle');

  Result := ObjectSlots[Index].Instance;
  if not Result.InheritsFrom(ExpectedClass) then
    raise Exception.CreateFmt(
      'LCL object type mismatch: expected %s, got %s',
      [ExpectedClass.ClassName, Result.ClassName]
    );
end;

function FindObjectOrNil(Handle: Int64; ExpectedClass: TClass): TObject;
var
  Index, Generation: LongWord;
begin
  if not DecodeHandle(Handle, Index, Generation) or
     (Index >= LongWord(Length(ObjectSlots))) or
     (ObjectSlots[Index].Generation <> Generation) or
     (ObjectSlots[Index].Instance = nil) or
     not ObjectSlots[Index].Instance.InheritsFrom(ExpectedClass) then
    Exit(nil);
  Result := ObjectSlots[Index].Instance;
end;

function FindObjectHandle(Instance: TObject; out Handle: Int64;
  out TypeTag: UTF8String): Boolean;
var
  Index: Integer;
begin
  for Index := 0 to High(ObjectSlots) do
    if ObjectSlots[Index].Instance = Instance then
    begin
      Handle := EncodeHandle(LongWord(Index), ObjectSlots[Index].Generation);
      TypeTag := ObjectSlots[Index].TypeTag;
      Exit(True);
    end;
  Handle := 0;
  TypeTag := '';
  Result := False;
end;

procedure ReleaseObject(Handle: Int64);
var
  Instance: TObject;
begin
  Instance := DetachObject(Handle);
  Instance.Free;
end;

function DetachObject(Handle: Int64): TObject;
var
  Index, Generation: LongWord;
begin
  Result := nil;
  if not DecodeHandle(Handle, Index, Generation) or
     (Index >= LongWord(Length(ObjectSlots))) or
     (ObjectSlots[Index].Generation <> Generation) or
     (ObjectSlots[Index].Instance = nil) then
    Exit;

  Result := ObjectSlots[Index].Instance;
  if Result is TComponent then
    TComponent(Result).RemoveFreeNotification(ObjectSlots[Index].Notifier);
  InvalidateSlot(Index);
  FreeAndNil(ObjectSlots[Index].Notifier);
end;

function ObjectIsTracked(Instance: TObject): Boolean;
var
  Index: Integer;
begin
  for Index := 0 to High(ObjectSlots) do
    if ObjectSlots[Index].Instance = Instance then
      Exit(True);
  Result := False;
end;

procedure ShutdownObjectTable(Cleanup: TP7ObjectCleanup);
var
  Index: Integer;
  Handle: Int64;
  Instance: TObject;
begin
  if ObjectTableShuttingDown then
    Exit;
  ObjectTableShuttingDown := True;

  if Assigned(Cleanup) then
    for Index := 0 to High(ObjectSlots) do
      if ObjectSlots[Index].Instance <> nil then
        Cleanup(ObjectSlots[Index].Instance);

  for Index := 0 to High(ObjectSlots) do
  begin
    Instance := ObjectSlots[Index].Instance;
    if Instance = nil then
      Continue;
    if not (Instance is TComponent) or
       (TComponent(Instance).Owner = nil) or
       not ObjectIsTracked(TComponent(Instance).Owner) then
    begin
      Handle := EncodeHandle(LongWord(Index), ObjectSlots[Index].Generation);
      Instance := DetachObject(Handle);
      Instance.Free;
    end;
  end;

  for Index := 0 to High(ObjectSlots) do
  begin
    Instance := ObjectSlots[Index].Instance;
    if Instance <> nil then
    begin
      Handle := EncodeHandle(LongWord(Index), ObjectSlots[Index].Generation);
      Instance := DetachObject(Handle);
      Instance.Free;
    end;
    FreeAndNil(ObjectSlots[Index].Notifier);
  end;
  ObjectSlots := nil;
  InvalidateRuntimeHandle := nil;
end;

finalization
  ShutdownObjectTable(nil);

end.
