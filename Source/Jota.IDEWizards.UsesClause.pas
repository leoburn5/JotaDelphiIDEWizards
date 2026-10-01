unit Jota.IDEWizards.UsesClause;

interface

type
  TEnsureUsesResult = (
    eurAdded,
    eurAlreadyInInterface,
    eurAlreadyInImplementation,
    eurNoSourceEditor,
    eurParseFailed);


function EnsureUnitInInterfaceUses(const AUnitName: string): TEnsureUsesResult;

implementation

uses
  System.SysUtils,
  ToolsAPI,
  Jota.IDEWizards.OTAUtils;

type
  TUsesClause = record
    Found: Boolean;
    SemicolonOffset: Integer; // offset (0-based, bytes) do ";" final
    Units: TArray<string>;    // nomes em minusculo
  end;

  TUnitSections = record
    InterfaceEndOffset: Integer; // offset logo apos a palavra "interface"
    InterfaceUses: TUsesClause;
    ImplementationUses: TUsesClause;
  end;

function ReadSourceBuffer(const ASourceEditor: IOTASourceEditor): RawByteString;
const
  ChunkSize = 16384;
var
  Reader: IOTAEditReader;
  Chunk: RawByteString;
  Position, ReadCount: Integer;
begin
  Result := '';
  Reader := ASourceEditor.CreateReader;
  try
    Position := 0;
    repeat
      SetLength(Chunk, ChunkSize);
      ReadCount := Reader.GetText(Position, PAnsiChar(Chunk), ChunkSize);
      SetLength(Chunk, ReadCount);
      Result := Result + Chunk;
      Inc(Position, ReadCount);
    until ReadCount < ChunkSize;
  finally
    // O reader precisa ser liberado antes de criar um writer.
    Reader := nil;
  end;
end;

function IsIdentStart(C: AnsiChar): Boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z', '_'];
end;

function IsIdentChar(C: AnsiChar): Boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.'];
end;

/// Retorna o proximo token a partir de I (1-based), pulando espacos,
/// comentarios e o conteudo de strings. TokStart recebe o indice
/// 1-based do inicio do token. Retorna '' no fim do texto.
function NextToken(const S: RawByteString; var I: Integer; out TokStart: Integer): string;
var
  Len: Integer;
