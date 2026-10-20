unit Jota.IDEWizards.ConfigDialog;

interface

function ExecuteConfigDialog: Boolean;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Winapi.Windows,
  Winapi.ShellAPI,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Graphics,
  Vcl.Dialogs,
  Vcl.FileCtrl,
  FireDAC.Comp.Client,
  Jota.IDEWizards.Config,
  Jota.IDEWizards.Metadata,
  Jota.IDEWizards.Theming;

const
  Margin = 16;
  GroupPadding = 12;
  GroupTopPadding = 24;
  LabelWidth = 120;
  ControlWidth = 260;
  RowHeight = 30;
  ButtonWidth = 100;
  ButtonHeight = 28;
  BrowseButtonWidth = 28;
  PasswordMask = '*';

type
  TJotaConnectionEdits = record
    Host: TEdit;
    Porta: TEdit;
    NomeBD: TEdit;
    Usuario: TEdit;
    Senha: TEdit;
    MostrarSenha: TCheckBox;
  end;

  TJotaConfigForm = class(TForm)
  private
    FRowTop: Integer;
    FGroup: TGroupBox;
    gbBaseDadosTrabalho: TGroupBox;
    gbBaseDadosSequencias: TGroupBox;
    FTrabalho: TJotaConnectionEdits;
    FSequencias: TJotaConnectionEdits;
    edVendorLib32: TEdit;
    btnVendorLib32: TButton;
    edVendorLib64: TEdit;
    btnVendorLib64: TButton;
    edAplicacaoPreConexao: TEdit;
    btnAplicacaoPreConexao: TButton;
    edPrefixoArquivosScript: TEdit;
    edPastaArquivosScript: TEdit;
    btnPastaArquivosScript: TButton;
    function CreateGroup(const ACaption: string; ALeft: Integer): TGroupBox;
    function AddRow(const ACaption: string; AWidth: Integer = ControlWidth): TEdit;
    function AddBrowseRow(const ACaption: string; AOnClick: TNotifyEvent;
      out AButton: TButton): TEdit;
    function AddConnectionRows: TJotaConnectionEdits;
    function CheckVendorLib(AEdit: TEdit; const AFileName: string;
      AMachine: Word; const ABits: string): Boolean;
    function ValidateConnection(const AEdits: TJotaConnectionEdits; const AHost: string;
      APorta: Integer; const ANomeBD, AUsuario: string; ARequired: Boolean): Boolean;
    procedure MostrarSenhaClick(Sender: TObject);
    procedure VendorLibBrowseClick(Sender: TObject);
    procedure AplicacaoPreConexaoBrowseClick(Sender: TObject);
    procedure PastaArquivosScriptBrowseClick(Sender: TObject);
    procedure TestarSequenciasClick(Sender: TObject);
    procedure OpenConfigFolderClick(Sender: TObject);
    procedure FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
    procedure Fail(AControl: TWinControl; const AMessage: string);
    function Validate(const ATrabalho: TJotaBaseDadosTrabalho;
      const ASequencias: TJotaBaseDadosSequencias): Boolean;
    function TrySave(const ATrabalho: TJotaBaseDadosTrabalho;
      const ASequencias: TJotaBaseDadosSequencias): Boolean;
    function GetTrabalho: TJotaBaseDadosTrabalho;
    function GetSequencias: TJotaBaseDadosSequencias;
    procedure SetConfig(const ATrabalho: TJotaBaseDadosTrabalho;
      const ASequencias: TJotaBaseDadosSequencias);
  public
    constructor CreateDialog;
  end;

function GetConnectionText(AEdit: TEdit): string;
begin
  Result := Trim(AEdit.Text);
end;

function GetPortaValue(AEdit: TEdit): Integer;
begin
  Result := StrToIntDef(Trim(AEdit.Text), 0);
end;

procedure SetPortaValue(AEdit: TEdit; APorta: Integer);
begin
  if APorta > 0 then
    AEdit.Text := IntToStr(APorta)
  else
    AEdit.Text := '';
end;

