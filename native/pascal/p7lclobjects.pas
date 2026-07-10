unit P7LclObjects;

{$mode objfpc}{$H+}

interface

function AddObject(Instance: TObject): Int64;
function FindObject(Handle: Int64; ExpectedClass: TClass): TObject;
procedure ReleaseObject(Handle: Int64);

implementation

uses
  SysUtils;

type
  TObjectSlot = record
    Instance: TObject;
    Generation: LongWord;
  end;

var
  ObjectSlots: array of TObjectSlot;

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

function AddObject(Instance: TObject): Int64;
var
  Index: Integer;
begin
  for Index := 0 to High(ObjectSlots) do
    if ObjectSlots[Index].Instance = nil then
    begin
      if ObjectSlots[Index].Generation = 0 then
        ObjectSlots[Index].Generation := 1;
      ObjectSlots[Index].Instance := Instance;
      Exit(EncodeHandle(LongWord(Index), ObjectSlots[Index].Generation));
    end;

  Index := Length(ObjectSlots);
  SetLength(ObjectSlots, Index + 1);
  ObjectSlots[Index].Generation := 1;
  ObjectSlots[Index].Instance := Instance;
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

procedure ReleaseObject(Handle: Int64);
var
  Index, Generation: LongWord;
  Instance: TObject;
begin
  if not DecodeHandle(Handle, Index, Generation) or
     (Index >= LongWord(Length(ObjectSlots))) or
     (ObjectSlots[Index].Generation <> Generation) or
     (ObjectSlots[Index].Instance = nil) then
    Exit;

  Instance := ObjectSlots[Index].Instance;
  ObjectSlots[Index].Instance := nil;
  Inc(ObjectSlots[Index].Generation);
  if ObjectSlots[Index].Generation = 0 then
    ObjectSlots[Index].Generation := 1;
  Instance.Free;
end;

procedure ReleaseAllObjects;
var
  Index: Integer;
begin
  for Index := 0 to High(ObjectSlots) do
    FreeAndNil(ObjectSlots[Index].Instance);
  ObjectSlots := nil;
end;

finalization
  ReleaseAllObjects;

end.
