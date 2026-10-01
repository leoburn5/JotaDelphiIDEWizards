unit Jota.IDEWizards.Metadata;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  Jota.IDEWizards.Config;

type
  TJotaMetaTableKind = (mtkTable, mtkView, mtkMaterializedView, mtkForeignTable);

  TJotaMetaColumn = class
  private
    FName: string;
    FPosition: Integer;
    FDataType: string;
    FTypeName: string;
    FLength: Integer;
    FPrecision: Integer;
    FScale: Integer;
    FNotNull: Boolean;
    FDefaultValue: string;
    FPrimaryKey: Boolean;
  public
    property Name: string read FName;
    property Position: Integer read FPosition;
    property DataType: string read FDataType;
    property TypeName: string read FTypeName;
    property Length: Integer read FLength;
    property Precision: Integer read FPrecision;
    property Scale: Integer read FScale;
    property NotNull: Boolean read FNotNull;
    property DefaultValue: string read FDefaultValue;
    property PrimaryKey: Boolean read FPrimaryKey;
  end;

  TJotaMetaForeignKey = class
  private
    FName: string;
    FColumns: TArray<string>;
    FRefSchema: string;
    FRefTable: string;
    FRefColumns: TArray<string>;
  public
    property Name: string read FName;
    property Columns: TArray<string> read FColumns;
    property RefSchema: string read FRefSchema;
    property RefTable: string read FRefTable;
    property RefColumns: TArray<string> read FRefColumns;
  end;

  TJotaMetaTable = class
  private
    FSchema: string;
    FName: string;
    FKind: TJotaMetaTableKind;
    FColumns: TObjectList<TJotaMetaColumn>;
    FPrimaryKeyName: string;
    FPrimaryKey: TArray<string>;
    FForeignKeys: TObjectList<TJotaMetaForeignKey>;
    function GetFullName: string;
    function GetIsView: Boolean;
  public
    constructor Create(const ASchema, AName: string; AKind: TJotaMetaTableKind);
    destructor Destroy; override;
    function FindColumn(const AName: string): TJotaMetaColumn;
    property Schema: string read FSchema;
    property Name: string read FName;
    property FullName: string read GetFullName;
    property Kind: TJotaMetaTableKind read FKind;
    property IsView: Boolean read GetIsView;
    property Columns: TObjectList<TJotaMetaColumn> read FColumns;
    property PrimaryKeyName: string read FPrimaryKeyName;
    property PrimaryKey: TArray<string> read FPrimaryKey;
    property ForeignKeys: TObjectList<TJotaMetaForeignKey> read FForeignKeys;
  end;

  TJotaMetadata = class
  private
    FHost: string;
    FDatabase: string;
    FLoadedAt: TDateTime;
    FLoadTimeMs: Int64;
    FTables: TObjectList<TJotaMetaTable>;
    FIndex: TDictionary<string, TJotaMetaTable>;
    function AddTable(const ASchema, AName: string; AKind: TJotaMetaTableKind): TJotaMetaTable;
  public
    constructor Create(const AHost, ADatabase: string);
    destructor Destroy; override;
    function FindTable(const AName: string): TJotaMetaTable; overload;
    function FindTable(const ASchema, AName: string): TJotaMetaTable; overload;
    function Summary: string;
    property Host: string read FHost;
    property Database: string read FDatabase;
    property LoadedAt: TDateTime read FLoadedAt;
    property LoadTimeMs: Int64 read FLoadTimeMs;
    property Tables: TObjectList<TJotaMetaTable> read FTables;
  end;

  TJotaMetadataLoadResult = (mlrNotConfigured, mlrLoaded, mlrFailed);

function CreateBaseDadosTrabalhoConnection(const AConfig: TJotaBaseDadosTrabalho): TFDConnection;
function LoadJotaMetadata: TJotaMetadataLoadResult;
function JotaMetadata: TJotaMetadata;
function JotaMetadataLastError: string;

