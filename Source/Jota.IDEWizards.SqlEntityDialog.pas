unit Jota.IDEWizards.SqlEntityDialog;

interface

function ExecuteSqlEntityDialog(var ASql: string): Boolean;
function AskEntityClassName(var AClassName: string; const ATitle, ALabel: string): Boolean;
function AskInterfacedNames(var AClassName, AInterfaceName: string): Boolean;
function SuggestInterfaceName(const AClassName: string): string;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Graphics,
  Vcl.Dialogs,
  Jota.IDEWizards.Theming;

const
  Margin = 16;
  ButtonWidth = 100;
  ButtonHeight = 28;

type
  TJotaSqlEntityForm = class(TForm)
  private
    mmSql: TMemo;
    procedure FormKeyDownHandler(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyPressHandler(Sender: TObject; var Key: Char);
    procedure FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
  public
    constructor CreateDialog(const ASql: string);
  end;

  TJotaEntityClassNameForm = class(TForm)
  private
    edClassName: TEdit;
    procedure FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
  public
    constructor CreateDialog(const AClassName, ATitle, ALabel: string);
  end;

  TJotaInterfacedNamesForm = class(TForm)
  private
    FLastAutoInterfaceName: string;
    edClassName: TEdit;
    edInterfaceName: TEdit;
    procedure ClassNameChange(Sender: TObject);
    procedure FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
  public
    constructor CreateDialog(const AClassName, AInterfaceName: string);
  end;

procedure Fail(AControl: TWinControl; const AMessage: string);
begin
  MessageDlg(AMessage, mtWarning, [mbOK], 0);
  if AControl.CanFocus then
    AControl.SetFocus;
end;

constructor TJotaSqlEntityForm.CreateDialog(const ASql: string);
var
  lblSql, lblHint: TLabel;
  BtnOk, BtnCancel: TButton;
begin
  inherited CreateNew(nil);

  Caption := 'Jota IDE Wizards - SQL Query para Entidade';
  BorderStyle := bsSizeable;
  BorderIcons := [biSystemMenu, biMaximize];
  Position := poScreenCenter;
  ClientWidth := 680;
  ClientHeight := 440;
  Constraints.MinWidth := 420;
  Constraints.MinHeight := 280;
  KeyPreview := True;
  OnKeyDown := FormKeyDownHandler;
  OnKeyPress := FormKeyPressHandler;
  OnCloseQuery := FormCloseQueryHandler;

  lblSql := TLabel.Create(Self);
  lblSql.Parent := Self;
  lblSql.Caption := '&Consulta SQL:';
  lblSql.Left := Margin;
  lblSql.Top := Margin;

  mmSql := TMemo.Create(Self);
  mmSql.Parent := Self;
  mmSql.SetBounds(Margin, lblSql.Top + lblSql.Height + 4, ClientWidth - Margin * 2,
    ClientHeight - (lblSql.Top + lblSql.Height + 4) - ButtonHeight - Margin * 2);
  mmSql.Anchors := [akLeft, akTop, akRight, akBottom];
  mmSql.Font.Name := 'Consolas';
  mmSql.Font.Size := 10;
  mmSql.ScrollBars := ssBoth;
  mmSql.WordWrap := False;
  mmSql.WantTabs := True;
  mmSql.Text := ASql;
  lblSql.FocusControl := mmSql;

  lblHint := TLabel.Create(Self);
  lblHint.Parent := Self;
  lblHint.Caption := 'Ctrl+Enter confirma';
  lblHint.Font.Color := clGrayText;
  lblHint.Left := Margin;
  lblHint.Top := ClientHeight - Margin - ButtonHeight + 6;
  lblHint.Anchors := [akLeft, akBottom];

  BtnCancel := TButton.Create(Self);
  BtnCancel.Parent := Self;
  BtnCancel.Caption := 'Cancelar';
  BtnCancel.Cancel := True;
  BtnCancel.ModalResult := mrCancel;
  BtnCancel.SetBounds(ClientWidth - Margin - ButtonWidth, ClientHeight - Margin - ButtonHeight,
    ButtonWidth, ButtonHeight);
  BtnCancel.Anchors := [akRight, akBottom];

  BtnOk := TButton.Create(Self);
  BtnOk.Parent := Self;
  BtnOk.Caption := 'C&onfirmar';
  BtnOk.ModalResult := mrOk;
  BtnOk.SetBounds(BtnCancel.Left - 8 - ButtonWidth, BtnCancel.Top, ButtonWidth, ButtonHeight);
  BtnOk.Anchors := [akRight, akBottom];

  ActiveControl := mmSql;

  ApplyIdeMatchingStyle(Self);
end;

procedure TJotaSqlEntityForm.FormKeyDownHandler(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    ModalResult := mrOk;
  end;
end;

procedure TJotaSqlEntityForm.FormKeyPressHandler(Sender: TObject; var Key: Char);
begin
  if Key = #10 then
    Key := #0;
end;

procedure TJotaSqlEntityForm.FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
begin
  if (ModalResult = mrOk) and (Trim(mmSql.Text) = '') then
  begin
    CanClose := False;
    Fail(mmSql, 'Informe a consulta SQL.');
  end;
end;

constructor TJotaEntityClassNameForm.CreateDialog(const AClassName, ATitle, ALabel: string);
var
  lblClassName: TLabel;
  BtnOk, BtnCancel: TButton;
begin
  inherited CreateNew(nil);

  Caption := 'Jota IDE Wizards - ' + ATitle;
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  ClientWidth := 420;
  OnCloseQuery := FormCloseQueryHandler;

  lblClassName := TLabel.Create(Self);
  lblClassName.Parent := Self;
  lblClassName.Caption := ALabel;
  lblClassName.Left := Margin;
  lblClassName.Top := Margin + 3;

  edClassName := TEdit.Create(Self);
  edClassName.Parent := Self;
  edClassName.SetBounds(Margin + 100, Margin, ClientWidth - Margin * 2 - 100, edClassName.Height);
  edClassName.Text := AClassName;
  lblClassName.FocusControl := edClassName;

  BtnCancel := TButton.Create(Self);
  BtnCancel.Parent := Self;
  BtnCancel.Caption := 'Cancelar';
  BtnCancel.Cancel := True;
  BtnCancel.ModalResult := mrCancel;
  BtnCancel.SetBounds(ClientWidth - Margin - ButtonWidth, edClassName.Top + edClassName.Height + Margin,
    ButtonWidth, ButtonHeight);

  BtnOk := TButton.Create(Self);
  BtnOk.Parent := Self;
  BtnOk.Caption := 'OK';
  BtnOk.Default := True;
  BtnOk.ModalResult := mrOk;
  BtnOk.SetBounds(BtnCancel.Left - 8 - ButtonWidth, BtnCancel.Top, ButtonWidth, ButtonHeight);

  ClientHeight := BtnCancel.Top + ButtonHeight + Margin;

  ActiveControl := edClassName;

  ApplyIdeMatchingStyle(Self);
end;

procedure TJotaEntityClassNameForm.FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
begin
  if (ModalResult = mrOk) and not IsValidIdent(Trim(edClassName.Text)) then
  begin
    CanClose := False;
    Fail(edClassName, 'Informe um nome válido (ex.: TDadosCliente).');
  end;
end;

function SuggestInterfaceName(const AClassName: string): string;
var
  Name: string;
begin
  Name := Trim(AClassName);
  Result := '';
  if Name <> '' then
  begin
    if CharInSet(Name[1], ['T', 't']) then
      Result := 'I' + Copy(Name, 2, MaxInt)
    else
      Result := 'I' + Name;
  end;
end;

constructor TJotaInterfacedNamesForm.CreateDialog(const AClassName, AInterfaceName: string);
var
  lblClassName, lblInterfaceName: TLabel;
  BtnOk, BtnCancel: TButton;
begin
  inherited CreateNew(nil);

  Caption := 'Jota IDE Wizards - Converter em Interfaced Object';
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  ClientWidth := 420;
  OnCloseQuery := FormCloseQueryHandler;

  lblClassName := TLabel.Create(Self);
  lblClassName.Parent := Self;
  lblClassName.Caption := '&Nome da classe:';
  lblClassName.Left := Margin;
  lblClassName.Top := Margin + 3;

  edClassName := TEdit.Create(Self);
  edClassName.Parent := Self;
  edClassName.SetBounds(Margin + 110, Margin, ClientWidth - Margin * 2 - 110, edClassName.Height);
  lblClassName.FocusControl := edClassName;

  lblInterfaceName := TLabel.Create(Self);
  lblInterfaceName.Parent := Self;
  lblInterfaceName.Caption := 'Nome da &interface:';
  lblInterfaceName.Left := Margin;
  lblInterfaceName.Top := edClassName.Top + edClassName.Height + 10 + 3;

  edInterfaceName := TEdit.Create(Self);
  edInterfaceName.Parent := Self;
  edInterfaceName.SetBounds(edClassName.Left, edClassName.Top + edClassName.Height + 10,
    edClassName.Width, edInterfaceName.Height);
  lblInterfaceName.FocusControl := edInterfaceName;

  BtnCancel := TButton.Create(Self);
  BtnCancel.Parent := Self;
  BtnCancel.Caption := 'Cancelar';
  BtnCancel.Cancel := True;
  BtnCancel.ModalResult := mrCancel;
  BtnCancel.SetBounds(ClientWidth - Margin - ButtonWidth,
    edInterfaceName.Top + edInterfaceName.Height + Margin, ButtonWidth, ButtonHeight);

  BtnOk := TButton.Create(Self);
  BtnOk.Parent := Self;
  BtnOk.Caption := 'OK';
  BtnOk.Default := True;
  BtnOk.ModalResult := mrOk;
  BtnOk.SetBounds(BtnCancel.Left - 8 - ButtonWidth, BtnCancel.Top, ButtonWidth, ButtonHeight);

  ClientHeight := BtnCancel.Top + ButtonHeight + Margin;

  edClassName.Text := AClassName;
  edInterfaceName.Text := AInterfaceName;
  if AInterfaceName = SuggestInterfaceName(AClassName) then
    FLastAutoInterfaceName := AInterfaceName
  else
    FLastAutoInterfaceName := #0;
  edClassName.OnChange := ClassNameChange;

  ActiveControl := edClassName;

  ApplyIdeMatchingStyle(Self);
end;

procedure TJotaInterfacedNamesForm.ClassNameChange(Sender: TObject);
var
  NewInterfaceName: string;
begin
  if edInterfaceName.Text = FLastAutoInterfaceName then
  begin
    NewInterfaceName := SuggestInterfaceName(edClassName.Text);
    edInterfaceName.Text := NewInterfaceName;
    FLastAutoInterfaceName := NewInterfaceName;
  end;
end;

procedure TJotaInterfacedNamesForm.FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
begin
  if ModalResult = mrOk then
  begin
    CanClose := False;
    if not IsValidIdent(Trim(edClassName.Text)) then
      Fail(edClassName, 'Informe um nome de classe válido (ex.: TDadosCliente).')
    else if not IsValidIdent(Trim(edInterfaceName.Text)) then
      Fail(edInterfaceName, 'Informe um nome de interface válido (ex.: IDadosCliente).')
    else if SameText(Trim(edClassName.Text), Trim(edInterfaceName.Text)) then
      Fail(edInterfaceName, 'O nome da interface deve ser diferente do nome da classe.')
    else
      CanClose := True;
  end;
end;

function AskInterfacedNames(var AClassName, AInterfaceName: string): Boolean;
var
  DlgForm: TJotaInterfacedNamesForm;
begin
  DlgForm := TJotaInterfacedNamesForm.CreateDialog(AClassName, AInterfaceName);
  try
    Result := DlgForm.ShowModal = mrOk;
    if Result then
    begin
      AClassName := Trim(DlgForm.edClassName.Text);
      AInterfaceName := Trim(DlgForm.edInterfaceName.Text);
    end;
  finally
    DlgForm.Free;
  end;
end;

function ExecuteSqlEntityDialog(var ASql: string): Boolean;
var
  DlgForm: TJotaSqlEntityForm;
begin
  DlgForm := TJotaSqlEntityForm.CreateDialog(ASql);
  try
    Result := DlgForm.ShowModal = mrOk;
    if Result then
      ASql := DlgForm.mmSql.Text;
  finally
    DlgForm.Free;
  end;
end;

function AskEntityClassName(var AClassName: string; const ATitle, ALabel: string): Boolean;
var
  DlgForm: TJotaEntityClassNameForm;
begin
  DlgForm := TJotaEntityClassNameForm.CreateDialog(AClassName, ATitle, ALabel);
  try
    Result := DlgForm.ShowModal = mrOk;
    if Result then
      AClassName := Trim(DlgForm.edClassName.Text);
  finally
    DlgForm.Free;
  end;
end;

end.
