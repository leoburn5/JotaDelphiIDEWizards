unit Jota.IDEWizards.TableScript;

interface

uses
  Jota.IDEWizards.Metadata;

type
  TJotaTableScriptKind = (tskInsert, tskUpsert, tskUpdate, tskDelete);
  TJotaTableScriptKinds = set of TJotaTableScriptKind;

const
  TableScriptKindNames: array[TJotaTableScriptKind] of string = (
    'Insert', 'Upsert', 'Update', 'Delete');

function TableScriptRequiresPrimaryKey(AKind: TJotaTableScriptKind): Boolean;
function BuildTableScriptSql(ATable: TJotaMetaTable; AKind: TJotaTableScriptKind): string;
function GenerateTableScripts(ATable: TJotaMetaTable; AKinds: TJotaTableScriptKinds;
  const AIndent: string; AReplaceMethods: Boolean; out ASkipped: string): string;

implementation

uses
  System.SysUtils,
  System.Classes,
  Jota.IDEWizards.SqlDelphiConverter,
  Jota.IDEWizards.SqlEntity;

function TableScriptRequiresPrimaryKey(AKind: TJotaTableScriptKind): Boolean;
begin
  Result := AKind <> tskInsert;
end;

function QuoteIdentifier(const AName: string): string;
begin
  if (AName = LowerCase(AName)) and IsValidIdent(AName) then
    Result := AName
  else
    Result := '"' + StringReplace(AName, '"', '""', [rfReplaceAll]) + '"';
end;

function ParamName(const AName: string): string;
var
  C: Char;
begin
  if IsValidIdent(AName) then
    Result := AName
  else
  begin
    Result := '';
    for C in AName do
      if CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
        Result := Result + C
      else
        Result := Result + '_';
    if (Result = '') or CharInSet(Result[1], ['0'..'9']) then
      Result := 'p' + Result;
  end;
end;

function TableReference(ATable: TJotaMetaTable): string;
begin
  if SameText(ATable.Schema, 'public') then
    Result := QuoteIdentifier(ATable.Name)
  else
    Result := QuoteIdentifier(ATable.Schema) + '.' + QuoteIdentifier(ATable.Name);
end;

function NonKeyColumns(ATable: TJotaMetaTable): TArray<TJotaMetaColumn>;
var
  Column: TJotaMetaColumn;
begin
  Result := nil;
  for Column in ATable.Columns do
    if not Column.PrimaryKey then
      Result := Result + [Column];
end;

function Separator(AIndex, ACount: Integer): string;
begin
  if AIndex < ACount - 1 then
    Result := ','
  else
    Result := '';
end;

procedure AddInsert(ATable: TJotaMetaTable; ALines: TStringList);
var
  I: Integer;
begin
  ALines.Add('INSERT INTO ' + TableReference(ATable) + ' (');
  for I := 0 to ATable.Columns.Count - 1 do
    ALines.Add('    ' + QuoteIdentifier(ATable.Columns[I].Name) +
      Separator(I, ATable.Columns.Count));
  ALines.Add(') VALUES (');
  for I := 0 to ATable.Columns.Count - 1 do
    ALines.Add('    :' + ParamName(ATable.Columns[I].Name) +
      Separator(I, ATable.Columns.Count));
  ALines.Add(')');
end;

procedure AddKeyWhere(ATable: TJotaMetaTable; ALines: TStringList);
var
  I: Integer;
  KeyName: string;
begin
  for I := 0 to High(ATable.PrimaryKey) do
  begin
    KeyName := ATable.PrimaryKey[I];
    if I = 0 then
      ALines.Add('WHERE ' + QuoteIdentifier(KeyName) + ' = :' + ParamName(KeyName))
    else
      ALines.Add('  AND ' + QuoteIdentifier(KeyName) + ' = :' + ParamName(KeyName));
  end;
end;

function BuildTableScriptSql(ATable: TJotaMetaTable; AKind: TJotaTableScriptKind): string;
var
  Lines: TStringList;
  NonKeys: TArray<TJotaMetaColumn>;
  KeyList: string;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    NonKeys := NonKeyColumns(ATable);
    case AKind of
      tskInsert:
        AddInsert(ATable, Lines);
      tskUpsert:
        begin
          AddInsert(ATable, Lines);
          KeyList := '';
          for I := 0 to High(ATable.PrimaryKey) do
            KeyList := KeyList + QuoteIdentifier(ATable.PrimaryKey[I]) +
              Separator(I, Length(ATable.PrimaryKey)) + ' ';
          Lines.Add('ON CONFLICT (' + Trim(KeyList) + ')');
          if Length(NonKeys) = 0 then
            Lines.Add('DO NOTHING')
          else
          begin
            Lines.Add('DO UPDATE SET');
            for I := 0 to High(NonKeys) do
              Lines.Add('    ' + QuoteIdentifier(NonKeys[I].Name) + ' = EXCLUDED.' +
                QuoteIdentifier(NonKeys[I].Name) + Separator(I, Length(NonKeys)));
          end;
        end;
      tskUpdate:
        begin
          Lines.Add('UPDATE ' + TableReference(ATable) + ' SET');
          for I := 0 to High(NonKeys) do
            Lines.Add('    ' + QuoteIdentifier(NonKeys[I].Name) + ' = :' +
              ParamName(NonKeys[I].Name) + Separator(I, Length(NonKeys)));
          AddKeyWhere(ATable, Lines);
        end;
      tskDelete:
        begin
          Lines.Add('DELETE FROM ' + TableReference(ATable));
          AddKeyWhere(ATable, Lines);
        end;
    end;
    Lines.LineBreak := sLineBreak;
    Lines.TrailingLineBreak := False;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function ConstantName(ATable: TJotaMetaTable; AKind: TJotaTableScriptKind): string;
