unit Jota.IDEWizards.TableScriptWizard;

interface

procedure RunTableScriptWizard;

implementation

uses
  System.SysUtils,
  System.UITypes,
  Vcl.Dialogs,
  Jota.IDEWizards.OTAUtils,
  Jota.IDEWizards.Metadata,
  Jota.IDEWizards.MetadataActions,
  Jota.IDEWizards.TableScript,
  Jota.IDEWizards.TableScriptDialog,
  Jota.IDEWizards.Toast;

var
  GLastKinds: TJotaTableScriptKinds = [tskInsert, tskUpsert, tskUpdate, tskDelete];
  GLastReplaceMethods: Boolean = False;

procedure InsertTableScripts(ATable: TJotaMetaTable; AKinds: TJotaTableScriptKinds;
  AReplaceMethods: Boolean);
var
  Scripts, Skipped: string;
begin
  Scripts := GenerateTableScripts(ATable, AKinds, StringOfChar(' ', GetCursorColumn - 1),
    AReplaceMethods, Skipped);
  if Scripts = '' then
    MessageDlg('Nenhum script gerado:' + sLineBreak + Skipped, mtWarning, [mbOK], 0)
  else if not InsertTextAtCursor(Scripts) then
    MessageDlg('Nenhum editor de código ativo para inserir os scripts.', mtWarning, [mbOK], 0)
  else if Skipped <> '' then
    MessageDlg('Scripts gerados para ' + ATable.FullName + '. Não gerados:' + sLineBreak +
      Skipped, mtInformation, [mbOK], 0)
  else
    ShowToast('Scripts gerados para ' + ATable.FullName);
end;

procedure RunTableScriptWizard;
var
  Table: TJotaMetaTable;
  Kinds: TJotaTableScriptKinds;
  ReplaceMethods: Boolean;
begin
  if JotaMetadata = nil then
    ReloadJotaMetadataInteractive;

  if JotaMetadata <> nil then
  begin
    Kinds := GLastKinds;
    ReplaceMethods := GLastReplaceMethods;
    if ExecuteTableScriptDialog(JotaMetadata, Table, Kinds, ReplaceMethods) then
    begin
      GLastKinds := Kinds;
      GLastReplaceMethods := ReplaceMethods;
      InsertTableScripts(Table, Kinds, ReplaceMethods);
    end;
  end;
end;

end.
