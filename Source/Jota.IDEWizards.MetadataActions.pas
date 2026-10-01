unit Jota.IDEWizards.MetadataActions;

interface

procedure LoadJotaMetadataAtStartup;
procedure ReloadJotaMetadataInteractive;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Dialogs,
  ToolsAPI,
  Jota.IDEWizards.Metadata,
  Jota.IDEWizards.Toast;

const
  ToastDurationMs = 5000;

procedure QueueToast(const AMessage: string);
begin
  TThread.ForceQueue(nil,
    procedure
    begin
      ShowToast(AMessage, ToastDurationMs);
    end);
end;

procedure LoadJotaMetadataAtStartup;
begin
  if SplashScreenServices <> nil then
    SplashScreenServices.StatusMessage('Jota IDE Wizards: carregando metadados da base de trabalho...');

  case LoadJotaMetadata of
    mlrLoaded:
      QueueToast('Metadados carregados: ' + JotaMetadata.Summary);
    mlrFailed:
      QueueToast('Falha ao carregar metadados: ' + JotaMetadataLastError);
  end;
end;

procedure ReloadJotaMetadataInteractive;
var
  LoadResult: TJotaMetadataLoadResult;
begin
  Screen.Cursor := crHourGlass;
  try
    LoadResult := LoadJotaMetadata;
  finally
    Screen.Cursor := crDefault;
  end;

  case LoadResult of
    mlrLoaded:
      ShowToast('Metadados carregados: ' + JotaMetadata.Summary, ToastDurationMs);
    mlrNotConfigured:
      MessageDlg('A base de dados de trabalho não está configurada.' + sLineBreak +
        'Use "1 - Configurar" no menu Ctrl+Shift+J.', mtInformation, [mbOK], 0);
    mlrFailed:
      MessageDlg('Não foi possível carregar os metadados da base de trabalho:' +
        sLineBreak + sLineBreak + JotaMetadataLastError, mtError, [mbOK], 0);
  end;
end;

end.
