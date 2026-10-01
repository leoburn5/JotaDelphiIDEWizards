unit Jota.IDEWizards.ConfigDialog;

interface

function ExecuteConfigDialog: Boolean;

implementation

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Graphics,
  Vcl.Dialogs,
  Jota.IDEWizards.Config,
  Jota.IDEWizards.Theming;

const
  Margin = 16;
  GroupPadding = 12;
  GroupTopPadding = 24;
  LabelWidth = 100;
  ControlWidth = 260;
  RowHeight = 30;
  ButtonWidth = 90;
  ButtonHeight = 28;
  BrowseButtonWidth = 28;
  PasswordMask = '*';

type
  TJotaConfigForm = class(TForm)
  private
    FRowTop: Integer;
    gbBaseDadosTrabalho: TGroupBox;
    edHost: TEdit;
    edPorta: TEdit;
    edNomeBD: TEdit;
    edUsuario: TEdit;
    edSenha: TEdit;
    chkMostrarSenha: TCheckBox;
    edVendorLib32: TEdit;
    btnVendorLib32: TButton;
    edVendorLib64: TEdit;
    btnVendorLib64: TButton;
    function AddRow(const ACaption: string; AWidth: Integer = ControlWidth): TEdit;
    function AddVendorLibRow(const ACaption: string; out AButton: TButton): TEdit;
    function CheckVendorLib(AEdit: TEdit; const AFileName: string;
      AMachine: Word; const ABits: string): Boolean;
    procedure MostrarSenhaClick(Sender: TObject);
    procedure VendorLibBrowseClick(Sender: TObject);
    procedure FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
    procedure Fail(AControl: TWinControl; const AMessage: string);
    function Validate(const AConfig: TJotaBaseDadosTrabalho): Boolean;
    function TrySave(const AConfig: TJotaBaseDadosTrabalho): Boolean;
    function GetConfig: TJotaBaseDadosTrabalho;
    procedure SetConfig(const AConfig: TJotaBaseDadosTrabalho);
  public
    constructor CreateDialog;
  end;

constructor TJotaConfigForm.CreateDialog;
var
  BtnOk, BtnCancel: TButton;
  lblArquivo: TLabel;
  GroupWidth, Y: Integer;
begin
  inherited CreateNew(nil);

  Caption := 'Jota IDE Wizards - Configurar';
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  OnCloseQuery := FormCloseQueryHandler;

  GroupWidth := GroupPadding + LabelWidth + ControlWidth + GroupPadding;
  ClientWidth := Margin + GroupWidth + Margin;

  gbBaseDadosTrabalho := TGroupBox.Create(Self);
  gbBaseDadosTrabalho.Parent := Self;
  gbBaseDadosTrabalho.Caption := ' Base de dados de trabalho ';
  gbBaseDadosTrabalho.Left := Margin;
  gbBaseDadosTrabalho.Top := Margin;
  gbBaseDadosTrabalho.Width := GroupWidth;

  FRowTop := GroupTopPadding;
  edHost := AddRow('&Host:');
  edPorta := AddRow('&Porta:', 70);
  edPorta.NumbersOnly := True;
  edPorta.MaxLength := 5;
  edNomeBD := AddRow('&NomeBD:');
  edUsuario := AddRow('&Usuário:');
  edSenha := AddRow('&Senha:');
  edSenha.PasswordChar := PasswordMask;

  chkMostrarSenha := TCheckBox.Create(Self);
  chkMostrarSenha.Parent := gbBaseDadosTrabalho;
  chkMostrarSenha.Caption := '&Mostrar senha';
  chkMostrarSenha.Left := GroupPadding + LabelWidth;
  chkMostrarSenha.Top := FRowTop;
  chkMostrarSenha.Width := ControlWidth;
  chkMostrarSenha.OnClick := MostrarSenhaClick;
  Inc(FRowTop, RowHeight);

  edVendorLib32 := AddVendorLibRow('libpq &32 bits:', btnVendorLib32);
  edVendorLib64 := AddVendorLibRow('libpq &64 bits:', btnVendorLib64);
{$IFDEF WIN64}
  edVendorLib64.Font.Style := [fsBold];
{$ELSE}
  edVendorLib32.Font.Style := [fsBold];
{$ENDIF}

  gbBaseDadosTrabalho.Height := FRowTop + GroupPadding div 2;
  Y := gbBaseDadosTrabalho.Top + gbBaseDadosTrabalho.Height + 8;

  lblArquivo := TLabel.Create(Self);
  lblArquivo.Parent := Self;
  lblArquivo.AutoSize := False;
  lblArquivo.WordWrap := True;
  lblArquivo.Left := Margin;
  lblArquivo.Top := Y;
  lblArquivo.Width := GroupWidth;
  lblArquivo.Height := 48;
  lblArquivo.Font.Color := clGrayText;
  lblArquivo.ShowAccelChar := False;
{$IFDEF WIN64}
  lblArquivo.Caption := 'IDE de 64 bits: usa a libpq de 64 bits.' + sLineBreak +
    'Arquivo: ' + GetJotaConfigFilePath;
{$ELSE}
  lblArquivo.Caption := 'IDE de 32 bits: usa a libpq de 32 bits.' + sLineBreak +
    'Arquivo: ' + GetJotaConfigFilePath;
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

  ClientHeight := Y + ButtonHeight + Margin;

  ActiveControl := edHost;

  ApplyIdeMatchingStyle(Self);
end;

function TJotaConfigForm.AddRow(const ACaption: string; AWidth: Integer): TEdit;
var
  Lbl: TLabel;
