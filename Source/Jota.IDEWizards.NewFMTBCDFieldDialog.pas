unit Jota.IDEWizards.NewFMTBCDFieldDialog;

{
  Dialogo "Novo campo FMTBCD": coleta as opcoes para criar um
  TFMTBCDField persistente em qualquer TDataSet do form/data module
  ativo no Form Designer.

  Padroes: Precision = 21, Scale (Size) = 2 -> compativel com
  numeric(21,2) do PostgreSQL.

  DisplayFormat e EditFormat sao gerados a partir da escala:
    DisplayFormat = '#,##0.00;(#,##0.00)'
    EditFormat    = '0.00'
  O EditFormat NAO usa separador de milhar de proposito: o texto
  editado volta para o campo via conversao string -> BCD, que nao
  aceita separador de milhar (o usuario veria "1.234,56", confirmaria
  e receberia erro de valor invalido).

  Os valores gerados automaticamente (Name, DisplayFormat, EditFormat)
  so sao recalculados enquanto o usuario nao os editar manualmente.
}

interface

uses
  System.Classes,
  Data.DB;

const
  DefaultFMTBCDPrecision = 21;
  DefaultFMTBCDScale = 2;
  MaxFMTBCDPrecision = 32;

type
  TNewFMTBCDFieldOptions = record
    DataSet: TDataSet;
    FieldName: string;
    ComponentName: string;
    DisplayLabel: string;
    FieldKind: TFieldKind;
    Precision: Integer;
    Scale: Integer;
    DisplayFormat: string;
    EditFormat: string;
    Required: Boolean;
  end;

/// <summary>
///   Gera DisplayFormat ('#,##0.00;(#,##0.00)') e EditFormat ('0.00')
///   com a quantidade de casas decimais de AScale. Os caracteres '.' e
///   ',' da mascara sao marcadores: o Delphi os troca pelos separadores
///   do locale ao formatar.
/// </summary>
procedure BuildBcdFormats(AScale: Integer; out ADisplayFormat, AEditFormat: string);

/// <summary>
///   Mostra o dialogo. ARoot e o form/data module em design (usado para
///   validar e sugerir o Name do componente). Retorna True se o usuario
///   confirmou, com AOptions preenchido.
/// </summary>
function ExecuteNewFMTBCDFieldDialog(ARoot: TComponent;
  const ADataSets: TArray<TDataSet>; APreselected: TDataSet;
  out AOptions: TNewFMTBCDFieldOptions): Boolean;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Vcl.Dialogs,
  Jota.IDEWizards.Theming;

const
  Margin = 16;
  LabelWidth = 130;
  ControlLeft = Margin + LabelWidth;
  ControlWidth = 280;
  RowHeight = 30;
  WarningHeight = 48;
  ButtonWidth = 90;
  ButtonHeight = 28;

  FieldKinds: array[0..2] of TFieldKind = (fkData, fkCalculated, fkInternalCalc);
  FieldKindCaptions: array[0..2] of string = (
    'fkData (campo do banco)',
    'fkCalculated (calculado)',
    'fkInternalCalc (calculado interno)');

procedure BuildBcdFormats(AScale: Integer; out ADisplayFormat, AEditFormat: string);
var
  Decimals: string;
begin
  if AScale > 0 then
    Decimals := '.' + StringOfChar('0', AScale)
  else
    Decimals := '';

  ADisplayFormat := Format('#,##0%s;(#,##0%s)', [Decimals, Decimals]);
  AEditFormat := '0' + Decimals;
end;

function HasPersistentFields(ADataSet: TDataSet): Boolean;
var
  I: Integer;
begin
  // Campos dinamicos (criados ao abrir o dataset) pertencem ao proprio
  // dataset; campos persistentes pertencem ao form/data module.
  for I := 0 to ADataSet.Fields.Count - 1 do
    if ADataSet.Fields[I].Owner <> ADataSet then
      Exit(True);
  Result := False;
end;

function FindPersistentField(ADataSet: TDataSet; const AFieldName: string): TField;
var
  I: Integer;
begin
  for I := 0 to ADataSet.Fields.Count - 1 do
  begin
    Result := ADataSet.Fields[I];
    if (Result.Owner <> ADataSet) and SameText(Result.FieldName, AFieldName) then
      Exit;
  end;
  Result := nil;
end;