constructor TJotaConfigForm.CreateDialog;
var
  BtnOk, BtnCancel, BtnOpenFolder, BtnTestar: TButton;
  lblArquivo: TLabel;
  GroupWidth, GroupHeight, Y: Integer;
begin
  inherited CreateNew(nil);

  Caption := 'Jota IDE Wizards - Configurar';
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  OnCloseQuery := FormCloseQueryHandler;

  GroupWidth := GroupPadding + LabelWidth + ControlWidth + GroupPadding;
  ClientWidth := Margin + GroupWidth + Margin + GroupWidth + Margin;

  gbBaseDadosTrabalho := CreateGroup(' Base de dados de trabalho ', Margin);
  FTrabalho := AddConnectionRows;
  edVendorLib32 := AddBrowseRow('libpq &32 bits:', VendorLibBrowseClick, btnVendorLib32);
  edVendorLib32.TextHint := '(vazio = procura no PATH)';
  edVendorLib64 := AddBrowseRow('libpq &64 bits:', VendorLibBrowseClick, btnVendorLib64);
  edVendorLib64.TextHint := '(vazio = procura no PATH)';
{$IFDEF WIN64}
  edVendorLib64.Font.Style := [fsBold];
{$ELSE}
  edVendorLib32.Font.Style := [fsBold];
{$ENDIF}
  GroupHeight := FRowTop;

  gbBaseDadosSequencias := CreateGroup(' Base de dados de sequências ', Margin + GroupWidth + Margin);
  FSequencias := AddConnectionRows;
  edAplicacaoPreConexao := AddBrowseRow('Aplicação pré-&conexão:', AplicacaoPreConexaoBrowseClick,
    btnAplicacaoPreConexao);
  edAplicacaoPreConexao.TextHint := '(opcional) executada antes de conectar';
  edPrefixoArquivosScript := AddRow('Pre&fixo dos scripts:');
  edPastaArquivosScript := AddBrowseRow('Pasta dos scr&ipts:', PastaArquivosScriptBrowseClick,
    btnPastaArquivosScript);

  BtnTestar := TButton.Create(Self);
  BtnTestar.Parent := gbBaseDadosSequencias;
  BtnTestar.Caption := '&Testar conexão';
  BtnTestar.SetBounds(GroupPadding + LabelWidth, FRowTop, 120, ButtonHeight - 2);
  BtnTestar.OnClick := TestarSequenciasClick;
  Inc(FRowTop, RowHeight + 4);

  if FRowTop > GroupHeight then
    GroupHeight := FRowTop;
  gbBaseDadosTrabalho.Height := GroupHeight + GroupPadding div 2;
  gbBaseDadosSequencias.Height := GroupHeight + GroupPadding div 2;

  Y := Margin + gbBaseDadosTrabalho.Height + 8;

  lblArquivo := TLabel.Create(Self);
  lblArquivo.Parent := Self;
  lblArquivo.AutoSize := False;
  lblArquivo.WordWrap := True;
  lblArquivo.Left := Margin;
  lblArquivo.Top := Y;
  lblArquivo.Width := ClientWidth - Margin * 2;
  lblArquivo.Height := 48;
  lblArquivo.Font.Color := clGrayText;
  lblArquivo.ShowAccelChar := False;
{$IFDEF WIN64}
  lblArquivo.Caption := 'IDE de 64 bits: usa a libpq de 64 bits (também na base de sequências).' +
    sLineBreak + 'Arquivo: ' + GetJotaConfigFilePath;
{$ELSE}
  lblArquivo.Caption := 'IDE de 32 bits: usa a libpq de 32 bits (também na base de sequências).' +
    sLineBreak + 'Arquivo: ' + GetJotaConfigFilePath;
{$ENDIF}
  Inc(Y, lblArquivo.Height + 8);

  BtnCancel := TButton.Create(Self);
  BtnCancel.Parent := Self;
  BtnCancel.Caption := 'Cancelar';
  BtnCancel.Cancel := True;
  BtnCancel.ModalResult := mrCancel;
  BtnCancel.SetBounds(ClientWidth - Margin - ButtonWidth, Y, ButtonWidth, ButtonHeight);

  BtnOk := TButton.Create(Self);
  BtnOk.Parent := Self;
  BtnOk.Caption := 'OK';
  BtnOk.Default := True;
  BtnOk.ModalResult := mrOk;
  BtnOk.SetBounds(BtnCancel.Left - 8 - ButtonWidth, Y, ButtonWidth, ButtonHeight);

  BtnOpenFolder := TButton.Create(Self);
  BtnOpenFolder.Parent := Self;
  BtnOpenFolder.Caption := 'Abrir &pasta';
  BtnOpenFolder.Hint := 'Abre no Explorer a pasta do arquivo de configuração';
  BtnOpenFolder.ShowHint := True;
  BtnOpenFolder.SetBounds(Margin, Y, ButtonWidth, ButtonHeight);
  BtnOpenFolder.OnClick := OpenConfigFolderClick;

  ClientHeight := Y + ButtonHeight + Margin;

  ActiveControl := FTrabalho.Host;

  ApplyIdeMatchingStyle(Self);