implementation

uses
  System.Classes,
  System.Diagnostics,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.UI.Intf,
  FireDAC.VCLUI.Wait,
  FireDAC.Phys,
  FireDAC.Phys.Intf,
  FireDAC.Phys.PG,
  FireDAC.DApt;

const
  ExcludedSchemasFilter =
    '  and n.nspname not in (''pg_catalog'', ''information_schema'')' + sLineBreak +
    '  and n.nspname not like ''pg\_toast%''' + sLineBreak +
    '  and n.nspname not like ''pg\_temp%''' + sLineBreak +
    '  and not c.relispartition' + sLineBreak;

  SqlColumns =
    'select n.nspname::text as schema_name,' + sLineBreak +
    '       c.relname::text as table_name,' + sLineBreak +
    '       c.relkind::text as rel_kind,' + sLineBreak +
    '       a.attnum::integer as column_position,' + sLineBreak +
    '       a.attname::text as column_name,' + sLineBreak +
    '       format_type(a.atttypid, a.atttypmod) as data_type,' + sLineBreak +
    '       t.typname::text as type_name,' + sLineBreak +
    '       case when a.atttypid in (1042, 1043) and a.atttypmod > 0' + sLineBreak +
    '            then a.atttypmod - 4 end as char_length,' + sLineBreak +
    '       case when a.atttypid = 1700 and a.atttypmod > 0' + sLineBreak +
    '            then ((a.atttypmod - 4) >> 16) & 65535 end as numeric_precision,' + sLineBreak +
    '       case when a.atttypid = 1700 and a.atttypmod > 0' + sLineBreak +
    '            then (a.atttypmod - 4) & 65535 end as numeric_scale,' + sLineBreak +
    '       a.attnotnull as not_null,' + sLineBreak +
    '       pg_get_expr(d.adbin, d.adrelid) as default_value' + sLineBreak +
    '  from pg_class c' + sLineBreak +
    '  join pg_namespace n on n.oid = c.relnamespace' + sLineBreak +
    '  join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped' + sLineBreak +
    '  join pg_type t on t.oid = a.atttypid' + sLineBreak +
    '  left join pg_attrdef d on d.adrelid = c.oid and d.adnum = a.attnum' + sLineBreak +
    ' where c.relkind in (''r'', ''p'', ''v'', ''m'', ''f'')' + sLineBreak +
    ExcludedSchemasFilter +
    ' order by n.nspname, c.relname, a.attnum';

  SqlConstraints =
    'select n.nspname::text as schema_name,' + sLineBreak +
    '       c.relname::text as table_name,' + sLineBreak +
    '       con.conname::text as constraint_name,' + sLineBreak +
    '       con.contype::text as constraint_type,' + sLineBreak +
    '       array_to_string(array(select a.attname' + sLineBreak +
    '                               from unnest(con.conkey) with ordinality as k(attnum, ord)' + sLineBreak +
    '                               join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k.attnum' + sLineBreak +
    '                              order by k.ord), '','') as column_names,' + sLineBreak +
    '       rn.nspname::text as ref_schema_name,' + sLineBreak +
    '       rc.relname::text as ref_table_name,' + sLineBreak +
    '       array_to_string(array(select a.attname' + sLineBreak +
    '                               from unnest(con.confkey) with ordinality as k(attnum, ord)' + sLineBreak +
    '                               join pg_attribute a on a.attrelid = con.confrelid and a.attnum = k.attnum' + sLineBreak +
    '                              order by k.ord), '','') as ref_column_names' + sLineBreak +
    '  from pg_constraint con' + sLineBreak +
    '  join pg_class c on c.oid = con.conrelid' + sLineBreak +
    '  join pg_namespace n on n.oid = c.relnamespace' + sLineBreak +
    '  left join pg_class rc on rc.oid = con.confrelid' + sLineBreak +
    '  left join pg_namespace rn on rn.oid = rc.relnamespace' + sLineBreak +
    ' where con.contype in (''p'', ''f'')' + sLineBreak +
    ExcludedSchemasFilter +
    ' order by n.nspname, c.relname, con.contype, con.conname';

  LoginTimeoutSeconds = 5;
  JotaPgDriverID = 'JotaPG';