type
  TJotaNewFMTBCDFieldForm = class(TForm)
  private
    FRoot: TComponent;
    FTop: Integer;
    FLastAutoName: string;
    FLastAutoDisplayFormat: string;
    FLastAutoEditFormat: string;
    cbDataSet: TComboBox;
    edFieldName: TEdit;
    edComponentName: TEdit;
    edDisplayLabel: TEdit;
    cbFieldKind: TComboBox;
    edPrecision: TEdit;
    udPrecision: TUpDown;
    edScale: TEdit;
    udScale: TUpDown;
    edDisplayFormat: TEdit;
    edEditFormat: TEdit;
    chkRequired: TCheckBox;
    lblWarning: TLabel;
    procedure AddRow(const ACaption: string; AControl: TWinControl;
      AWidth: Integer = ControlWidth);
    function CreateEdit: TEdit;
    function CreateUpDown(AEdit: TEdit; AMin, AMax, APosition: Integer): TUpDown;
    function SelectedDataSet: TDataSet;
    function CurrentScale: Integer;
    function CurrentPrecision: Integer;
    function SuggestComponentName: string;
    procedure RefreshAutoValues;
    procedure RefreshWarning;
    procedure DataSetChange(Sender: TObject);
    procedure FieldNameChange(Sender: TObject);
    procedure ScaleChange(Sender: TObject);
    procedure FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
    function Fail(AControl: TWinControl; const AMessage: string): Boolean;
  public
    constructor CreateDialog(ARoot: TComponent; const ADataSets: TArray<TDataSet>;
      APreselected: TDataSet);
    procedure GetOptions(out AOptions: TNewFMTBCDFieldOptions);
  end;

{ TJotaNewFMTBCDFieldForm }

constructor TJotaNewFMTBCDFieldForm.CreateDialog(ARoot: TComponent;
  const ADataSets: TArray<TDataSet>; APreselected: TDataSet);
var
  DS: TDataSet;
  I: Integer;
  BtnOk, BtnCancel: TButton;
begin
  inherited CreateNew(nil);

  FRoot := ARoot;

  Caption := 'Jota IDE Wizards - Novo campo FMTBCD';
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  ClientWidth := ControlLeft + ControlWidth + Margin;
  OnCloseQuery := FormCloseQueryHandler;

  FTop := Margin;

  cbDataSet := TComboBox.Create(Self);
  AddRow('&Dataset:', cbDataSet);
  cbDataSet.Style := csDropDownList;
  cbDataSet.Sorted := True;
  for DS in ADataSets do
    cbDataSet.Items.AddObject(Format('%s (%s)', [DS.Name, DS.ClassName]), DS);
  cbDataSet.ItemIndex := cbDataSet.Items.IndexOfObject(APreselected);
  if (cbDataSet.ItemIndex < 0) and (cbDataSet.Items.Count = 1) then
    cbDataSet.ItemIndex := 0;
  cbDataSet.OnChange := DataSetChange;

  edFieldName := CreateEdit;
  AddRow('&FieldName:', edFieldName);
  edFieldName.OnChange := FieldNameChange;

  edComponentName := CreateEdit;
  AddRow('&Name (componente):', edComponentName);

  edDisplayLabel := CreateEdit;
  AddRow('Display&Label:', edDisplayLabel);
  edDisplayLabel.TextHint := '(vazio = usa o FieldName)';

  cbFieldKind := TComboBox.Create(Self);
  AddRow('Field&Kind:', cbFieldKind);
  cbFieldKind.Style := csDropDownList;
  for I := Low(FieldKindCaptions) to High(FieldKindCaptions) do
    cbFieldKind.Items.Add(FieldKindCaptions[I]);
  cbFieldKind.ItemIndex := 0;

  edPrecision := CreateEdit;
  AddRow('&Precision:', edPrecision, 70);
  udPrecision := CreateUpDown(edPrecision, 1, MaxFMTBCDPrecision, DefaultFMTBCDPrecision);

  edScale := CreateEdit;
  AddRow('&Scale (Size):', edScale, 70);
  udScale := CreateUpDown(edScale, 0, MaxFMTBCDPrecision, DefaultFMTBCDScale);
  edScale.OnChange := ScaleChange;

  edDisplayFormat := CreateEdit;
  AddRow('Displa&yFormat:', edDisplayFormat);

  edEditFormat := CreateEdit;
  AddRow('&EditFormat:', edEditFormat);

  chkRequired := TCheckBox.Create(Self);
  chkRequired.Parent := Self;
  chkRequired.Caption := '&Required';
  chkRequired.Left := ControlLeft;
  chkRequired.Top := FTop;
  chkRequired.Width := ControlWidth;
  Inc(FTop, RowHeight);

  lblWarning := TLabel.Create(Self);
  lblWarning.Parent := Self;
  lblWarning.Left := Margin;
  lblWarning.Top := FTop;
  lblWarning.AutoSize := False;
  lblWarning.WordWrap := True;
  lblWarning.Width := ClientWidth - (Margin * 2);
  lblWarning.Height := WarningHeight;
  lblWarning.Font.Color := clRed;
  Inc(FTop, WarningHeight + 8);

  BtnCancel := TButton.Create(Self);
  BtnCancel.Parent := Self;
  BtnCancel.Caption := 'Cancelar';
  BtnCancel.Cancel := True;
  BtnCancel.ModalResult := mrCancel;
  BtnCancel.SetBounds(ClientWidth - Margin - ButtonWidth, FTop, ButtonWidth, ButtonHeight);

  BtnOk := TButton.Create(Self);
  BtnOk.Parent := Self;
  BtnOk.Caption := 'OK';
  BtnOk.Default := True;
  BtnOk.ModalResult := mrOk;
  BtnOk.SetBounds(BtnCancel.Left - 8 - ButtonWidth, FTop, ButtonWidth, ButtonHeight);

  ClientHeight := FTop + ButtonHeight + Margin;

  RefreshAutoValues;
  RefreshWarning;

  if cbDataSet.ItemIndex < 0 then
    ActiveControl := cbDataSet
  else
    ActiveControl := edFieldName;

  ApplyIdeMatchingStyle(Self);