end;

function TJotaConfigForm.CreateGroup(const ACaption: string; ALeft: Integer): TGroupBox;
begin
  Result := TGroupBox.Create(Self);
  Result.Parent := Self;
  Result.Caption := ACaption;
  Result.Left := ALeft;
  Result.Top := Margin;
  Result.Width := GroupPadding + LabelWidth + ControlWidth + GroupPadding;
  FGroup := Result;
  FRowTop := GroupTopPadding;
end;

function TJotaConfigForm.AddRow(const ACaption: string; AWidth: Integer): TEdit;
var
  Lbl: TLabel;
begin
  Result := TEdit.Create(Self);
  Result.Parent := FGroup;
  Result.SetBounds(GroupPadding + LabelWidth, FRowTop, AWidth, Result.Height);

  Lbl := TLabel.Create(Self);
  Lbl.Parent := FGroup;
  Lbl.Caption := ACaption;
  Lbl.Left := GroupPadding;
  Lbl.Top := FRowTop + 3;
  Lbl.FocusControl := Result;

  Inc(FRowTop, RowHeight);
end;

function TJotaConfigForm.AddBrowseRow(const ACaption: string; AOnClick: TNotifyEvent;
  out AButton: TButton): TEdit;
begin
  Result := AddRow(ACaption, ControlWidth - BrowseButtonWidth - 4);

  AButton := TButton.Create(Self);
  AButton.Parent := FGroup;
  AButton.Caption := '...';
  AButton.SetBounds(Result.Left + Result.Width + 4, Result.Top,
    BrowseButtonWidth, Result.Height);
  AButton.OnClick := AOnClick;
end;

function TJotaConfigForm.AddConnectionRows: TJotaConnectionEdits;
begin
  Result.Host := AddRow('&Host:');
  Result.Porta := AddRow('P&orta:', 70);
  Result.Porta.NumbersOnly := True;
  Result.Porta.MaxLength := 5;
  Result.NomeBD := AddRow('&NomeBD:');
  Result.Usuario := AddRow('&Usuário:');
  Result.Senha := AddRow('&Senha:');
  Result.Senha.PasswordChar := PasswordMask;

  Result.MostrarSenha := TCheckBox.Create(Self);
  Result.MostrarSenha.Parent := FGroup;
  Result.MostrarSenha.Caption := '&Mostrar senha';
  Result.MostrarSenha.Left := GroupPadding + LabelWidth;
  Result.MostrarSenha.Top := FRowTop;
  Result.MostrarSenha.Width := ControlWidth;
  Result.MostrarSenha.Tag := NativeInt(Result.Senha);
  Result.MostrarSenha.OnClick := MostrarSenhaClick;
  Inc(FRowTop, RowHeight);
end;

procedure TJotaConfigForm.MostrarSenhaClick(Sender: TObject);
var
  CheckBox: TCheckBox;
  SenhaEdit: TEdit;
begin
  CheckBox := Sender as TCheckBox;
  SenhaEdit := TEdit(CheckBox.Tag);
  if CheckBox.Checked then
    SenhaEdit.PasswordChar := #0
  else
    SenhaEdit.PasswordChar := PasswordMask;
