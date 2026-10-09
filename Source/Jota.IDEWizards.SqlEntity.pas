unit Jota.IDEWizards.SqlEntity;

interface

uses
  System.SysUtils,
  Data.DB;

type
  EJotaSqlEntityError = class(Exception);

  TJotaSqlColumn = record
    Name: string;
    FieldType: TFieldType;
  end;

function PrepareDescribeSql(const ASql: string): string;
function DescribeSqlColumns(const ASql: string): TArray<TJotaSqlColumn>;
function FieldTypeToDelphiType(AFieldType: TFieldType): string;
function ExtractFirstFromTable(const ASql: string): string;
function SuggestEntityClassName(const ASql: string): string;
function TableNameToPascalCase(const ATable: string): string;
function IsDelphiReservedWord(const AName: string): Boolean;
function GenerateObjectWithProperties(const AClassName: string;
  const AColumns: TArray<TJotaSqlColumn>; const AIndent: string): string;
function GenerateRecord(const ARecordName: string;
  const AColumns: TArray<TJotaSqlColumn>; const AIndent: string): string;
procedure GenerateInterfacedObject(const AClassName, AInterfaceName: string;
  const AColumns: TArray<TJotaSqlColumn>; const AIndent: string;
  out ADeclarations, AImplementation: string);

implementation

uses
  System.Classes,
  System.StrUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Option,
  Jota.IDEWizards.Config,
  Jota.IDEWizards.Metadata;

const
  DelphiReservedWords: array[0..65] of string = (
    'and', 'array', 'as', 'asm', 'begin', 'case', 'class', 'const',
    'constructor', 'destructor', 'dispinterface', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exports', 'file', 'finalization', 'finally',
    'for', 'function', 'goto', 'if', 'implementation', 'in', 'inherited',
    'initialization', 'inline', 'interface', 'is', 'label', 'library', 'mod',
    'nil', 'not', 'object', 'of', 'or', 'out', 'packed', 'procedure',
    'program', 'property', 'raise', 'record', 'repeat', 'resourcestring',
    'set', 'shl', 'shr', 'string', 'then', 'threadvar', 'to', 'try', 'type',
    'unit', 'until', 'uses', 'var', 'while', 'with', 'xor', 'operator');

function IsIdentStart(C: Char): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '_']);
end;

function IsIdentChar(C: Char): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '_', '0'..'9']);
end;

function ReplaceParamsWithNull(const ASql: string): string;
var
  Builder: TStringBuilder;
  I, J, Len: Integer;
  C: Char;
