unit Jota.IDEWizards.TableScriptDialog;

interface

uses
  Jota.IDEWizards.Metadata,
  Jota.IDEWizards.TableScript;

function ExecuteTableScriptDialog(AMetadata: TJotaMetadata; out ATable: TJotaMetaTable;
  var AKinds: TJotaTableScriptKinds; var AReplaceMethods: Boolean): Boolean;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Grids,
  Vcl.Graphics,
  Vcl.Dialogs,
  Jota.IDEWizards.Theming;

const
  Margin = 16;
  ButtonWidth = 100;
  ButtonHeight = 28;
  GroupHeight = 52;
  ColSchema = 0;
  ColTable = 1;
  ColPrimaryKey = 2;

type
  TJotaTableScriptForm = class(TForm)
  private
    FMetadata: TJotaMetadata;
    FFiltered: TList<TJotaMetaTable>;
    edTabela: TEdit;
    grTabelas: TStringGrid;
    gbScripts: TGroupBox;
    chkScripts: array[TJotaTableScriptKind] of TCheckBox;
    chkReplaceMethods: TCheckBox;
    procedure ApplyFilter;
    procedure UpdateScriptChecks(ATable: TJotaMetaTable);
    function TableAtRow(ARow: Integer): TJotaMetaTable;
    function SelectedTable: TJotaMetaTable;
    function SelectedKinds: TJotaTableScriptKinds;
    procedure SelectRow(ARow: Integer);
    procedure FilterChange(Sender: TObject);
    procedure FilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FilterKeyPress(Sender: TObject; var Key: Char);
    procedure GridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure GridDblClick(Sender: TObject);
    procedure FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
    procedure Fail(AControl: TWinControl; const AMessage: string);
  public
    constructor CreateDialog(AMetadata: TJotaMetadata; AKinds: TJotaTableScriptKinds;
      AReplaceMethods: Boolean);
    destructor Destroy; override;
  end;

constructor TJotaTableScriptForm.CreateDialog(AMetadata: TJotaMetadata;
  AKinds: TJotaTableScriptKinds; AReplaceMethods: Boolean);
var
  lblTabela: TLabel;
  BtnOk, BtnCancel: TButton;
  Kind: TJotaTableScriptKind;
  Y, CheckLeft: Integer;