var
  GMetadata: TJotaMetadata = nil;
  GLastError: string = '';
  GDriverLink: TFDPhysPgDriverLink = nil;

procedure PrepareDriverLink(const AVendorLib: string);
begin
  if GDriverLink = nil then
  begin
    GDriverLink := TFDPhysPgDriverLink.Create(nil);
    GDriverLink.DriverID := JotaPgDriverID;
    GDriverLink.VendorLib := AVendorLib;
  end
  else if not SameText(GDriverLink.VendorLib, AVendorLib) then
  begin
    GDriverLink.Release;
    GDriverLink.VendorLib := AVendorLib;
  end;
end;

function MakeKey(const ASchema, AName: string): string;
begin
  Result := LowerCase(ASchema + '.' + AName);
end;

function SplitNames(const AText: string): TArray<string>;
begin
  if AText = '' then
    Result := nil
  else
    Result := AText.Split([',']);
end;

function KindFromRelKind(const ARelKind: string): TJotaMetaTableKind;
begin
  if ARelKind = 'v' then
    Result := mtkView
  else if ARelKind = 'm' then
    Result := mtkMaterializedView
  else if ARelKind = 'f' then
    Result := mtkForeignTable
  else
    Result := mtkTable;
end;

constructor TJotaMetaTable.Create(const ASchema, AName: string; AKind: TJotaMetaTableKind);
begin
  inherited Create;
  FSchema := ASchema;
  FName := AName;
  FKind := AKind;
  FColumns := TObjectList<TJotaMetaColumn>.Create(True);
  FForeignKeys := TObjectList<TJotaMetaForeignKey>.Create(True);
end;

destructor TJotaMetaTable.Destroy;
begin
  FForeignKeys.Free;
  FColumns.Free;
  inherited;
end;

function TJotaMetaTable.GetFullName: string;
begin
  Result := FSchema + '.' + FName;
end;

function TJotaMetaTable.GetIsView: Boolean;
begin
  Result := FKind in [mtkView, mtkMaterializedView];
end;

function TJotaMetaTable.FindColumn(const AName: string): TJotaMetaColumn;
var
  I: Integer;
begin
  Result := nil;
  I := 0;
  while (Result = nil) and (I < FColumns.Count) do
  begin
    if SameText(FColumns[I].Name, AName) then
      Result := FColumns[I];
    Inc(I);
  end;
end;

constructor TJotaMetadata.Create(const AHost, ADatabase: string);
begin
  inherited Create;
  FHost := AHost;
  FDatabase := ADatabase;
  FTables := TObjectList<TJotaMetaTable>.Create(True);
  FIndex := TDictionary<string, TJotaMetaTable>.Create;
end;

destructor TJotaMetadata.Destroy;
begin
  FIndex.Free;
  FTables.Free;
  inherited;
end;

function TJotaMetadata.AddTable(const ASchema, AName: string;
  AKind: TJotaMetaTableKind): TJotaMetaTable;
begin
  Result := TJotaMetaTable.Create(ASchema, AName, AKind);
  FTables.Add(Result);
  FIndex.AddOrSetValue(MakeKey(ASchema, AName), Result);
end;

function TJotaMetadata.FindTable(const ASchema, AName: string): TJotaMetaTable;
begin
  if not FIndex.TryGetValue(MakeKey(ASchema, AName), Result) then
    Result := nil;
end;

function TJotaMetadata.FindTable(const AName: string): TJotaMetaTable;
var
  DotPos, I: Integer;