end;

procedure TJotaNewFMTBCDFieldForm.AddRow(const ACaption: string;
  AControl: TWinControl; AWidth: Integer);
var
  Lbl: TLabel;
begin
  AControl.Parent := Self;
  AControl.SetBounds(ControlLeft, FTop, AWidth, AControl.Height);

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Self;
  Lbl.Caption := ACaption;
  Lbl.Left := Margin;
  Lbl.Top := FTop + 3;
  Lbl.FocusControl := AControl;

  Inc(FTop, RowHeight);
end;

function TJotaNewFMTBCDFieldForm.CreateEdit: TEdit;
begin
  Result := TEdit.Create(Self);
end;

function TJotaNewFMTBCDFieldForm.CreateUpDown(AEdit: TEdit;
  AMin, AMax, APosition: Integer): TUpDown;
begin
  Result := TUpDown.Create(Self);
  Result.Parent := Self;
  Result.Min := AMin;
  Result.Max := AMax;
  Result.Thousands := False;
  Result.Associate := AEdit;
  Result.Position := APosition;
end;

function TJotaNewFMTBCDFieldForm.SelectedDataSet: TDataSet;
begin
  if cbDataSet.ItemIndex < 0 then
    Result := nil
  else
    Result := TDataSet(cbDataSet.Items.Objects[cbDataSet.ItemIndex]);
end;

function TJotaNewFMTBCDFieldForm.CurrentScale: Integer;
begin
  Result := StrToIntDef(Trim(edScale.Text), -1);
end;

function TJotaNewFMTBCDFieldForm.CurrentPrecision: Integer;
begin
  Result := StrToIntDef(Trim(edPrecision.Text), -1);
end;

function TJotaNewFMTBCDFieldForm.SuggestComponentName: string;
var
  DS: TDataSet;
  C: Char;
  CleanFieldName, BaseName: string;
  N: Integer;
begin
  Result := '';
  DS := SelectedDataSet;
  if DS = nil then
    Exit;

  // Mesmo padrao do Fields Editor: <NomeDoDataset><FieldName>, so com
  // caracteres validos em identificador.
  CleanFieldName := '';
  for C in Trim(edFieldName.Text) do
    if CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      CleanFieldName := CleanFieldName + C;

  if CleanFieldName = '' then
    Exit;

  BaseName := DS.Name + CleanFieldName;
  Result := BaseName;
  N := 1;
  while (FRoot <> nil) and (FRoot.FindComponent(Result) <> nil) do
  begin
    Result := BaseName + IntToStr(N);
    Inc(N);
  end;
end;

procedure TJotaNewFMTBCDFieldForm.RefreshAutoValues;
var
  NewName, NewDisplayFormat, NewEditFormat: string;
  Scale: Integer;
begin
  // So sobrescreve se o texto atual ainda for o ultimo valor gerado
  // automaticamente (ou seja, o usuario nao editou manualmente).
  NewName := SuggestComponentName;
  if edComponentName.Text = FLastAutoName then
    edComponentName.Text := NewName;
  FLastAutoName := NewName;

  Scale := CurrentScale;
  if Scale < 0 then
    Exit;

  BuildBcdFormats(Scale, NewDisplayFormat, NewEditFormat);

  if edDisplayFormat.Text = FLastAutoDisplayFormat then
    edDisplayFormat.Text := NewDisplayFormat;
  FLastAutoDisplayFormat := NewDisplayFormat;

  if edEditFormat.Text = FLastAutoEditFormat then
    edEditFormat.Text := NewEditFormat;
  FLastAutoEditFormat := NewEditFormat;