begin
  inherited CreateNew(nil);

  FMetadata := AMetadata;
  FFiltered := TList<TJotaMetaTable>.Create;

  Caption := 'Jota IDE Wizards - Tabela para Script';
  BorderStyle := bsSizeable;
  BorderIcons := [biSystemMenu, biMaximize];
  Position := poScreenCenter;
  ClientWidth := 640;
  ClientHeight := 520;
  Constraints.MinWidth := 480;
  Constraints.MinHeight := 360;
  OnCloseQuery := FormCloseQueryHandler;

  lblTabela := TLabel.Create(Self);
  lblTabela.Parent := Self;
  lblTabela.Caption := '&Tabela:';
  lblTabela.Left := Margin;
  lblTabela.Top := Margin + 3;

  edTabela := TEdit.Create(Self);
  edTabela.Parent := Self;
  edTabela.SetBounds(Margin + 60, Margin, ClientWidth - Margin * 2 - 60, edTabela.Height);
  edTabela.Anchors := [akLeft, akTop, akRight];
  edTabela.TextHint := 'parte do nome da tabela (use esquema.tabela para filtrar pelo esquema)';
  edTabela.OnChange := FilterChange;
  edTabela.OnKeyDown := FilterKeyDown;
  edTabela.OnKeyPress := FilterKeyPress;
  lblTabela.FocusControl := edTabela;

  Y := ClientHeight - Margin - ButtonHeight;

  BtnCancel := TButton.Create(Self);
  BtnCancel.Parent := Self;
  BtnCancel.Caption := 'Cancelar';
  BtnCancel.Cancel := True;
  BtnCancel.ModalResult := mrCancel;
  BtnCancel.SetBounds(ClientWidth - Margin - ButtonWidth, Y, ButtonWidth, ButtonHeight);
  BtnCancel.Anchors := [akRight, akBottom];

  BtnOk := TButton.Create(Self);
  BtnOk.Parent := Self;
  BtnOk.Caption := '&Gerar';
  BtnOk.ModalResult := mrOk;
  BtnOk.SetBounds(BtnCancel.Left - 8 - ButtonWidth, Y, ButtonWidth, ButtonHeight);
  BtnOk.Anchors := [akRight, akBottom];

  chkReplaceMethods := TCheckBox.Create(Self);
  chkReplaceMethods.Parent := Self;
  chkReplaceMethods.Caption := 'Gerar Métodos de &Replace';
  chkReplaceMethods.SetBounds(Margin, Y + 6, 220, 17);
  chkReplaceMethods.Anchors := [akLeft, akBottom];
  chkReplaceMethods.Checked := AReplaceMethods;

  gbScripts := TGroupBox.Create(Self);
  gbScripts.Parent := Self;
  gbScripts.Caption := ' Scripts: ';
  gbScripts.SetBounds(Margin, Y - 12 - GroupHeight, ClientWidth - Margin * 2, GroupHeight);
  gbScripts.Anchors := [akLeft, akRight, akBottom];

  CheckLeft := 12;
  for Kind := Low(TJotaTableScriptKind) to High(TJotaTableScriptKind) do
  begin
    chkScripts[Kind] := TCheckBox.Create(Self);
    chkScripts[Kind].Parent := gbScripts;
    chkScripts[Kind].Caption := '&' + IntToStr(Ord(Kind) + 1) + ' - ' + TableScriptKindNames[Kind];
    chkScripts[Kind].SetBounds(CheckLeft, 22, 110, 17);
    chkScripts[Kind].Checked := Kind in AKinds;
    Inc(CheckLeft, 120);
  end;

  grTabelas := TStringGrid.Create(Self);
  grTabelas.Parent := Self;
  grTabelas.SetBounds(Margin, edTabela.Top + edTabela.Height + 10, ClientWidth - Margin * 2,
    gbScripts.Top - 10 - (edTabela.Top + edTabela.Height + 10));
  grTabelas.Anchors := [akLeft, akTop, akRight, akBottom];
  grTabelas.ColCount := 3;
  grTabelas.FixedCols := 0;
  grTabelas.RowCount := 2;
  grTabelas.FixedRows := 1;
  grTabelas.DefaultRowHeight := 20;
  grTabelas.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
    goRowSelect, goColSizing, goThumbTracking];
  grTabelas.ColWidths[ColSchema] := 160;
  grTabelas.ColWidths[ColTable] := 300;
  grTabelas.ColWidths[ColPrimaryKey] := 120;
  grTabelas.Cells[ColSchema, 0] := 'Esquema';
  grTabelas.Cells[ColTable, 0] := 'Tabela';
  grTabelas.Cells[ColPrimaryKey, 0] := 'Chave primária';
  grTabelas.OnSelectCell := GridSelectCell;
  grTabelas.OnDblClick := GridDblClick;

  ActiveControl := edTabela;
  ApplyFilter;

  ApplyIdeMatchingStyle(Self);
end;

destructor TJotaTableScriptForm.Destroy;
begin
  FFiltered.Free;
  inherited;
end;

procedure TJotaTableScriptForm.ApplyFilter;
var
  Filter: string;
  Table: TJotaMetaTable;
  UseFullName, Matches: Boolean;
  I: Integer;
begin
  Filter := LowerCase(Trim(edTabela.Text));
  UseFullName := Pos('.', Filter) > 0;
  FFiltered.Clear;
  for Table in FMetadata.Tables do
    if not Table.IsView then
    begin
      if Filter = '' then
        Matches := True
      else if UseFullName then
        Matches := Pos(Filter, LowerCase(Table.FullName)) > 0
      else
        Matches := Pos(Filter, LowerCase(Table.Name)) > 0;
      if Matches then
        FFiltered.Add(Table);
    end;

  if FFiltered.Count = 0 then
  begin
    grTabelas.RowCount := 2;
    grTabelas.Rows[1].Clear;
  end
  else
    grTabelas.RowCount := FFiltered.Count + 1;

  for I := 0 to FFiltered.Count - 1 do
  begin
    grTabelas.Cells[ColSchema, I + 1] := FFiltered[I].Schema;
    grTabelas.Cells[ColTable, I + 1] := FFiltered[I].Name;
    grTabelas.Cells[ColPrimaryKey, I + 1] := string.Join(', ', FFiltered[I].PrimaryKey);
  end;

  SelectRow(1);
