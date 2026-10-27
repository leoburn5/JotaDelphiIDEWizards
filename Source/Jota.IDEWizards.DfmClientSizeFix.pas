unit Jota.IDEWizards.DfmClientSizeFix;

interface

uses
  System.SysUtils;

function ReadDfmBytes(const AFileName: string): TBytes;
function RestoreRemovedClientSize(const AFileName: string; const ABefore: TBytes;
  out ARestored: string): Boolean;

implementation

uses
  System.Classes,
  System.StrUtils,
  System.IOUtils;

const
  ClientSizeProperties: array[0..1] of string = ('ClientHeight', 'ClientWidth');
  Utf8BomAsRawText = #$EF#$BB#$BF;

function ReadDfmBytes(const AFileName: string): TBytes;
begin
  Result := nil;
  if TFile.Exists(AFileName) then
    Result := TFile.ReadAllBytes(AFileName);
end;

function BytesToRawText(const ABytes: TBytes): string;
var
  I: Integer;
begin
  SetLength(Result, Length(ABytes));
  for I := 0 to High(ABytes) do
    Result[I + 1] := Char(ABytes[I]);
end;

function RawTextToBytes(const AText: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AText));
  for I := 1 to Length(AText) do
    Result[I - 1] := Byte(Ord(AText[I]));
end;

procedure SplitRawLines(const AText: string; ALines: TStrings; out AEndsWithLineFeed: Boolean);
var
  Start, I: Integer;
begin
  ALines.Clear;
  Start := 1;
  for I := 1 to Length(AText) do
    if AText[I] = #10 then
    begin
      ALines.Add(Copy(AText, Start, I - Start));
      Start := I + 1;
    end;
  AEndsWithLineFeed := Start > Length(AText);
  if not AEndsWithLineFeed then
    ALines.Add(Copy(AText, Start, MaxInt));
end;

function JoinRawLines(ALines: TStrings; AEndsWithLineFeed: Boolean): string;
var
  Builder: TStringBuilder;
  I: Integer;
begin
  Builder := TStringBuilder.Create;
  try
    for I := 0 to ALines.Count - 1 do
    begin
      Builder.Append(ALines[I]);
      if (I < ALines.Count - 1) or AEndsWithLineFeed then
        Builder.Append(#10);
    end;
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function LineContent(const ALine: string): string;
begin
  Result := ALine;
  if EndsStr(#13, Result) then
    SetLength(Result, Length(Result) - 1);
end;

function IsObjectHeader(const AText: string): Boolean;
begin
  Result := StartsStr('object ', AText) or StartsStr('inherited ', AText) or
    StartsStr('inline ', AText);
end;

function IsTextDfm(ALines: TStrings): Boolean;
var
  Header: string;
begin
  Result := False;
  if ALines.Count > 0 then
  begin
    Header := LineContent(ALines[0]);
    if StartsStr(Utf8BomAsRawText, Header) then
      Header := Copy(Header, Length(Utf8BomAsRawText) + 1, MaxInt);
    Result := IsObjectHeader(TrimLeft(Header));
  end;
end;

function IsRootLevelLine(const ALine: string): Boolean;
var
  Content: string;
begin
  Content := LineContent(ALine);
  Result := (Length(Content) > 2) and (Content[1] = ' ') and (Content[2] = ' ') and
    (Content[3] <> ' ');
end;

function RootPropertyName(const ALine: string): string;
var
  Content: string;
  EqualPos: Integer;
begin
  Result := '';
  if IsRootLevelLine(ALine) then
  begin
    Content := Copy(LineContent(ALine), 3, MaxInt);
    EqualPos := Pos(' = ', Content);
    if (EqualPos > 0) and not IsObjectHeader(Content) then
      Result := Copy(Content, 1, EqualPos - 1);
  end;
end;

function IsRootChildHeader(const ALine: string): Boolean;
begin
  Result := IsRootLevelLine(ALine) and IsObjectHeader(Copy(LineContent(ALine), 3, MaxInt));
end;

function RootBlockEnd(ALines: TStrings): Integer;
begin
  Result := 1;
  while (Result < ALines.Count) and (LineContent(ALines[Result]) <> 'end') and
    not IsRootChildHeader(ALines[Result]) do
    Inc(Result);
end;

function FindRootProperty(ALines: TStrings; const AName: string): Integer;
var
  I, LastIndex: Integer;
begin
  Result := -1;
  LastIndex := RootBlockEnd(ALines);
  I := 1;
  while (I < LastIndex) and (Result < 0) do
  begin
    if SameText(RootPropertyName(ALines[I]), AName) then
      Result := I;
    Inc(I);
  end;
end;

function InsertPosition(ABefore, AAfter: TStrings; ABeforeIndex: Integer): Integer;
var
  J, Found: Integer;
  PreviousName: string;
begin
  Result := 1;
  Found := -1;
  J := ABeforeIndex - 1;
  while (J >= 1) and (Found < 0) do
  begin
    PreviousName := RootPropertyName(ABefore[J]);
    if PreviousName <> '' then
      Found := FindRootProperty(AAfter, PreviousName);
    Dec(J);
  end;
  if Found >= 0 then
  begin
    Result := Found + 1;
    while (Result < AAfter.Count) and StartsStr('   ', LineContent(AAfter[Result])) do
      Inc(Result);
  end;
end;

function RestoreRemovedClientSize(const AFileName: string; const ABefore: TBytes;
  out ARestored: string): Boolean;
var
  BeforeLines, AfterLines: TStringList;
  BeforeEndsWithLineFeed, AfterEndsWithLineFeed: Boolean;
  PropertyName, NewLine, LineEnding: string;
  BeforeIndex: Integer;
  LastWriteTime: TDateTime;
begin
  Result := False;
  ARestored := '';
  if (Length(ABefore) > 0) and TFile.Exists(AFileName) then
  begin
    BeforeLines := TStringList.Create;
    AfterLines := TStringList.Create;
    try
      SplitRawLines(BytesToRawText(ABefore), BeforeLines, BeforeEndsWithLineFeed);
      SplitRawLines(BytesToRawText(TFile.ReadAllBytes(AFileName)), AfterLines,
        AfterEndsWithLineFeed);
      if IsTextDfm(BeforeLines) and IsTextDfm(AfterLines) then
      begin
        LineEnding := '';
        if EndsStr(#13, AfterLines[0]) then
          LineEnding := #13;
        for PropertyName in ClientSizeProperties do
        begin
          BeforeIndex := FindRootProperty(BeforeLines, PropertyName);
          if (BeforeIndex >= 0) and (FindRootProperty(AfterLines, PropertyName) < 0) then
          begin
            NewLine := LineContent(BeforeLines[BeforeIndex]);
            AfterLines.Insert(InsertPosition(BeforeLines, AfterLines, BeforeIndex),
              NewLine + LineEnding);
            if ARestored <> '' then
              ARestored := ARestored + ', ';
            ARestored := ARestored + Trim(NewLine);
            Result := True;
          end;
        end;
        if Result then
        begin
          LastWriteTime := TFile.GetLastWriteTime(AFileName);
          TFile.WriteAllBytes(AFileName,
            RawTextToBytes(JoinRawLines(AfterLines, AfterEndsWithLineFeed)));
          TFile.SetLastWriteTime(AFileName, LastWriteTime);
        end;
      end;
    finally
      AfterLines.Free;
      BeforeLines.Free;
    end;
  end;
end;

end.