begin
  Result := '';
  Len := Length(S);

  while I <= Len do
  begin
    case S[I] of
      #0..' ':
        Inc(I);
      '{':
        begin
          while (I <= Len) and (S[I] <> '}') do
            Inc(I);
          Inc(I);
        end;
      '(':
        if (I < Len) and (S[I + 1] = '*') then
        begin
          Inc(I, 2);
          while (I < Len) and not ((S[I] = '*') and (S[I + 1] = ')')) do
            Inc(I);
          Inc(I, 2);
        end
        else
          Break;
      '/':
        if (I < Len) and (S[I + 1] = '/') then
        begin
          while (I <= Len) and not (S[I] in [#10, #13]) do
            Inc(I);
        end
        else
          Break;
    else
      Break;
    end;
  end;

  if I > Len then
    Exit;

  TokStart := I;

  if IsIdentStart(S[I]) then
  begin
    while (I <= Len) and IsIdentChar(S[I]) do
      Inc(I);
    Result := LowerCase(string(Copy(S, TokStart, I - TokStart)));
  end
  else if S[I] = '''' then
  begin
    Inc(I);
    while (I <= Len) and (S[I] <> '''') do
      Inc(I);
    Inc(I);
    Result := '''';
  end
  else
  begin
    Result := string(S[I]);
    Inc(I);
  end;
end;

function ParseUsesList(const S: RawByteString; var I: Integer): TUsesClause;
var
  Tok: string;
  TokStart: Integer;
  SkipNext: Boolean;
begin
  // Chamado logo apos o token "uses".
  Result.Found := False;
  Result.Units := nil;
  SkipNext := False;
  repeat
    Tok := NextToken(S, I, TokStart);
    if Tok = '' then
      Exit;
    if Tok = ';' then
    begin
      Result.Found := True;
      Result.SemicolonOffset := TokStart - 1;
      Exit;
    end;
    if Tok = 'in' then
      SkipNext := True  // Unit in 'arquivo.pas' -> pula o nome do arquivo
    else if SkipNext then
      SkipNext := False
    else if (Tok <> ',') and IsIdentStart(AnsiChar(Tok[1])) then
      Result.Units := Result.Units + [Tok];
  until False;
end;

function ParseUnitSections(const S: RawByteString; out ASections: TUnitSections): Boolean;
var
  I, TokStart: Integer;
  Tok: string;
begin
  Result := False;
  ASections.InterfaceEndOffset := -1;
  ASections.InterfaceUses.Found := False;
  ASections.InterfaceUses.Units := nil;
  ASections.ImplementationUses.Found := False;
  ASections.ImplementationUses.Units := nil;

  I := 1;
  repeat
    Tok := NextToken(S, I, TokStart);
  until (Tok = '') or (Tok = 'interface');
  if Tok = '' then
    Exit;

  ASections.InterfaceEndOffset := I - 1;

  Tok := NextToken(S, I, TokStart);
  if Tok = 'uses' then
  begin
    ASections.InterfaceUses := ParseUsesList(S, I);
    if not ASections.InterfaceUses.Found then
      Exit;
  end;

  repeat
    Tok := NextToken(S, I, TokStart);
  until (Tok = '') or (Tok = 'implementation');

  if Tok = 'implementation' then
  begin
    Tok := NextToken(S, I, TokStart);
    if Tok = 'uses' then
      ASections.ImplementationUses := ParseUsesList(S, I);
  end;

  Result := True;
end;

function ShortUnitName(const AName: string): string;
var
  P: Integer;
begin
  P := LastDelimiter('.', AName);
  Result := Copy(AName, P + 1, MaxInt);
end;

function ContainsUnit(const AUnits: TArray<string>; const AUnitName: string): Boolean;
var
  U, Target: string;
begin
  // Compara pelo nome completo e pelo nome sem namespace
  // ("fmtbcd" == "data.fmtbcd"), por causa dos unit scope names.
  Target := LowerCase(AUnitName);
  for U in AUnits do
    if (U = Target) or (ShortUnitName(U) = ShortUnitName(Target)) then
      Exit(True);
  Result := False;
end;

procedure InsertTextAt(const ASourceEditor: IOTASourceEditor; AOffset: Integer;
  const AText: string);
var
  Writer: IOTAEditWriter;
begin
  Writer := ASourceEditor.CreateUndoableWriter;
  try
    Writer.CopyTo(AOffset);
    Writer.Insert(PAnsiChar(UTF8Encode(AText)));
  finally
    Writer := nil;
  end;
end;

function EnsureUnitInInterfaceUses(const AUnitName: string): TEnsureUsesResult;
var
  SourceEditor: IOTASourceEditor;
  Source: RawByteString;
  Sections: TUnitSections;
begin
  SourceEditor := GetActiveSourceEditor;
  if SourceEditor = nil then
    Exit(eurNoSourceEditor);

  Source := ReadSourceBuffer(SourceEditor);
  if not ParseUnitSections(Source, Sections) then
    Exit(eurParseFailed);

  if ContainsUnit(Sections.InterfaceUses.Units, AUnitName) then
    Exit(eurAlreadyInInterface);

  if ContainsUnit(Sections.ImplementationUses.Units, AUnitName) then
    Exit(eurAlreadyInImplementation);

  if Sections.InterfaceUses.Found then
    InsertTextAt(SourceEditor, Sections.InterfaceUses.SemicolonOffset,
      ', ' + AUnitName)
  else
    InsertTextAt(SourceEditor, Sections.InterfaceEndOffset,
      sLineBreak + sLineBreak + 'uses' + sLineBreak + '  ' + AUnitName + ';');

  Result := eurAdded;
end;

end.
