unit Jota.IDEWizards.SequenceWizard;

interface

procedure RunNewSequenceWizard;

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
  Vcl.Clipbrd,
  Jota.IDEWizards.Config,
  Jota.IDEWizards.OTAUtils,
  Jota.IDEWizards.Sequence,
  Jota.IDEWizards.SequenceDialog,
  Jota.IDEWizards.Toast;

function ChooseSequenceKind(out AKind: TJotaSequenceKind): Boolean;
var
  Menu: TPopupMenu;
  Item: TMenuItem;
  Kind: TJotaSequenceKind;
  P: TPoint;
  Cmd: Integer;
begin
  Result := False;
  AKind := Low(TJotaSequenceKind);
  Menu := TPopupMenu.Create(nil);
  try
    for Kind := Low(TJotaSequenceKind) to High(TJotaSequenceKind) do
    begin
      Item := TMenuItem.Create(Menu);
      Item.Caption := '&' + IntToStr(Ord(Kind) + 1) + ' - ' + SequenceKindCaptions[Kind];
      Item.Tag := Ord(Kind);
      Menu.Items.Add(Item);
    end;

    P := GetEditorPopupPoint;
    Cmd := Integer(TrackPopupMenuEx(Menu.Handle,
      TPM_LEFTALIGN or TPM_TOPALIGN or TPM_RIGHTBUTTON or TPM_RETURNCMD,
      P.X, P.Y, PopupList.Window, nil));

    if Cmd <> 0 then
    begin
      Item := Menu.FindItem(Cmd, fkCommand);
      if Item <> nil then
      begin
        AKind := TJotaSequenceKind(Item.Tag);
        Result := True;
      end;
    end;
  finally
    Menu.Free;
  end;
end;

function TryRunSequence(const AConfig: TJotaBaseDadosSequencias; const AVendorLib: string;
  const ADefinition: TJotaSequenceDefinition; const AValues: TArray<string>): Boolean;
var
  Script, FileName: string;
  Created: Boolean;
begin
  Result := False;
  Script := '';
  Screen.Cursor := crHourGlass;
  try
    try
      Script := ExecuteSequenceFunction(AConfig, AVendorLib, ADefinition, AValues);
      FileName := AppendScriptToFile(AConfig.PastaArquivosScript, AConfig.PrefixoArquivosScript,
        Script, Created);
      Result := True;
      Screen.Cursor := crDefault;
      if Created then
        ShowToast('Script gravado no novo arquivo ' + ExtractFileName(FileName), 5000)
      else
        ShowToast('Script adicionado em ' + ExtractFileName(FileName), 5000);
    except
      on E: Exception do
      begin
        Screen.Cursor := crDefault;
        if Script = '' then
          MessageDlg('Não foi possível gerar a sequência:' + sLineBreak + sLineBreak + E.Message,
            mtError, [mbOK], 0)
        else
        begin
          Clipboard.AsText := Script;
          Result := True;
          MessageDlg('A sequência foi gerada, mas não foi possível gravar o arquivo de script:' +
            sLineBreak + sLineBreak + E.Message + sLineBreak + sLineBreak +
            'O script foi copiado para a área de transferência.', mtError, [mbOK], 0);
        end;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure RunNewSequenceWizard;
var
  Config: TJotaBaseDadosSequencias;
  ConfigError, VendorLib: string;
  Kind: TJotaSequenceKind;
  Definition: TJotaSequenceDefinition;
  Values: TArray<string>;
  Done: Boolean;
begin
  try
    Config := LoadBaseDadosSequencias;
    VendorLib := LoadBaseDadosTrabalho.ActiveVendorLib;
    ConfigError := ValidateSequenceConfig(Config);
  except
    on E: Exception do
      ConfigError := E.Message;
  end;

  if ConfigError <> '' then
    MessageDlg(ConfigError + sLineBreak + 'Use "1 - Configurar" no menu Ctrl+Shift+J.',
      mtWarning, [mbOK], 0)
  else if ChooseSequenceKind(Kind) then
  begin
    Definition := GetSequenceDefinition(Kind);
    Values := nil;
    Done := False;
    while not Done and ExecuteSequenceDialog(Definition, Values) do
      Done := TryRunSequence(Config, VendorLib, Definition, Values);
  end;
end;

end.
