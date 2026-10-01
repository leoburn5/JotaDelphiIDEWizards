unit Jota.IDEWizards.JotaMenu;

interface

type
  TJotaEditorMenuChoice = (emcNone, emcHandled, emcSyncEdit);

procedure RegisterJotaMenu;
procedure UnregisterJotaMenu;
function ShowJotaEditorMenu: TJotaEditorMenuChoice;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Menus,
  Vcl.ActnList,
  ToolsAPI,
  Jota.IDEWizards.ConfigDialog,
  Jota.IDEWizards.MetadataActions,
  Jota.IDEWizards.OTAUtils,
  Jota.IDEWizards.SqlEntityWizard,
  Jota.IDEWizards.FieldWizards;

const
  JotaCategory = 'Jota IDE Wizards';

type
  TJotaMenu = class(TComponent)
  private
    FShortcutAction: TAction;
    FConfigAction: TAction;
    FReloadMetadataAction: TAction;
    FSqlEntityAction: TAction;
    FNewFMTBCDFieldAction: TAction;
    FPopupMenu: TPopupMenu;
    FEditorPopupMenu: TPopupMenu;
    FSyncEditItem: TMenuItem;
    FToolsMenuItem: TMenuItem;
    function CreateAction(const AName, ACaption: string;
      AOnExecute: TNotifyEvent): TAction;
    function AddActionItem(AParent: TMenuItem; AAction: TAction): TMenuItem;
    procedure AddToolsItem(const ACaption: string; AAction: TAction);
    procedure ToolsItemClick(Sender: TObject);
    function FindToolsMenu(AMainMenu: TMainMenu): TMenuItem;
    procedure AddToolsMenu(AMainMenu: TMainMenu);
    procedure ShortcutActionExecute(Sender: TObject);
    procedure ShortcutActionUpdate(Sender: TObject);
    procedure ConfigActionExecute(Sender: TObject);
    procedure ReloadMetadataActionExecute(Sender: TObject);
    procedure SqlEntityActionExecute(Sender: TObject);
    procedure NewFMTBCDFieldActionExecute(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function PopupEditorMenu: TJotaEditorMenuChoice;
  end;

var
  JotaMenu: TJotaMenu = nil;

function IsCodeEditorFocused: Boolean;
begin
  Result := (Screen.ActiveControl <> nil) and
    Screen.ActiveControl.ClassNameIs('TEditControl');
end;

constructor TJotaMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FConfigAction := CreateAction('JotaConfigAction',
    '&1 - Configurar', ConfigActionExecute);

  FReloadMetadataAction := CreateAction('JotaReloadMetadataAction',
    '&2 - Recarregar metadados', ReloadMetadataActionExecute);

  FSqlEntityAction := CreateAction('JotaSqlEntityAction',
    '&3 - SQL Query para Entidade', SqlEntityActionExecute);

  FNewFMTBCDFieldAction := CreateAction('JotaNewFMTBCDFieldAction',
    '&3 - Novo campo FMTBCD', NewFMTBCDFieldActionExecute);

  FShortcutAction := CreateAction('JotaMenuShortcutAction',
    'Jota IDE Wizards - Menu', ShortcutActionExecute);
  FShortcutAction.OnUpdate := ShortcutActionUpdate;
  FShortcutAction.ShortCut := ShortCut(Ord('J'), [ssCtrl, ssShift]);

  FPopupMenu := TPopupMenu.Create(Self);
  AddActionItem(FPopupMenu.Items, FConfigAction);
  AddActionItem(FPopupMenu.Items, FReloadMetadataAction);
  AddActionItem(FPopupMenu.Items, FNewFMTBCDFieldAction);

  FEditorPopupMenu := TPopupMenu.Create(Self);
  AddActionItem(FEditorPopupMenu.Items, FConfigAction);
  AddActionItem(FEditorPopupMenu.Items, FReloadMetadataAction);
  AddActionItem(FEditorPopupMenu.Items, FSqlEntityAction);
  FSyncEditItem := TMenuItem.Create(FEditorPopupMenu);
  FSyncEditItem.Caption := '&4 - SyncEdit';
  FEditorPopupMenu.Items.Add(FSyncEditItem);

  AddToolsMenu((BorlandIDEServices as INTAServices).MainMenu);
end;

destructor TJotaMenu.Destroy;
begin
  FreeAndNil(FToolsMenuItem);
  FreeAndNil(FEditorPopupMenu);
  FreeAndNil(FPopupMenu);
  FreeAndNil(FShortcutAction);
  FreeAndNil(FNewFMTBCDFieldAction);
  FreeAndNil(FSqlEntityAction);
  FreeAndNil(FReloadMetadataAction);
  FreeAndNil(FConfigAction);
  inherited;
end;

function TJotaMenu.CreateAction(const AName, ACaption: string;
  AOnExecute: TNotifyEvent): TAction;
begin
  Result := TAction.Create(nil);
  Result.Name := AName;
  Result.Caption := ACaption;
  Result.Category := JotaCategory;
  Result.OnExecute := AOnExecute;
  Result.ActionList := (BorlandIDEServices as INTAServices).ActionList;
end;

function TJotaMenu.AddActionItem(AParent: TMenuItem; AAction: TAction): TMenuItem;
begin
  Result := TMenuItem.Create(AParent);
  Result.Action := AAction;
  AParent.Add(Result);
end;

procedure TJotaMenu.AddToolsItem(const ACaption: string; AAction: TAction);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(FToolsMenuItem);
  Item.Caption := ACaption;
  Item.Tag := NativeInt(AAction);
  Item.OnClick := ToolsItemClick;
  FToolsMenuItem.Add(Item);
end;

procedure TJotaMenu.ToolsItemClick(Sender: TObject);
begin
  TAction((Sender as TMenuItem).Tag).Execute;
end;

function TJotaMenu.FindToolsMenu(AMainMenu: TMainMenu): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  if AMainMenu <> nil then
  begin
    I := 0;
    while (Result = nil) and (I < AMainMenu.Items.Count) do
    begin
      if SameText(AMainMenu.Items[I].Name, 'ToolsMenu') then
        Result := AMainMenu.Items[I];
      Inc(I);
    end;
  end;
end;

procedure TJotaMenu.AddToolsMenu(AMainMenu: TMainMenu);
var
  ToolsMenu: TMenuItem;
begin
  ToolsMenu := FindToolsMenu(AMainMenu);
  if ToolsMenu <> nil then
  begin
    FToolsMenuItem := TMenuItem.Create(nil);
    FToolsMenuItem.Name := 'JotaIDEWizardsToolsMenu';
    FToolsMenuItem.Caption := 'Jota IDE Wizards';

    AddToolsItem('Configurar', FConfigAction);
    AddToolsItem('Recarregar metadados', FReloadMetadataAction);
    AddToolsItem('SQL Query para Entidade', FSqlEntityAction);
    AddToolsItem('Novo campo FMTBCD', FNewFMTBCDFieldAction);

    ToolsMenu.Add(FToolsMenuItem);
  end;
end;

function TJotaMenu.PopupEditorMenu: TJotaEditorMenuChoice;
var
  P: TPoint;
  Cmd: Integer;
  Item: TMenuItem;
begin
  Result := emcNone;
  P := GetEditorPopupPoint;

  Cmd := Integer(TrackPopupMenuEx(FEditorPopupMenu.Handle,
    TPM_LEFTALIGN or TPM_TOPALIGN or TPM_RIGHTBUTTON or TPM_RETURNCMD,
    P.X, P.Y, PopupList.Window, nil));

  if Cmd <> 0 then
  begin
    Item := FEditorPopupMenu.FindItem(Cmd, fkCommand);
    if Item = FSyncEditItem then
      Result := emcSyncEdit
    else if Item <> nil then
    begin
      Item.Click;
      Result := emcHandled;
    end;
  end;
end;

procedure TJotaMenu.ShortcutActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := not IsCodeEditorFocused;
end;

procedure TJotaMenu.ShortcutActionExecute(Sender: TObject);
var
  P: TPoint;
begin
  if IsDataSetSelectedInDesigner then
    RunNewFMTBCDFieldWizard
  else
  begin
    P := Mouse.CursorPos;
    FPopupMenu.Popup(P.X, P.Y);
  end;
end;

procedure TJotaMenu.ConfigActionExecute(Sender: TObject);
begin
  if ExecuteConfigDialog then
    ReloadJotaMetadataInteractive;
end;

procedure TJotaMenu.ReloadMetadataActionExecute(Sender: TObject);
begin
  ReloadJotaMetadataInteractive;
end;

procedure TJotaMenu.SqlEntityActionExecute(Sender: TObject);
begin
  RunSqlQueryToEntityWizard;
end;

procedure TJotaMenu.NewFMTBCDFieldActionExecute(Sender: TObject);
begin
  RunNewFMTBCDFieldWizard;
end;

function ShowJotaEditorMenu: TJotaEditorMenuChoice;
begin
  if JotaMenu = nil then
    Result := emcSyncEdit
  else
    Result := JotaMenu.PopupEditorMenu;
end;

procedure RegisterJotaMenu;
begin
  if JotaMenu = nil then
    JotaMenu := TJotaMenu.Create(nil);
end;

procedure UnregisterJotaMenu;
begin
  FreeAndNil(JotaMenu);
end;

end.