end;

function ReadDllMachine(const AFileName: string): Word;
var
  Stream: TFileStream;
  PEOffset: Cardinal;
  Signature: Cardinal;
begin
  Result := 0;
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    if Stream.Size > $40 then
    begin
      Stream.Position := $3C;
      Stream.ReadBuffer(PEOffset, SizeOf(PEOffset));
      if Stream.Size > Int64(PEOffset) + 6 then
      begin
        Stream.Position := PEOffset;
        Stream.ReadBuffer(Signature, SizeOf(Signature));
        if Signature = $00004550 then
          Stream.ReadBuffer(Result, SizeOf(Result));
      end;
    end;
  finally
    Stream.Free;
  end;
end;

procedure BrowseFile(AOwner: TComponent; AEdit: TEdit; const ATitle, AFilter: string);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(AOwner);
  try
    Dialog.Title := ATitle;
    Dialog.Filter := AFilter;
    Dialog.Options := Dialog.Options + [ofFileMustExist, ofPathMustExist];
    if AEdit.Text <> '' then
    begin
      Dialog.InitialDir := ExtractFilePath(AEdit.Text);
      Dialog.FileName := ExtractFileName(AEdit.Text);
    end;
    if Dialog.Execute then
      AEdit.Text := Dialog.FileName;
  finally
    Dialog.Free;
  end;
end;

procedure TJotaConfigForm.VendorLibBrowseClick(Sender: TObject);
begin
  if Sender = btnVendorLib64 then
    BrowseFile(Self, edVendorLib64, 'Selecione a libpq.dll de 64 bits',
      'libpq.dll|libpq.dll|Bibliotecas (*.dll)|*.dll')
  else
    BrowseFile(Self, edVendorLib32, 'Selecione a libpq.dll de 32 bits',
      'libpq.dll|libpq.dll|Bibliotecas (*.dll)|*.dll');
end;

procedure TJotaConfigForm.AplicacaoPreConexaoBrowseClick(Sender: TObject);
begin
  BrowseFile(Self, edAplicacaoPreConexao, 'Selecione a aplicação pré-conexão',
    'Executáveis (*.exe;*.bat;*.cmd)|*.exe;*.bat;*.cmd|Todos os arquivos (*.*)|*.*');
end;

procedure TJotaConfigForm.PastaArquivosScriptBrowseClick(Sender: TObject);
var
  Folder: string;
begin
  Folder := Trim(edPastaArquivosScript.Text);
  if SelectDirectory('Selecione a pasta dos arquivos de script', '', Folder,
    [sdNewUI, sdNewFolder], Self) then
    edPastaArquivosScript.Text := Folder;
end;

procedure TJotaConfigForm.TestarSequenciasClick(Sender: TObject);
var
  Sequencias: TJotaBaseDadosSequencias;
  Connection: TFDConnection;
  UsesSsl: Boolean;
  Info: string;
begin
  Sequencias := GetSequencias;
  if ValidateConnection(FSequencias, Sequencias.Host, Sequencias.Porta, Sequencias.NomeBD,
    Sequencias.Usuario, True) then
  begin
    Screen.Cursor := crHourGlass;
    try
      try
        Connection := CreateBaseDadosSequenciasConnection(Sequencias,
          GetTrabalho.ActiveVendorLib, UsesSsl);
        try
          Connection.Connected := True;
          Connection.Connected := False;
        finally
          Connection.Free;
        end;
        if UsesSsl then
          Info := 'Conexão OK (SSL require com ca.crt, client.crt e client.key).'
        else
          Info := 'Conexão OK (sem certificados de cliente).';
        Screen.Cursor := crDefault;
        MessageDlg(Info, mtInformation, [mbOK], 0);
      except
        on E: Exception do
        begin
          Screen.Cursor := crDefault;
          MessageDlg('Falha ao conectar na base de dados de sequências:' + sLineBreak + sLineBreak +
            E.Message, mtError, [mbOK], 0);
        end;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
  end;
end;

procedure TJotaConfigForm.OpenConfigFolderClick(Sender: TObject);
var
  FilePath, Parameters: string;