begin
  Builder := TStringBuilder.Create;
  try
    Len := Length(ASql);
    I := 1;
    while I <= Len do
    begin
      C := ASql[I];
      if (C = '''') or (C = '"') then
      begin
        J := I + 1;
        while (J <= Len) and (ASql[J] <> C) do
          Inc(J);
        Builder.Append(Copy(ASql, I, J - I + 1));
        I := J + 1;
      end
      else if (C = '-') and (I < Len) and (ASql[I + 1] = '-') then
      begin
        J := I;
        while (J <= Len) and not CharInSet(ASql[J], [#10, #13]) do
          Inc(J);
        Builder.Append(Copy(ASql, I, J - I));
        I := J;
      end
      else if (C = '/') and (I < Len) and (ASql[I + 1] = '*') then
      begin
        J := Pos('*/', ASql, I + 2);
        if J = 0 then
          J := Len + 1
        else
          J := J + 2;
        Builder.Append(Copy(ASql, I, J - I));
        I := J;
      end
      else if (C = ':') and (I < Len) and (ASql[I + 1] = ':') then
      begin
        Builder.Append('::');
        Inc(I, 2);
      end
      else if (C = ':') and (I < Len) and IsIdentStart(ASql[I + 1]) then
      begin
        J := I + 1;
        while (J <= Len) and IsIdentChar(ASql[J]) do
          Inc(J);
        Builder.Append('null');
        I := J;
      end
      else
      begin
        Builder.Append(C);
        Inc(I);
      end;
    end;
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function RemoveTrailingSemicolons(const ASql: string): string;
begin
  Result := TrimRight(ASql);
  while (Result <> '') and (Result[Length(Result)] = ';') do
    Result := TrimRight(Copy(Result, 1, Length(Result) - 1));
end;

function PrepareDescribeSql(const ASql: string): string;
begin
  Result := 'select * from (' + sLineBreak +
    RemoveTrailingSemicolons(ReplaceParamsWithNull(ASql)) + sLineBreak +
    ') jota_query limit 0';
end;

function TokenizeSql(const ASql: string): TArray<string>;
var
  Tokens: TList<string>;
  I, J, Len: Integer;
  C: Char;
begin
  Tokens := TList<string>.Create;
  try
    Len := Length(ASql);
    I := 1;
    while I <= Len do
    begin
      C := ASql[I];
      if CharInSet(C, [' ', #9, #10, #13]) then
        Inc(I)
      else if (C = '-') and (I < Len) and (ASql[I + 1] = '-') then
      begin
        while (I <= Len) and not CharInSet(ASql[I], [#10, #13]) do
          Inc(I);
      end
      else if (C = '/') and (I < Len) and (ASql[I + 1] = '*') then
      begin
        J := Pos('*/', ASql, I + 2);
        if J = 0 then
          I := Len + 1
        else
          I := J + 2;
      end
      else if C = '''' then
      begin
        J := I + 1;
        while (J <= Len) and (ASql[J] <> '''') do
          Inc(J);
        Tokens.Add('''''');
        I := J + 1;
      end
      else if IsIdentStart(C) or (C = '"') then
      begin
        J := I;
        while (J <= Len) and (IsIdentChar(ASql[J]) or CharInSet(ASql[J], ['.', '"'])) do
        begin
          if ASql[J] = '"' then
          begin
            Inc(J);
            while (J <= Len) and (ASql[J] <> '"') do
              Inc(J);
          end;
          Inc(J);
        end;
        Tokens.Add(Copy(ASql, I, J - I));
        I := J;
      end
      else
      begin
        Tokens.Add(C);
        Inc(I);
      end;
    end;
    Result := Tokens.ToArray;
  finally
    Tokens.Free;
  end;
end;

function IsFunctionCallParen(const APreviousToken: string): Boolean;
const
  Keywords: array[0..19] of string = ('in', 'exists', 'from', 'join', 'as', 'any',
    'all', 'some', 'select', 'where', 'and', 'or', 'on', 'not', 'lateral',
    'values', 'union', 'using', 'with', 'recursive');
var
  Keyword: string;
begin
  Result := (APreviousToken <> '') and (IsIdentStart(APreviousToken[1]) or (APreviousToken[1] = '"'));
  for Keyword in Keywords do
    if SameText(Keyword, APreviousToken) then
      Result := False;
end;

function IsTableToken(const AToken: string): Boolean;
begin
  Result := (AToken <> '') and (IsIdentStart(AToken[1]) or (AToken[1] = '"'));
end;

function ExtractFirstFromTable(const ASql: string): string;
var
  Tokens: TArray<string>;
  Parens: TStack<Boolean>;
  CteNames: TList<string>;
  I, DotPos, FunctionDepth: Integer;
  PreviousToken, Candidate, FirstAny, FirstOuter: string;
begin
  Tokens := TokenizeSql(ASql);
  FirstAny := '';
  FirstOuter := '';
  Parens := TStack<Boolean>.Create;
  CteNames := TList<string>.Create;
  try
    FunctionDepth := 0;
    for I := 0 to High(Tokens) - 1 do
    begin
      if Tokens[I] = '(' then
      begin
        if I > 0 then
          PreviousToken := Tokens[I - 1]
        else
          PreviousToken := '';
        Parens.Push(IsFunctionCallParen(PreviousToken));
        if Parens.Peek then
          Inc(FunctionDepth);
      end
      else if (Tokens[I] = ')') and (Parens.Count > 0) then
      begin
        if Parens.Pop then
          Dec(FunctionDepth);
      end
      else if (Parens.Count = 0) and (I + 2 <= High(Tokens)) and
        SameText(Tokens[I + 1], 'as') and (Tokens[I + 2] = '(') then
        CteNames.Add(LowerCase(Tokens[I]))
      else if (FunctionDepth = 0) and SameText(Tokens[I], 'from') and IsTableToken(Tokens[I + 1]) then
      begin
        Candidate := Tokens[I + 1];
        if FirstAny = '' then
          FirstAny := Candidate;
        if (FirstOuter = '') and (Parens.Count = 0) and not CteNames.Contains(LowerCase(Candidate)) then
          FirstOuter := Candidate;
      end;
    end;
  finally
    CteNames.Free;
    Parens.Free;
  end;

  if FirstOuter <> '' then
    Result := FirstOuter
  else
    Result := FirstAny;

  DotPos := LastDelimiter('.', Result);
  if DotPos > 0 then
    Result := Copy(Result, DotPos + 1, MaxInt);
  Result := StringReplace(Result, '"', '', [rfReplaceAll]);
end;

function RemoveTablePrefixes(const ATable: string): string;
var
  Removed: Boolean;
begin
  Result := ATable;
  Removed := True;
  while Removed do
  begin
    Removed := True;
    if StartsText('_', Result) then
      Delete(Result, 1, 1)
    else if StartsText('spk', Result) then
      Delete(Result, 1, 3)
    else if StartsText('tb', Result) then
      Delete(Result, 1, 2)
    else
      Removed := False;
  end;
end;

function ToPascalCasePart(const APart: string): string;
var
  Rest: string;
begin
  Rest := Copy(APart, 2, MaxInt);
  if APart = UpperCase(APart) then
    Rest := LowerCase(Rest);
  Result := UpperCase(Copy(APart, 1, 1)) + Rest;
end;

function TableNameToPascalCase(const ATable: string): string;
var
  Part: string;
begin
  Result := '';
  for Part in RemoveTablePrefixes(ATable).Split(['_']) do
    if Part <> '' then
      Result := Result + ToPascalCasePart(Part);
end;

function SuggestEntityClassName(const ASql: string): string;
begin
  Result := 'TDados' + TableNameToPascalCase(ExtractFirstFromTable(ASql));
  if not IsValidIdent(Result) then
    Result := 'TDados';
end;

function DescribeSqlColumns(const ASql: string): TArray<TJotaSqlColumn>;
var
  Config: TJotaBaseDadosTrabalho;
  Connection: TFDConnection;
  Qry: TFDQuery;
  I: Integer;
begin
  Config := LoadBaseDadosTrabalho;
  if not Config.IsConfigured then
    raise EJotaSqlEntityError.Create('A base de dados de trabalho não está configurada.' +
      sLineBreak + 'Use "1 - Configurar" no menu Ctrl+Shift+J.');

  Connection := CreateBaseDadosTrabalhoConnection(Config);
  try
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := Connection;
      Qry.ResourceOptions.MacroCreate := False;
      Qry.ResourceOptions.MacroExpand := False;
      Qry.ResourceOptions.ParamCreate := False;
      Qry.ResourceOptions.ParamExpand := False;
      Qry.ResourceOptions.EscapeExpand := False;
      Qry.SQL.Text := PrepareDescribeSql(ASql);
      Qry.Open;

      SetLength(Result, Qry.FieldCount);
      for I := 0 to Qry.FieldCount - 1 do
      begin
        Result[I].Name := Qry.Fields[I].FieldName;
        Result[I].FieldType := Qry.Fields[I].DataType;
      end;
      Qry.Close;
    finally
      Qry.Free;
    end;
    Connection.Connected := False;
  finally
    Connection.Free;
  end;
end;

function FieldTypeToDelphiType(AFieldType: TFieldType): string;
begin
  case AFieldType of
    ftString, ftWideString, ftFixedChar, ftFixedWideChar, ftMemo, ftWideMemo,
    ftFmtMemo:
      Result := 'string';
    ftSmallint:
      Result := 'SmallInt';
    ftInteger, ftAutoInc:
      Result := 'Integer';
    ftLargeint:
      Result := 'Int64';
    ftWord:
      Result := 'Word';
    ftShortint:
      Result := 'ShortInt';
    ftByte:
      Result := 'Byte';
    ftLongWord:
      Result := 'Cardinal';
    ftFloat, ftBCD, ftFMTBcd:
      Result := 'Double';
    ftSingle:
      Result := 'Single';
    ftExtended:
      Result := 'Extended';
    ftCurrency:
      Result := 'Currency';
    ftBoolean:
      Result := 'Boolean';
    ftDate:
      Result := 'TDate';
    ftTime:
      Result := 'TTime';
    ftDateTime, ftTimeStamp, ftOraTimeStamp, ftTimeStampOffset:
      Result := 'TDateTime';
    ftGuid:
      Result := 'TGUID';
    ftBlob, ftBytes, ftVarBytes, ftGraphic, ftOraBlob, ftStream:
      Result := 'TBytes';
  else
    Result := 'Variant';
  end;
end;

function IsReservedWord(const AName: string): Boolean;
var
  Reserved: string;
begin
  Result := False;
  for Reserved in DelphiReservedWords do
    if SameText(Reserved, AName) then
      Result := True;
end;

function SanitizeIdentifier(const AName: string; AIndex: Integer): string;
var
  C: Char;
begin
  if IsValidIdent(AName) then
    Result := AName
  else
  begin
    Result := '';
    for C in AName do
      if IsIdentChar(C) then
        Result := Result + C
      else
        Result := Result + '_';
    if Result = '' then
      Result := 'Coluna' + IntToStr(AIndex + 1)
    else if not IsIdentStart(Result[1]) then
      Result := '_' + Result;
  end;
end;

function BuildPropertyNames(const AColumns: TArray<TJotaSqlColumn>;
  const AReservedNames: array of string): TArray<string>;
var
  Used: TDictionary<string, Integer>;
  I, Count: Integer;
  BaseName, Name: string;
begin
  SetLength(Result, Length(AColumns));
  Used := TDictionary<string, Integer>.Create;
  try
    for Name in AReservedNames do
      Used.AddOrSetValue(LowerCase(Name), -1);
    for I := 0 to High(AColumns) do
    begin
      BaseName := SanitizeIdentifier(AColumns[I].Name, I);
      Name := BaseName;
      Count := 1;
      while Used.ContainsKey(LowerCase(Name)) do
      begin
        Inc(Count);
        Name := BaseName + '_' + IntToStr(Count);
      end;
      Used.Add(LowerCase(Name), I);
      Result[I] := Name;
    end;
  finally
    Used.Free;
  end;
end;

function IsDelphiReservedWord(const AName: string): Boolean;
begin
  Result := IsReservedWord(AName);
end;

function EscapeIdentifier(const AName: string): string;
begin
  if IsReservedWord(AName) then
    Result := '&' + AName
  else
    Result := AName;
end;

function JoinLines(ALines: TStringList): string;
begin
  ALines.LineBreak := sLineBreak;
  ALines.TrailingLineBreak := False;
  Result := ALines.Text;
end;

function GenerateRecord(const ARecordName: string;
  const AColumns: TArray<TJotaSqlColumn>; const AIndent: string): string;
var
  Lines: TStringList;
  Names: TArray<string>;
  I: Integer;
begin
  Names := BuildPropertyNames(AColumns, []);
  Lines := TStringList.Create;
  try
    Lines.Add(ARecordName + ' = record');
    for I := 0 to High(AColumns) do
      Lines.Add(AIndent + '  ' + EscapeIdentifier(Names[I]) + ': ' +
        FieldTypeToDelphiType(AColumns[I].FieldType) + ';');
    Lines.Add(AIndent + 'end;');
    Result := JoinLines(Lines);
  finally
    Lines.Free;
  end;
end;

function GenerateObjectWithProperties(const AClassName: string;
  const AColumns: TArray<TJotaSqlColumn>; const AIndent: string): string;
var
  Lines: TStringList;
  Names: TArray<string>;
  I: Integer;
  DelphiType, PropertyName, FieldName: string;
begin
  Names := BuildPropertyNames(AColumns, []);
  Lines := TStringList.Create;
  try
    Lines.Add(AClassName + ' = class(TObject)');
    Lines.Add(AIndent + 'private');
    for I := 0 to High(AColumns) do
      Lines.Add(AIndent + '  F' + Names[I] + ': ' + FieldTypeToDelphiType(AColumns[I].FieldType) + ';');
    Lines.Add(AIndent + 'public');
    for I := 0 to High(AColumns) do
    begin
      DelphiType := FieldTypeToDelphiType(AColumns[I].FieldType);
      FieldName := 'F' + Names[I];
      PropertyName := EscapeIdentifier(Names[I]);
      Lines.Add(Format('%s  property %s: %s read %s write %s;',
        [AIndent, PropertyName, DelphiType, FieldName, FieldName]));
    end;
    Lines.Add(AIndent + 'end;');
    Result := JoinLines(Lines);
  finally
    Lines.Free;
  end;
end;

procedure GenerateInterfacedObject(const AClassName, AInterfaceName: string;
  const AColumns: TArray<TJotaSqlColumn>; const AIndent: string;
  out ADeclarations, AImplementation: string);
var
  Declarations, Implementation_: TStringList;
  Names: TArray<string>;
  I: Integer;
  Guid: TGUID;
  MethodName, DelphiType, FieldName, Getter, Setter: string;
begin
  Names := BuildPropertyNames(AColumns, ['New']);
  CreateGUID(Guid);
  Declarations := TStringList.Create;
  Implementation_ := TStringList.Create;
  try
    Declarations.Add(AInterfaceName + ' = interface');
    Declarations.Add(AIndent + '  [''' + GUIDToString(Guid) + ''']');
    for I := 0 to High(AColumns) do
    begin
      MethodName := EscapeIdentifier(Names[I]);
      DelphiType := FieldTypeToDelphiType(AColumns[I].FieldType);
      Declarations.Add(AIndent + '  function ' + MethodName + ': ' + DelphiType + '; overload;');
      Declarations.Add(AIndent + '  function ' + MethodName + '(const Value: ' + DelphiType + '): ' +
        AInterfaceName + '; overload;');
    end;
    Declarations.Add(AIndent + 'end;');
    Declarations.Add('');

    Declarations.Add(AIndent + AClassName + ' = class(TInterfacedObject, ' + AInterfaceName + ')');
    Declarations.Add(AIndent + 'private');
    for I := 0 to High(AColumns) do
      Declarations.Add(AIndent + '  F' + Names[I] + ': ' + FieldTypeToDelphiType(AColumns[I].FieldType) + ';');
    Declarations.Add(AIndent + 'public');
    Declarations.Add(AIndent + '  class function New: ' + AInterfaceName + ';');

    Implementation_.Add('class function ' + AClassName + '.New: ' + AInterfaceName + ';');
    Implementation_.Add('begin');
    Implementation_.Add('  Result := Self.Create;');
    Implementation_.Add('end;');
    Implementation_.Add('');

    for I := 0 to High(AColumns) do
    begin
      MethodName := EscapeIdentifier(Names[I]);
      DelphiType := FieldTypeToDelphiType(AColumns[I].FieldType);
      FieldName := 'F' + Names[I];
      Getter := 'function ' + MethodName + ': ' + DelphiType + '; overload;';
      Setter := 'function ' + MethodName + '(const Value: ' + DelphiType + '): ' + AInterfaceName +
        '; overload;';
      Declarations.Add(AIndent + '  ' + Getter);
      Declarations.Add(AIndent + '  ' + Setter);

      Implementation_.Add('function ' + AClassName + '.' + MethodName + ': ' + DelphiType + ';');
      Implementation_.Add('begin');
      Implementation_.Add('  Result := ' + FieldName + ';');
      Implementation_.Add('end;');
      Implementation_.Add('');
      Implementation_.Add('function ' + AClassName + '.' + MethodName + '(const Value: ' + DelphiType +
        '): ' + AInterfaceName + ';');
      Implementation_.Add('begin');
      Implementation_.Add('  Result := Self;');
      Implementation_.Add('  ' + FieldName + ' := Value;');
      Implementation_.Add('end;');
      Implementation_.Add('');
    end;
    Declarations.Add(AIndent + 'end;');

    ADeclarations := JoinLines(Declarations);
    AImplementation := JoinLines(Implementation_);
  finally
    Implementation_.Free;
    Declarations.Free;
  end;
end;

end.