begin
  DotPos := Pos('.', AName);
  if DotPos > 0 then
    Result := FindTable(Copy(AName, 1, DotPos - 1), Copy(AName, DotPos + 1, MaxInt))
  else
  begin
    Result := FindTable('public', AName);
    I := 0;
    while (Result = nil) and (I < FTables.Count) do
    begin
      if SameText(FTables[I].Name, AName) then
        Result := FTables[I];
      Inc(I);
    end;
  end;
end;

function TJotaMetadata.Summary: string;
var
  Table: TJotaMetaTable;
  TableCount, ViewCount, ColumnCount: Integer;
begin
  TableCount := 0;
  ViewCount := 0;
  ColumnCount := 0;
  for Table in FTables do
  begin
    if Table.IsView then
      Inc(ViewCount)
    else
      Inc(TableCount);
    Inc(ColumnCount, Table.Columns.Count);
  end;
  Result := Format('%d tabelas, %d views, %d colunas (%d ms)',
    [TableCount, ViewCount, ColumnCount, FLoadTimeMs]);
end;

function CreateBaseDadosTrabalhoConnection(const AConfig: TJotaBaseDadosTrabalho): TFDConnection;
begin
  PrepareDriverLink(AConfig.ActiveVendorLib);
  Result := TFDConnection.Create(nil);
  try
    Result.LoginPrompt := False;
    Result.ResourceOptions.SilentMode := True;
    Result.Params.DriverID := JotaPgDriverID;
    Result.Params.Values['Server'] := AConfig.Host;
    Result.Params.Values['Port'] := IntToStr(AConfig.Porta);
    Result.Params.Database := AConfig.NomeBD;
    Result.Params.UserName := AConfig.Usuario;
    Result.Params.Password := AConfig.Senha;
    Result.Params.Values['LoginTimeout'] := IntToStr(LoginTimeoutSeconds);
    Result.Params.Values['ApplicationName'] := 'Jota IDE Wizards';
  except
    Result.Free;
    raise;
  end;
end;