begin
  FilePath := GetJotaConfigFilePath;
  ForceDirectories(ExtractFilePath(FilePath));
  if FileExists(FilePath) then
    Parameters := '/select,"' + FilePath + '"'
  else
    Parameters := '"' + ExtractFilePath(FilePath) + '"';
  ShellExecute(Handle, 'open', 'explorer.exe', PChar(Parameters), nil, SW_SHOWNORMAL);
end;

function TJotaConfigForm.GetTrabalho: TJotaBaseDadosTrabalho;
begin
  Result.Host := GetConnectionText(FTrabalho.Host);
  Result.Porta := GetPortaValue(FTrabalho.Porta);
  Result.NomeBD := GetConnectionText(FTrabalho.NomeBD);
  Result.Usuario := GetConnectionText(FTrabalho.Usuario);
  Result.Senha := FTrabalho.Senha.Text;
  Result.VendorLib32 := Trim(edVendorLib32.Text);
  Result.VendorLib64 := Trim(edVendorLib64.Text);
end;

function TJotaConfigForm.GetSequencias: TJotaBaseDadosSequencias;
begin
  Result.Host := GetConnectionText(FSequencias.Host);
  Result.Porta := GetPortaValue(FSequencias.Porta);
  Result.NomeBD := GetConnectionText(FSequencias.NomeBD);
  Result.Usuario := GetConnectionText(FSequencias.Usuario);
  Result.Senha := FSequencias.Senha.Text;
  Result.AplicacaoPreConexao := Trim(edAplicacaoPreConexao.Text);
  Result.PrefixoArquivosScript := Trim(edPrefixoArquivosScript.Text);
  Result.PastaArquivosScript := Trim(edPastaArquivosScript.Text);
end;

procedure TJotaConfigForm.SetConfig(const ATrabalho: TJotaBaseDadosTrabalho;
  const ASequencias: TJotaBaseDadosSequencias);
begin
  FTrabalho.Host.Text := ATrabalho.Host;
  SetPortaValue(FTrabalho.Porta, ATrabalho.Porta);
  FTrabalho.NomeBD.Text := ATrabalho.NomeBD;
  FTrabalho.Usuario.Text := ATrabalho.Usuario;
  FTrabalho.Senha.Text := ATrabalho.Senha;
  edVendorLib32.Text := ATrabalho.VendorLib32;
  edVendorLib64.Text := ATrabalho.VendorLib64;

  FSequencias.Host.Text := ASequencias.Host;
  SetPortaValue(FSequencias.Porta, ASequencias.Porta);
  FSequencias.NomeBD.Text := ASequencias.NomeBD;
  FSequencias.Usuario.Text := ASequencias.Usuario;
  FSequencias.Senha.Text := ASequencias.Senha;
  edAplicacaoPreConexao.Text := ASequencias.AplicacaoPreConexao;
  edPrefixoArquivosScript.Text := ASequencias.PrefixoArquivosScript;
  edPastaArquivosScript.Text := ASequencias.PastaArquivosScript;
end;

procedure TJotaConfigForm.Fail(AControl: TWinControl; const AMessage: string);
begin
  MessageDlg(AMessage, mtWarning, [mbOK], 0);
  if AControl.CanFocus then
    AControl.SetFocus;
end;

function TJotaConfigForm.ValidateConnection(const AEdits: TJotaConnectionEdits;
  const AHost: string; APorta: Integer; const ANomeBD, AUsuario: string;
  ARequired: Boolean): Boolean;
begin
  Result := False;
  if not ARequired and (AHost = '') and (ANomeBD = '') and (AUsuario = '') then
    Result := True
  else if AHost = '' then
    Fail(AEdits.Host, 'Informe o Host.')
  else if (APorta < 1) or (APorta > 65535) then
    Fail(AEdits.Porta, 'Porta deve estar entre 1 e 65535 (padrão do PostgreSQL: 5432).')
  else if ANomeBD = '' then
    Fail(AEdits.NomeBD, 'Informe o NomeBD.')
  else if AUsuario = '' then
    Fail(AEdits.Usuario, 'Informe o Usuário.')
  else
    Result := True;