end;

procedure TJotaNewFMTBCDFieldForm.RefreshWarning;
var
  DS: TDataSet;
  Msg: string;
begin
  Msg := '';
  DS := SelectedDataSet;
  if DS <> nil then
  begin
    if not HasPersistentFields(DS) then
      Msg := 'Atenção: este dataset ainda não tem campos persistentes. ' +
        'Depois de criar este campo, só os campos persistentes existirão em ' +
        'runtime. Se precisar dos demais, use "Add all fields" antes.';
    if DS.Active then
      Msg := Msg + IfThen(Msg <> '', ' ', '') +
        'O dataset está aberto e será fechado ao confirmar.';
  end;
  lblWarning.Caption := Msg;
end;

procedure TJotaNewFMTBCDFieldForm.DataSetChange(Sender: TObject);
begin
  RefreshAutoValues;
  RefreshWarning;
end;

procedure TJotaNewFMTBCDFieldForm.FieldNameChange(Sender: TObject);
begin
  RefreshAutoValues;
end;

procedure TJotaNewFMTBCDFieldForm.ScaleChange(Sender: TObject);
begin
  RefreshAutoValues;
end;

function TJotaNewFMTBCDFieldForm.Fail(AControl: TWinControl; const AMessage: string): Boolean;
begin
  MessageDlg(AMessage, mtWarning, [mbOK], 0);
  if AControl.CanFocus then
    AControl.SetFocus;
  Result := False;
end;

procedure TJotaNewFMTBCDFieldForm.FormCloseQueryHandler(Sender: TObject;
  var CanClose: Boolean);
var
  DS: TDataSet;
  FieldName, CompName: string;
  Precision, Scale: Integer;
begin
  if ModalResult <> mrOk then
    Exit;

  CanClose := False;

  DS := SelectedDataSet;
  if DS = nil then
  begin
    Fail(cbDataSet, 'Selecione o dataset.');
    Exit;
  end;

  FieldName := Trim(edFieldName.Text);
  if FieldName = '' then
  begin
    Fail(edFieldName, 'Informe o FieldName.');
    Exit;
  end;

  if FindPersistentField(DS, FieldName) <> nil then
  begin
    Fail(edFieldName, Format('O dataset %s já tem um campo persistente "%s".',
      [DS.Name, FieldName]));
    Exit;
  end;

  CompName := Trim(edComponentName.Text);
  if not IsValidIdent(CompName) then
  begin
    Fail(edComponentName, Format('"%s" não é um nome de componente válido.', [CompName]));
    Exit;
  end;

  if (FRoot <> nil) and (FRoot.FindComponent(CompName) <> nil) then
  begin
    Fail(edComponentName, Format('Já existe um componente chamado "%s".', [CompName]));
    Exit;
  end;

  Precision := CurrentPrecision;
  if (Precision < 1) or (Precision > MaxFMTBCDPrecision) then
  begin
    Fail(edPrecision, Format('Precision deve estar entre 1 e %d.', [MaxFMTBCDPrecision]));
    Exit;
  end;

  Scale := CurrentScale;
  if (Scale < 0) or (Scale > Precision) then
  begin
    Fail(edScale, 'Scale deve estar entre 0 e o valor de Precision.');
    Exit;
  end;

  CanClose := True;
end;

procedure TJotaNewFMTBCDFieldForm.GetOptions(out AOptions: TNewFMTBCDFieldOptions);
begin
  AOptions.DataSet := SelectedDataSet;
  AOptions.FieldName := Trim(edFieldName.Text);
  AOptions.ComponentName := Trim(edComponentName.Text);
  AOptions.DisplayLabel := Trim(edDisplayLabel.Text);
  AOptions.FieldKind := FieldKinds[cbFieldKind.ItemIndex];
  AOptions.Precision := CurrentPrecision;
  AOptions.Scale := CurrentScale;
  AOptions.DisplayFormat := edDisplayFormat.Text;
  AOptions.EditFormat := edEditFormat.Text;
  AOptions.Required := chkRequired.Checked;
end;

function ExecuteNewFMTBCDFieldDialog(ARoot: TComponent;
  const ADataSets: TArray<TDataSet>; APreselected: TDataSet;
  out AOptions: TNewFMTBCDFieldOptions): Boolean;
var
  DlgForm: TJotaNewFMTBCDFieldForm;
begin
  DlgForm := TJotaNewFMTBCDFieldForm.CreateDialog(ARoot, ADataSets, APreselected);
  try
    Result := DlgForm.ShowModal = mrOk;
    if Result then
      DlgForm.GetOptions(AOptions);
  finally
    DlgForm.Free;
  end;
end;

end.