begin
  Result := TEdit.Create(Self);
  Result.Parent := gbBaseDadosTrabalho;
  Result.SetBounds(GroupPadding + LabelWidth, FRowTop, AWidth, Result.Height);

  Lbl := TLabel.Create(Self);
  Lbl.Parent := gbBaseDadosTrabalho;
  Lbl.Caption := ACaption;
  Lbl.Left := GroupPadding;
  Lbl.Top := FRowTop + 3;
  Lbl.FocusControl := Result;

  Inc(FRowTop, RowHeight);
end;

procedure TJotaConfigForm.MostrarSenhaClick(Sender: TObject);
begin
  if chkMostrarSenha.Checked then
    edSenha.PasswordChar := #0
  else
    edSenha.PasswordChar := PasswordMask;
end;

function TJotaConfigForm.AddVendorLibRow(const ACaption: string; out AButton: TButton): TEdit;
begin
  Result := AddRow(ACaption, ControlWidth - BrowseButtonWidth - 4);
  Result.TextHint := '(vazio = procura no PATH)';

  AButton := TButton.Create(Self);
  AButton.Parent := gbBaseDadosTrabalho;
  AButton.Caption := '...';
  AButton.SetBounds(Result.Left + Result.Width + 4, Result.Top,
    BrowseButtonWidth, Result.Height);
  AButton.OnClick := VendorLibBrowseClick;
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

procedure TJotaConfigForm.VendorLibBrowseClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  edVendorLib: TEdit;
begin
  if Sender = btnVendorLib64 then
    edVendorLib := edVendorLib64
  else
    edVendorLib := edVendorLib32;

  Dialog := TOpenDialog.Create(Self);
  try
    if edVendorLib = edVendorLib64 then
      Dialog.Title := 'Selecione a libpq.dll de 64 bits'
    else
      Dialog.Title := 'Selecione a libpq.dll de 32 bits';
    Dialog.Filter := 'libpq.dll|libpq.dll|Bibliotecas (*.dll)|*.dll';
    Dialog.Options := Dialog.Options + [ofFileMustExist, ofPathMustExist];
    if edVendorLib.Text <> '' then
    begin
      Dialog.InitialDir := ExtractFilePath(edVendorLib.Text);
      Dialog.FileName := ExtractFileName(edVendorLib.Text);
    end;
    if Dialog.Execute then
      edVendorLib.Text := Dialog.FileName;
  finally
    Dialog.Free;
  end;
end;

function TJotaConfigForm.GetConfig: TJotaBaseDadosTrabalho;
begin
  Result.Host := Trim(edHost.Text);
  Result.Porta := StrToIntDef(Trim(edPorta.Text), 0);
  Result.NomeBD := Trim(edNomeBD.Text);
  Result.Usuario := Trim(edUsuario.Text);
  Result.Senha := edSenha.Text;
  Result.VendorLib32 := Trim(edVendorLib32.Text);
  Result.VendorLib64 := Trim(edVendorLib64.Text);
end;

procedure TJotaConfigForm.SetConfig(const AConfig: TJotaBaseDadosTrabalho);
begin
  edHost.Text := AConfig.Host;
  if AConfig.Porta > 0 then
    edPorta.Text := IntToStr(AConfig.Porta)
  else
    edPorta.Text := '';
  edNomeBD.Text := AConfig.NomeBD;
  edUsuario.Text := AConfig.Usuario;
  edSenha.Text := AConfig.Senha;
  edVendorLib32.Text := AConfig.VendorLib32;
  edVendorLib64.Text := AConfig.VendorLib64;
end;

procedure TJotaConfigForm.Fail(AControl: TWinControl; const AMessage: string);
begin
  MessageDlg(AMessage, mtWarning, [mbOK], 0);
  if AControl.CanFocus then
    AControl.SetFocus;
end;

function TJotaConfigForm.Validate(const AConfig: TJotaBaseDadosTrabalho): Boolean;
begin
  Result := False;
  if AConfig.Host = '' then
    Fail(edHost, 'Informe o Host.')
  else if (AConfig.Porta < 1) or (AConfig.Porta > 65535) then
    Fail(edPorta, 'Porta deve estar entre 1 e 65535 (padrão do PostgreSQL: 5432).')
  else if AConfig.NomeBD = '' then
    Fail(edNomeBD, 'Informe o NomeBD.')
  else if AConfig.Usuario = '' then
    Fail(edUsuario, 'Informe o Usuário.')
  else
    Result := CheckVendorLib(edVendorLib32, AConfig.VendorLib32, IMAGE_FILE_MACHINE_I386, '32') and
      CheckVendorLib(edVendorLib64, AConfig.VendorLib64, IMAGE_FILE_MACHINE_AMD64, '64');
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

function TJotaConfigForm.TrySave(const AConfig: TJotaBaseDadosTrabalho): Boolean;
begin
  try
    SaveBaseDadosTrabalho(AConfig);
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
  Config: TJotaBaseDadosTrabalho;
begin
  if ModalResult = mrOk then
  begin
    Config := GetConfig;
    CanClose := Validate(Config) and TrySave(Config);
  end;
end;

function ExecuteConfigDialog: Boolean;
var
  DlgForm: TJotaConfigForm;
  Config: TJotaBaseDadosTrabalho;
begin
  try
    Config := LoadBaseDadosTrabalho;
  except
    on E: Exception do
    begin
      MessageDlg(E.Message + sLineBreak + sLineBreak +
        'Os valores padrão serão usados. Ao salvar, o arquivo atual será ' +
        'preservado com a extensão .bak.', mtWarning, [mbOK], 0);
      Config := TJotaBaseDadosTrabalho.Default;
    end;
  end;

  DlgForm := TJotaConfigForm.CreateDialog;
  try
    DlgForm.SetConfig(Config);
    Result := DlgForm.ShowModal = mrOk;
  finally
    DlgForm.Free;
  end;
end;

end.