function CreateQuery(AConnection: TFDConnection; const ASql: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := AConnection;
  Result.FetchOptions.Mode := fmAll;
  Result.FetchOptions.Unidirectional := True;
  Result.ResourceOptions.MacroCreate := False;
  Result.ResourceOptions.MacroExpand := False;
  Result.ResourceOptions.ParamCreate := False;
  Result.ResourceOptions.ParamExpand := False;
  Result.ResourceOptions.EscapeExpand := False;
  Result.SQL.Text := ASql;
end;

procedure LoadColumns(AConnection: TFDConnection; AMetadata: TJotaMetadata);
var
  Qry: TFDQuery;
  Table: TJotaMetaTable;
  Column: TJotaMetaColumn;
  Key: string;
begin
  Qry := CreateQuery(AConnection, SqlColumns);
  try
    Qry.Open;
    Table := nil;
    while not Qry.Eof do
    begin
      Key := MakeKey(Qry.FieldByName('schema_name').AsString, Qry.FieldByName('table_name').AsString);
      if (Table = nil) or (MakeKey(Table.Schema, Table.Name) <> Key) then
        Table := AMetadata.AddTable(Qry.FieldByName('schema_name').AsString,
          Qry.FieldByName('table_name').AsString,
          KindFromRelKind(Qry.FieldByName('rel_kind').AsString));

      Column := TJotaMetaColumn.Create;
      Table.FColumns.Add(Column);
      Column.FName := Qry.FieldByName('column_name').AsString;
      Column.FPosition := Qry.FieldByName('column_position').AsInteger;
      Column.FDataType := Qry.FieldByName('data_type').AsString;
      Column.FTypeName := Qry.FieldByName('type_name').AsString;
      Column.FLength := Qry.FieldByName('char_length').AsInteger;
      Column.FPrecision := Qry.FieldByName('numeric_precision').AsInteger;
      Column.FScale := Qry.FieldByName('numeric_scale').AsInteger;
      Column.FNotNull := Qry.FieldByName('not_null').AsBoolean;
      Column.FDefaultValue := Qry.FieldByName('default_value').AsString;

      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure ApplyPrimaryKey(ATable: TJotaMetaTable; const AName: string;
  const AColumns: TArray<string>);
var
  ColumnName: string;
  Column: TJotaMetaColumn;
begin
  ATable.FPrimaryKeyName := AName;
  ATable.FPrimaryKey := AColumns;
  for ColumnName in AColumns do
  begin
    Column := ATable.FindColumn(ColumnName);
    if Column <> nil then
      Column.FPrimaryKey := True;
  end;
end;

procedure LoadConstraints(AConnection: TFDConnection; AMetadata: TJotaMetadata);
var
  Qry: TFDQuery;
  Table: TJotaMetaTable;
  ForeignKey: TJotaMetaForeignKey;
begin
  Qry := CreateQuery(AConnection, SqlConstraints);
  try
    Qry.Open;
    while not Qry.Eof do
    begin
      Table := AMetadata.FindTable(Qry.FieldByName('schema_name').AsString,
        Qry.FieldByName('table_name').AsString);
      if Table <> nil then
      begin
        if Qry.FieldByName('constraint_type').AsString = 'p' then
          ApplyPrimaryKey(Table, Qry.FieldByName('constraint_name').AsString,
            SplitNames(Qry.FieldByName('column_names').AsString))
        else
        begin
          ForeignKey := TJotaMetaForeignKey.Create;
          Table.FForeignKeys.Add(ForeignKey);
          ForeignKey.FName := Qry.FieldByName('constraint_name').AsString;
          ForeignKey.FColumns := SplitNames(Qry.FieldByName('column_names').AsString);
          ForeignKey.FRefSchema := Qry.FieldByName('ref_schema_name').AsString;
          ForeignKey.FRefTable := Qry.FieldByName('ref_table_name').AsString;
          ForeignKey.FRefColumns := SplitNames(Qry.FieldByName('ref_column_names').AsString);
        end;
      end;
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function ReadMetadata(const AConfig: TJotaBaseDadosTrabalho): TJotaMetadata;
var
  Connection: TFDConnection;
  Stopwatch: TStopwatch;
begin
  Stopwatch := TStopwatch.StartNew;
  Result := TJotaMetadata.Create(AConfig.Host, AConfig.NomeBD);
  try
    Connection := CreateBaseDadosTrabalhoConnection(AConfig);
    try
      Connection.Connected := True;
      LoadColumns(Connection, Result);
      LoadConstraints(Connection, Result);
      Connection.Connected := False;
    finally
      Connection.Free;
    end;
    Result.FLoadedAt := Now;
    Result.FLoadTimeMs := Stopwatch.ElapsedMilliseconds;
  except
    Result.Free;
    raise;
  end;
end;

function LoadJotaMetadata: TJotaMetadataLoadResult;
var
  Config: TJotaBaseDadosTrabalho;
  NewMetadata: TJotaMetadata;
begin
  GLastError := '';
  try
    Config := LoadBaseDadosTrabalho;
    if Config.IsConfigured then
    begin
      NewMetadata := ReadMetadata(Config);
      GMetadata.Free;
      GMetadata := NewMetadata;
      Result := mlrLoaded;
    end
    else
    begin
      FreeAndNil(GMetadata);
      Result := mlrNotConfigured;
    end;
  except
    on E: Exception do
    begin
      GLastError := E.Message;
      Result := mlrFailed;
    end;
  end;
end;

function JotaMetadata: TJotaMetadata;
begin
  Result := GMetadata;
end;

function JotaMetadataLastError: string;
begin
  Result := GLastError;
end;

initialization

finalization
  FreeAndNil(GMetadata);
  FreeAndNil(GDriverLink);

end.
