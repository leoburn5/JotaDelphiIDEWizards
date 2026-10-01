unit Jota.IDEWizards.FieldWizards;

{
  Wizards de campos (TField) para o Form Designer.

  "Novo campo FMTBCD": cria um TFMTBCDField persistente em qualquer
  descendente de TDataSet (TFDQuery, TFDMemTable, TClientDataSet, etc.)
  do form/data module ativo, com Precision/Size/DisplayFormat/EditFormat
  ja preenchidos (padrao numeric(21,2)).

  O campo e criado do mesmo jeito que o Fields Editor faz: Owner = Root
  do designer (o form/data module), Name atribuido antes de ligar ao
  dataset - a IDE usa o rename do componente para declarar o campo na
  classe do form no .pas.

  Depois de criar o campo, garante "Data.FmtBcd" no uses da interface
  (para usar StrToBcd, BcdToStr, TBcd etc. sem declarar a mao).
}

interface

/// <summary>
///   Abre o dialogo "Novo campo FMTBCD" para o form/data module ativo e
///   cria o campo com as opcoes escolhidas.
/// </summary>
procedure RunNewFMTBCDFieldWizard;

/// <summary>
///   True se houver um TDataSet selecionado diretamente no Form
///   Designer ativo (nao conta campo selecionado no Fields Editor).
/// </summary>
function IsDataSetSelectedInDesigner: Boolean;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Dialogs,
  Data.DB,
  ToolsAPI,
  DesignIntf,
  Jota.IDEWizards.NewFMTBCDFieldDialog,
  Jota.IDEWizards.UsesClause,
  Jota.IDEWizards.Toast;

function GetActiveFormDesigner: IDesigner;
var
  Module: IOTAModule;
  FormEditor: IOTAFormEditor;
  NTAFormEditor: INTAFormEditor;
  I: Integer;
begin
  Result := nil;

  if BorlandIDEServices = nil then
    Exit;

  Module := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  if Module = nil then
    Exit;

  for I := 0 to Module.GetModuleFileCount - 1 do
    if Supports(Module.GetModuleFileEditor(I), IOTAFormEditor, FormEditor) and
      Supports(FormEditor, INTAFormEditor, NTAFormEditor) then
    begin
      Result := NTAFormEditor.FormDesigner;
      if Result <> nil then
        Exit;
    end;
end;

function CollectDataSets(ARoot: TComponent): TArray<TDataSet>;
var
  List: TList<TDataSet>;
  I: Integer;
begin
  List := TList<TDataSet>.Create;
  try
    for I := 0 to ARoot.ComponentCount - 1 do
      if ARoot.Components[I] is TDataSet then
        List.Add(TDataSet(ARoot.Components[I]));
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function GetPreselectedDataSet(const ADesigner: IDesigner): TDataSet;
var
  Selections: IDesignerSelections;
  Item: TPersistent;
  I: Integer;
begin
  // Usa o dataset selecionado no designer, ou o dataset do campo
  // selecionado (ex.: campo selecionado no Fields Editor).
  Result := nil;
  Selections := CreateSelectionList;
  ADesigner.GetSelections(Selections);
  for I := 0 to Selections.Count - 1 do
  begin
    Item := Selections.Items[I];
    if Item is TDataSet then
      Exit(TDataSet(Item));
    if (Item is TField) and (TField(Item).DataSet <> nil) then
      Exit(TField(Item).DataSet);
  end;
end;

function IsDataSetSelectedInDesigner: Boolean;
var
  Designer: IDesigner;
  Selections: IDesignerSelections;
  I: Integer;
begin
  Result := False;
  Designer := GetActiveFormDesigner;
  if Designer = nil then
    Exit;

  Selections := CreateSelectionList;
  Designer.GetSelections(Selections);
  for I := 0 to Selections.Count - 1 do
    if Selections.Items[I] is TDataSet then
      Exit(True);
end;

procedure RunNewFMTBCDFieldWizard;
var
  Designer: IDesigner;
  Root: TComponent;
  DataSets: TArray<TDataSet>;
  Options: TNewFMTBCDFieldOptions;
  Field: TFMTBCDField;
  UsesMsg: string;
begin
  Designer := GetActiveFormDesigner;
  if (Designer = nil) or (Designer.Root = nil) then
  begin
    ShowMessage('Abra um form ou data module no Form Designer para criar o campo.');
    Exit;
  end;

  Root := Designer.Root;
  DataSets := CollectDataSets(Root);
  if Length(DataSets) = 0 then
  begin
    ShowMessage(Format('Nenhum dataset encontrado em %s.', [Root.Name]));
    Exit;
  end;

  if not ExecuteNewFMTBCDFieldDialog(Root, DataSets,
    GetPreselectedDataSet(Designer), Options) then
    Exit;

  // Nao da para adicionar campo persistente com o dataset aberto. O
  // dialogo ja avisou o usuario de que o dataset seria fechado.
  if Options.DataSet.Active then
    Options.DataSet.Close;

  Field := TFMTBCDField.Create(Root);
  try
    Field.FieldName := Options.FieldName;
    Field.FieldKind := Options.FieldKind;
    Field.Precision := Options.Precision;
    Field.Size := Options.Scale;
    if Options.DisplayLabel <> '' then
      Field.DisplayLabel := Options.DisplayLabel;
    Field.DisplayFormat := Options.DisplayFormat;
    Field.EditFormat := Options.EditFormat;
    Field.Required := Options.Required;
    Field.Name := Options.ComponentName;
    Field.DataSet := Options.DataSet;
  except
    Field.Free;
    raise;
  end;

  Designer.Modified;
  Designer.SelectComponent(Field);

  case EnsureUnitInInterfaceUses('Data.FmtBcd') of
    eurAdded:
      UsesMsg := ' + Data.FmtBcd adicionada ao uses';
    eurAlreadyInImplementation:
      UsesMsg := ' (Data.FmtBcd já está no uses da implementation)';
    eurNoSourceEditor, eurParseFailed:
      UsesMsg := ' (não foi possível ajustar o uses: adicione Data.FmtBcd manualmente)';
  else
    UsesMsg := '';
  end;

  ShowToast(Format('Campo %s (%d,%d) criado em %s%s',
    [Field.FieldName, Field.Precision, Field.Size, Options.DataSet.Name, UsesMsg]),
    3500);
end;

end.
