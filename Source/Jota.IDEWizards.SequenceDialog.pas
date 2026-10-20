unit Jota.IDEWizards.SequenceDialog;

interface

uses
  Jota.IDEWizards.Sequence;

function ExecuteSequenceDialog(const ADefinition: TJotaSequenceDefinition;
  var AValues: TArray<string>): Boolean;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Dialogs,
  Jota.IDEWizards.Theming;

const
  Margin = 16;
  LabelSpacing = 12;
  ControlWidth = 320;
  IndicatorWidth = 60;
  RowHeight = 30;
  ButtonWidth = 100;
  ButtonHeight = 28;

type
  TJotaSequenceForm = class(TForm)
  private
    FDefinition: TJotaSequenceDefinition;
    FLabels: TArray<TLabel>;
    FControls: TArray<TWinControl>;
    FBtnOk: TButton;
    FBtnCancel: TButton;
    function ValueAt(AIndex: Integer): string;
    procedure LayoutControls;
    procedure FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
  public
    constructor CreateDialog(const ADefinition: TJotaSequenceDefinition;
      const AValues: TArray<string>);
    function Values: TArray<string>;
  end;

constructor TJotaSequenceForm.CreateDialog(const ADefinition: TJotaSequenceDefinition;
  const AValues: TArray<string>);
var
  I: Integer;
  Edit: TEdit;
  Combo: TComboBox;
  Value: string;
begin
  inherited CreateNew(nil);

  FDefinition := ADefinition;
  Caption := 'Jota IDE Wizards - Nova Sequência - ' + ADefinition.Caption;
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  OnCloseQuery := FormCloseQueryHandler;

  SetLength(FLabels, Length(ADefinition.Params));
  SetLength(FControls, Length(ADefinition.Params));
  for I := 0 to High(ADefinition.Params) do
  begin
    if I <= High(AValues) then
      Value := AValues[I]
    else
      Value := '';

    FLabels[I] := TLabel.Create(Self);
    FLabels[I].Parent := Self;
    FLabels[I].AutoSize := True;
    FLabels[I].Caption := ADefinition.Params[I].Caption + ' (' + ADefinition.Params[I].Name + '):';

    if ADefinition.Params[I].IsIndicator then
    begin
      Combo := TComboBox.Create(Self);
      Combo.Parent := Self;
      Combo.Style := csDropDownList;
      Combo.Items.Add('S');
      Combo.Items.Add('N');
      Combo.ItemIndex := Combo.Items.IndexOf(Value);
      if Combo.ItemIndex < 0 then
        Combo.ItemIndex := 1;
      FControls[I] := Combo;
    end
    else
    begin
      Edit := TEdit.Create(Self);
      Edit.Parent := Self;
      Edit.Text := Value;
      FControls[I] := Edit;
    end;
    FLabels[I].FocusControl := FControls[I];
  end;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := Self;
  FBtnCancel.Caption := 'Cancelar';
  FBtnCancel.Cancel := True;
  FBtnCancel.ModalResult := mrCancel;

  FBtnOk := TButton.Create(Self);
  FBtnOk.Parent := Self;
  FBtnOk.Caption := 'C&onfirmar';
  FBtnOk.Default := True;
  FBtnOk.ModalResult := mrOk;

  if Length(FControls) > 0 then
    ActiveControl := FControls[0];

  ApplyIdeMatchingStyle(Self);
  LayoutControls;
end;

procedure TJotaSequenceForm.LayoutControls;
var
  I, LabelWidth, ControlLeft, Y, ContentWidth: Integer;
begin
  LabelWidth := 0;
  for I := 0 to High(FLabels) do
    if Canvas.TextWidth(FLabels[I].Caption) > LabelWidth then
      LabelWidth := Canvas.TextWidth(FLabels[I].Caption);
  for I := 0 to High(FLabels) do
    if FLabels[I].Width > LabelWidth then
      LabelWidth := FLabels[I].Width;

  ControlLeft := Margin + LabelWidth + LabelSpacing;
  ContentWidth := ControlLeft + ControlWidth + Margin;
  if ContentWidth < Margin + ButtonWidth * 2 + 8 + Margin then
    ContentWidth := Margin + ButtonWidth * 2 + 8 + Margin;
  ClientWidth := ContentWidth;

  Y := Margin;
  for I := 0 to High(FControls) do
  begin
    FLabels[I].Left := Margin;
    FLabels[I].Top := Y + 3;
    if FControls[I] is TComboBox then
      FControls[I].SetBounds(ControlLeft, Y, IndicatorWidth, FControls[I].Height)
    else
      FControls[I].SetBounds(ControlLeft, Y, ControlWidth, FControls[I].Height);
    Inc(Y, RowHeight);
  end;

  Inc(Y, 8);
  FBtnCancel.SetBounds(ClientWidth - Margin - ButtonWidth, Y, ButtonWidth, ButtonHeight);
  FBtnOk.SetBounds(FBtnCancel.Left - 8 - ButtonWidth, Y, ButtonWidth, ButtonHeight);
  ClientHeight := Y + ButtonHeight + Margin;
end;

function TJotaSequenceForm.ValueAt(AIndex: Integer): string;
begin
  if FControls[AIndex] is TComboBox then
    Result := TComboBox(FControls[AIndex]).Text
  else
    Result := Trim(TEdit(FControls[AIndex]).Text);
end;

function TJotaSequenceForm.Values: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, Length(FControls));
  for I := 0 to High(FControls) do
    Result[I] := ValueAt(I);
end;

procedure TJotaSequenceForm.FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
var
  I, EmptyIndex: Integer;
begin
  if ModalResult = mrOk then
  begin
    EmptyIndex := -1;
    I := 0;
    while (EmptyIndex < 0) and (I <= High(FControls)) do
    begin
      if ValueAt(I) = '' then
        EmptyIndex := I;
      Inc(I);
    end;

    CanClose := EmptyIndex < 0;
    if not CanClose then
    begin
      MessageDlg('Preencha "' + FDefinition.Params[EmptyIndex].Caption + '".', mtWarning, [mbOK], 0);
      if FControls[EmptyIndex].CanFocus then
        FControls[EmptyIndex].SetFocus;
    end;
  end;
end;

function ExecuteSequenceDialog(const ADefinition: TJotaSequenceDefinition;
  var AValues: TArray<string>): Boolean;
var
  DlgForm: TJotaSequenceForm;
begin
  DlgForm := TJotaSequenceForm.CreateDialog(ADefinition, AValues);
  try
    Result := DlgForm.ShowModal = mrOk;
    if Result then
      AValues := DlgForm.Values;
  finally
    DlgForm.Free;
  end;
end;

end.