end;

function TJotaTableScriptForm.TableAtRow(ARow: Integer): TJotaMetaTable;
begin
  if (ARow >= 1) and (ARow <= FFiltered.Count) then
    Result := FFiltered[ARow - 1]
  else
    Result := nil;
end;

function TJotaTableScriptForm.SelectedTable: TJotaMetaTable;
begin
  Result := TableAtRow(grTabelas.Row);
end;

procedure TJotaTableScriptForm.SelectRow(ARow: Integer);
begin
  if (ARow >= 1) and (ARow < grTabelas.RowCount) then
    grTabelas.Row := ARow;
  UpdateScriptChecks(SelectedTable);
end;

procedure TJotaTableScriptForm.UpdateScriptChecks(ATable: TJotaMetaTable);
var
  Kind: TJotaTableScriptKind;
begin
  for Kind := Low(TJotaTableScriptKind) to High(TJotaTableScriptKind) do
    chkScripts[Kind].Enabled := (ATable <> nil) and
      (not TableScriptRequiresPrimaryKey(Kind) or (Length(ATable.PrimaryKey) > 0));
end;

function TJotaTableScriptForm.SelectedKinds: TJotaTableScriptKinds;
var
  Kind: TJotaTableScriptKind;
begin
  Result := [];
  for Kind := Low(TJotaTableScriptKind) to High(TJotaTableScriptKind) do
    if chkScripts[Kind].Enabled and chkScripts[Kind].Checked then
      Include(Result, Kind);
end;

procedure TJotaTableScriptForm.FilterChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TJotaTableScriptForm.FilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_DOWN:
      begin
        SelectRow(grTabelas.Row + 1);
        Key := 0;
      end;
    VK_UP:
      begin
        SelectRow(grTabelas.Row - 1);
        Key := 0;
      end;
    VK_NEXT:
      begin
        SelectRow(grTabelas.Row + grTabelas.VisibleRowCount);
        Key := 0;
      end;
    VK_PRIOR:
      begin
        SelectRow(grTabelas.Row - grTabelas.VisibleRowCount);
        Key := 0;
      end;
    VK_RETURN:
      begin
        ModalResult := mrOk;
        Key := 0;
      end;
  end;
end;

procedure TJotaTableScriptForm.FilterKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
    Key := #0;
end;

procedure TJotaTableScriptForm.GridSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  UpdateScriptChecks(TableAtRow(ARow));
end;

procedure TJotaTableScriptForm.GridDblClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TJotaTableScriptForm.Fail(AControl: TWinControl; const AMessage: string);
begin
  MessageDlg(AMessage, mtWarning, [mbOK], 0);
  if AControl.CanFocus then
    AControl.SetFocus;
end;

procedure TJotaTableScriptForm.FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
begin
  if ModalResult = mrOk then
  begin
    CanClose := False;
    if SelectedTable = nil then
      Fail(edTabela, 'Selecione uma tabela.')
    else if SelectedKinds = [] then
      Fail(gbScripts, 'Marque ao menos um script disponível para a tabela selecionada.')
    else
      CanClose := True;
  end;
end;

function ExecuteTableScriptDialog(AMetadata: TJotaMetadata; out ATable: TJotaMetaTable;
  var AKinds: TJotaTableScriptKinds; var AReplaceMethods: Boolean): Boolean;
var
  DlgForm: TJotaTableScriptForm;
  Kind: TJotaTableScriptKind;
begin
  ATable := nil;
  DlgForm := TJotaTableScriptForm.CreateDialog(AMetadata, AKinds, AReplaceMethods);
  try
    Result := DlgForm.ShowModal = mrOk;
    if Result then
    begin
      ATable := DlgForm.SelectedTable;
      AKinds := [];
      for Kind := Low(TJotaTableScriptKind) to High(TJotaTableScriptKind) do
        if DlgForm.chkScripts[Kind].Checked then
          Include(AKinds, Kind);
      AReplaceMethods := DlgForm.chkReplaceMethods.Checked;
    end;
  finally
    DlgForm.Free;
  end;
end;

end.