end;

function TJotaConfigForm.Validate(const ATrabalho: TJotaBaseDadosTrabalho;
  const ASequencias: TJotaBaseDadosSequencias): Boolean;
begin
  Result := False;
  if not ValidateConnection(FTrabalho, ATrabalho.Host, ATrabalho.Porta, ATrabalho.NomeBD,
    ATrabalho.Usuario, True) then
    Result := False
  else if not CheckVendorLib(edVendorLib32, ATrabalho.VendorLib32, IMAGE_FILE_MACHINE_I386, '32') then
    Result := False
  else if not CheckVendorLib(edVendorLib64, ATrabalho.VendorLib64, IMAGE_FILE_MACHINE_AMD64, '64') then
    Result := False
  else if not ValidateConnection(FSequencias, ASequencias.Host, ASequencias.Porta,
    ASequencias.NomeBD, ASequencias.Usuario, False) then
    Result := False
  else if (ASequencias.AplicacaoPreConexao <> '') and not FileExists(ASequencias.AplicacaoPreConexao) then
    Fail(edAplicacaoPreConexao, 'Aplicação pré-conexão não encontrada:' + sLineBreak +
      ASequencias.AplicacaoPreConexao)
  else if (ASequencias.PastaArquivosScript <> '') and not DirectoryExists(ASequencias.PastaArquivosScript) then
    Fail(edPastaArquivosScript, 'Pasta dos scripts não encontrada:' + sLineBreak +
      ASequencias.PastaArquivosScript)
  else
    Result := True;
end;

function TJotaConfigForm.CheckVendorLib(AEdit: TEdit; const AFileName: string;
  AMachine: Word; const ABits: string): Boolean;
begin
  Result := False;
  if AFileName = '' then
    Result := True
  else if not FileExists(AFileName) then
    Fail(AEdit, 'Arquivo não encontrado:' + sLineBreak + AFileName)
  else if ReadDllMachine(AFileName) <> AMachine then
    Fail(AEdit, Format('A DLL informada em "libpq %s bits" não é de %s bits:',
      [ABits, ABits]) + sLineBreak + AFileName)
  else
    Result := True;
end;

function TJotaConfigForm.TrySave(const ATrabalho: TJotaBaseDadosTrabalho;
  const ASequencias: TJotaBaseDadosSequencias): Boolean;
begin
  try
    SaveJotaConfig(ATrabalho, ASequencias);
    Result := True;
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível salvar as configurações:' + sLineBreak +
        E.Message, mtError, [mbOK], 0);
      Result := False;
    end;
  end;
end;

procedure TJotaConfigForm.FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
var
  Trabalho: TJotaBaseDadosTrabalho;
  Sequencias: TJotaBaseDadosSequencias;
begin
  if ModalResult = mrOk then
  begin
    Trabalho := GetTrabalho;
    Sequencias := GetSequencias;
    CanClose := Validate(Trabalho, Sequencias) and TrySave(Trabalho, Sequencias);
  end;
end;

function ExecuteConfigDialog: Boolean;
var
  DlgForm: TJotaConfigForm;
  Trabalho: TJotaBaseDadosTrabalho;
  Sequencias: TJotaBaseDadosSequencias;
begin
  try
    Trabalho := LoadBaseDadosTrabalho;
    Sequencias := LoadBaseDadosSequencias;
  except
    on E: Exception do
    begin
      MessageDlg(E.Message + sLineBreak + sLineBreak +
        'Os valores padrão serão usados. Ao salvar, o arquivo atual será ' +
        'preservado com a extensão .bak.', mtWarning, [mbOK], 0);
      Trabalho := TJotaBaseDadosTrabalho.Default;
      Sequencias := TJotaBaseDadosSequencias.Default;
    end;
  end;

  DlgForm := TJotaConfigForm.CreateDialog;
  try
    DlgForm.SetConfig(Trabalho, Sequencias);
    Result := DlgForm.ShowModal = mrOk;
  finally
    DlgForm.Free;
  end;
end;

end.
