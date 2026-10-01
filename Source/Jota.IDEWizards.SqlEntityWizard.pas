unit Jota.IDEWizards.SqlEntityWizard;

interface

procedure RunSqlQueryToEntityWizard;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Menus,
  Vcl.Dialogs,
  Jota.IDEWizards.OTAUtils,
  Jota.IDEWizards.SqlEntity,
  Jota.IDEWizards.SqlEntityDialog,
  Jota.IDEWizards.Toast;

type
  TJotaSqlEntityTarget = (setNone, setObjectWithProperties, setRecord, setInterfacedObject);

var
  GLastSql: string = '';

function ChooseSqlEntityTarget: TJotaSqlEntityTarget;
var
  Menu: TPopupMenu;
  Item: TMenuItem;
  P: TPoint;
  Cmd: Integer;
begin
  Result := setNone;
  Menu := TPopupMenu.Create(nil);
  try
    Item := TMenuItem.Create(Menu);
    Item.Caption := '&1 - Converter em TObject Com Property';
    Item.Tag := Ord(setObjectWithProperties);
    Menu.Items.Add(Item);

    Item := TMenuItem.Create(Menu);
    Item.Caption := '&2 - Converter em Record';
    Item.Tag := Ord(setRecord);
    Menu.Items.Add(Item);

    Item := TMenuItem.Create(Menu);
    Item.Caption := '&3 - Converter em Interfaced Object';
    Item.Tag := Ord(setInterfacedObject);
    Menu.Items.Add(Item);

    P := GetEditorPopupPoint;
    Cmd := Integer(TrackPopupMenuEx(Menu.Handle,
      TPM_LEFTALIGN or TPM_TOPALIGN or TPM_RIGHTBUTTON or TPM_RETURNCMD,
      P.X, P.Y, PopupList.Window, nil));

    if Cmd <> 0 then
    begin
      Item := Menu.FindItem(Cmd, fkCommand);
      if Item <> nil then
        Result := TJotaSqlEntityTarget(Item.Tag);
    end;
  finally
    Menu.Free;
  end;
end;

function TryDescribe(const ASql: string; out AColumns: TArray<TJotaSqlColumn>): Boolean;
begin
  Screen.Cursor := crHourGlass;
  try
    try
      AColumns := DescribeSqlColumns(ASql);
      Result := Length(AColumns) > 0;
      if not Result then
        MessageDlg('A consulta não retornou nenhuma coluna.', mtWarning, [mbOK], 0);
    except
      on E: Exception do
      begin
        Screen.Cursor := crDefault;
        MessageDlg('Não foi possível executar a consulta:' + sLineBreak + sLineBreak +
          E.Message, mtError, [mbOK], 0);
        Result := False;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure InsertObjectWithProperties(const ASql: string;
  const AColumns: TArray<TJotaSqlColumn>);
var
  Indent, ClassName: string;
begin
  ClassName := SuggestEntityClassName(ASql);
  if AskEntityClassName(ClassName, 'Converter em TObject Com Property', '&Nome da classe:') then
  begin
    Indent := StringOfChar(' ', GetCursorColumn - 1);
    if InsertTextAtCursor(GenerateObjectWithProperties(ClassName, AColumns, Indent)) then
      ShowToast(Format('Classe %s gerada com %d propriedades', [ClassName, Length(AColumns)]))
    else
      MessageDlg('Nenhum editor de código ativo para inserir a classe.', mtWarning, [mbOK], 0);
  end;
end;

procedure InsertRecord(const ASql: string; const AColumns: TArray<TJotaSqlColumn>);
var
  Indent, RecordName: string;
begin
  RecordName := SuggestEntityClassName(ASql);
  if AskEntityClassName(RecordName, 'Converter em Record', '&Nome do record:') then
  begin
    Indent := StringOfChar(' ', GetCursorColumn - 1);
    if InsertTextAtCursor(GenerateRecord(RecordName, AColumns, Indent)) then
      ShowToast(Format('Record %s gerado com %d campos', [RecordName, Length(AColumns)]))
    else
      MessageDlg('Nenhum editor de código ativo para inserir o record.', mtWarning, [mbOK], 0);
  end;
end;

procedure InsertInterfacedObject(const ASql: string; const AColumns: TArray<TJotaSqlColumn>);
var
  ClassName, InterfaceName, Declarations, Implementation_: string;
  ImplementationFound: Boolean;
begin
  ClassName := SuggestEntityClassName(ASql);
  InterfaceName := SuggestInterfaceName(ClassName);
  if AskInterfacedNames(ClassName, InterfaceName) then
  begin
    GenerateInterfacedObject(ClassName, InterfaceName, AColumns,
      StringOfChar(' ', GetCursorColumn - 1), Declarations, Implementation_);
    if not InsertTextAtCursorAndImplementation(Declarations, Implementation_, ImplementationFound) then
      MessageDlg('Nenhum editor de código ativo para inserir a classe.', mtWarning, [mbOK], 0)
    else if ImplementationFound then
      ShowToast(Format('Interface %s e classe %s geradas com %d campos',
        [InterfaceName, ClassName, Length(AColumns)]))
    else
      MessageDlg('Não encontrei o final da seção implementation (initialization, finalization ' +
        'ou "end."). Os métodos foram inseridos junto da classe, no cursor; mova-os para a ' +
        'seção implementation.', mtWarning, [mbOK], 0);
  end;
end;

procedure RunSqlQueryToEntityWizard;
var
  Sql: string;
  Columns: TArray<TJotaSqlColumn>;
  Described: Boolean;
begin
  Sql := GLastSql;
  Described := False;

  while not Described and ExecuteSqlEntityDialog(Sql) do
  begin
    GLastSql := Sql;
    Described := TryDescribe(Sql, Columns);
  end;

  if Described then
    case ChooseSqlEntityTarget of
      setObjectWithProperties:
        InsertObjectWithProperties(Sql, Columns);
      setRecord:
        InsertRecord(Sql, Columns);
      setInterfacedObject:
        InsertInterfacedObject(Sql, Columns);
    end;
end;

end.