var
  TableName: string;
begin
  TableName := TableNameToPascalCase(ATable.Name);
  if not IsValidIdent('Sql' + TableName) then
    TableName := ParamName(ATable.Name);
  Result := 'cSql' + TableScriptKindNames[AKind] + TableName;
end;

function ScriptParamColumns(ATable: TJotaMetaTable; AKind: TJotaTableScriptKind): TArray<string>;
var
  Column: TJotaMetaColumn;
  KeyName: string;
begin
  Result := nil;
  if AKind in [tskInsert, tskUpsert] then
  begin
    for Column in ATable.Columns do
      Result := Result + [Column.Name];
  end
  else
  begin
    if AKind = tskUpdate then
      for Column in NonKeyColumns(ATable) do
        Result := Result + [Column.Name];
    for KeyName in ATable.PrimaryKey do
      Result := Result + [KeyName];
  end;
end;

function IsForeignKeyColumn(ATable: TJotaMetaTable; const AColumnName: string): Boolean;
var
  ForeignKey: TJotaMetaForeignKey;
  ColumnName: string;
begin
  Result := False;
  for ForeignKey in ATable.ForeignKeys do
    for ColumnName in ForeignKey.Columns do
      if SameText(ColumnName, AColumnName) then
        Result := True;
end;

function PropertyReference(const AColumnName: string): string;
begin
  Result := ParamName(AColumnName);
  if IsDelphiReservedWord(Result) then
    Result := '&' + Result;
end;

procedure AddReplaceMethod(ATable: TJotaMetaTable; AKind: TJotaTableScriptKind;
  const AIndent: string; ALines: TStringList);
var
  ColumnName, ReplaceFunction: string;
begin
  ALines.Add('');
  ALines.Add(AIndent + 'var');
  ALines.Add(AIndent + '  _Sql: string;');
  ALines.Add(AIndent + 'begin');
  ALines.Add(AIndent + '  _Sql := ' + ConstantName(ATable, AKind) + ';');
  for ColumnName in ScriptParamColumns(ATable, AKind) do
  begin
    if IsForeignKeyColumn(ATable, ColumnName) then
      ReplaceFunction := 'ReplaceSqlAsNull'
    else
      ReplaceFunction := 'ReplaceSql';
    ALines.Add(AIndent + '  _Sql := FDMConexaoSPK.' + ReplaceFunction + '(_Sql, '':' +
      ParamName(ColumnName) + ''', aOrigemParam.' + PropertyReference(ColumnName) + ');');
  end;
  ALines.Add(AIndent + '  FDMConexaoSPK.ExecSQL(_Sql);');
  ALines.Add(AIndent + 'end;');
end;

function GenerateTableScripts(ATable: TJotaMetaTable; AKinds: TJotaTableScriptKinds;
  const AIndent: string; AReplaceMethods: Boolean; out ASkipped: string): string;
var
  Lines, ConstantLines: TStringList;
  Kind: TJotaTableScriptKind;
  Line: string;
begin
  ASkipped := '';
  Lines := TStringList.Create;
  ConstantLines := TStringList.Create;
  try
    for Kind := Low(TJotaTableScriptKind) to High(TJotaTableScriptKind) do
      if Kind in AKinds then
      begin
        if TableScriptRequiresPrimaryKey(Kind) and (Length(ATable.PrimaryKey) = 0) then
          ASkipped := ASkipped + TableScriptKindNames[Kind] + ' (tabela sem chave primária)' + sLineBreak
        else if (Kind = tskUpdate) and (Length(NonKeyColumns(ATable)) = 0) then
          ASkipped := ASkipped + TableScriptKindNames[Kind] +
            ' (todas as colunas fazem parte da chave primária)' + sLineBreak
        else
        begin
          if Lines.Count > 0 then
            Lines.Add('');
          if AReplaceMethods then
            Lines.Add(AIndent + 'const');
          Lines.Add(AIndent + '  ' + ConstantName(ATable, Kind) + ' =');
          ConstantLines.Text := SqlToDelphiConstant(BuildTableScriptSql(ATable, Kind));
          for Line in ConstantLines do
            Lines.Add(AIndent + '    ' + TrimLeft(Line));
          if AReplaceMethods then
            AddReplaceMethod(ATable, Kind, AIndent, Lines);
        end;
      end;

    if Lines.Count > 0 then
    begin
      if AReplaceMethods then
        Lines[0] := TrimLeft(Lines[0])
      else
        Lines.Insert(0, 'const');
      Lines.LineBreak := sLineBreak;
      Lines.TrailingLineBreak := False;
      Result := Lines.Text;
    end
    else
      Result := '';
    ASkipped := TrimRight(ASkipped);
  finally
    ConstantLines.Free;
    Lines.Free;
  end;
end;

end.
