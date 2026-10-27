unit Jota.IDEWizards.SaveGuard;

interface

uses
  ToolsAPI;

function ModuleHasFormEditor(const AModule: IOTAModule): Boolean;
function HandleFormSave(const AModule: IOTAModule; const AOrigin: string): Boolean;
procedure RegisterSaveGuard;
procedure UnregisterSaveGuard;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Actions,
  System.UITypes,
  Vcl.ActnList,
  Vcl.Dialogs,
  Jota.IDEWizards.DfmClientSizeFix,
  Jota.IDEWizards.Toast;

const
  IdeFileSaveActionName = 'FileSaveCommand';
  ToastDurationMs = 4000;

type
  TJotaSaveGuard = class(TComponent)
  private
    FSaveAction: TContainedAction;
    FOriginalExecute: TNotifyEvent;
    procedure SaveActionExecute(Sender: TObject);
    function IsHookInstalled: Boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function ExecuteOriginalSave: Boolean;
  end;

var
  SaveGuard: TJotaSaveGuard = nil;

function FindFormEditor(const AModule: IOTAModule): IOTAFormEditor;
var
  I: Integer;
  FormEditor: IOTAFormEditor;
begin
  Result := nil;
  if Assigned(AModule) then
  begin
    I := 0;
    while (I < AModule.ModuleFileCount) and not Assigned(Result) do
    begin
      if Supports(AModule.ModuleFileEditors[I], IOTAFormEditor, FormEditor) then
        Result := FormEditor;
      Inc(I);
    end;
  end;
end;

function ModuleHasFormEditor(const AModule: IOTAModule): Boolean;
begin
  Result := Assigned(FindFormEditor(AModule));
end;

function GetDfmFileName(const AModule: IOTAModule; const AFormEditor: IOTAFormEditor): string;
begin
  Result := AFormEditor.FileName;
  if not SameText(ExtractFileExt(Result), '.dfm') then
    Result := ChangeFileExt(AModule.FileName, '.dfm');
end;

procedure SaveModule(const AModule: IOTAModule);
begin
  if not (Assigned(SaveGuard) and SaveGuard.ExecuteOriginalSave) then
    AModule.Save(False, True);
end;

function HandleFormSave(const AModule: IOTAModule; const AOrigin: string): Boolean;
var
  FormEditor: IOTAFormEditor;
  DfmFileName, Restored: string;
  Before: TBytes;
begin
  FormEditor := FindFormEditor(AModule);
  Result := Assigned(FormEditor);
  if Result then
  begin
    DfmFileName := GetDfmFileName(AModule, FormEditor);
    Before := ReadDfmBytes(DfmFileName);
    SaveModule(AModule);
    try
      if RestoreRemovedClientSize(DfmFileName, Before, Restored) then
        ShowToast('Jota (' + AOrigin + '): DFM corrigido (' + Restored + ') - ' +
          ExtractFileName(DfmFileName), ToastDurationMs);
    except
      on E: Exception do
        MessageDlg('A unit foi salva, mas não consegui conferir/corrigir o DFM ' +
          ExtractFileName(DfmFileName) + ':' + sLineBreak + sLineBreak + E.Message,
          mtError, [mbOK], 0);
    end;
  end;
end;

function FindIdeAction(const AName: string): TContainedAction;
var
  ActionList: TCustomActionList;
  I: Integer;
begin
  Result := nil;
  ActionList := (BorlandIDEServices as INTAServices).ActionList;
  if Assigned(ActionList) then
  begin
    I := 0;
    while (I < ActionList.ActionCount) and not Assigned(Result) do
    begin
      if SameText(ActionList.Actions[I].Name, AName) then
        Result := ActionList.Actions[I];
      Inc(I);
    end;
  end;
end;

procedure QueueToast(const AMessage: string);
begin
  TThread.ForceQueue(nil,
    procedure
    begin
      ShowToast(AMessage, ToastDurationMs);
    end);
end;

constructor TJotaSaveGuard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSaveAction := FindIdeAction(IdeFileSaveActionName);
  if Assigned(FSaveAction) and Assigned(FSaveAction.OnExecute) then
  begin
    FOriginalExecute := FSaveAction.OnExecute;
    FSaveAction.OnExecute := SaveActionExecute;
    FSaveAction.FreeNotification(Self);
  end
  else
  begin
    FSaveAction := nil;
    QueueToast('Jota: não consegui interceptar a ação ' + IdeFileSaveActionName +
      ' (File > Save)');
  end;
end;

destructor TJotaSaveGuard.Destroy;
begin
  if IsHookInstalled then
    FSaveAction.OnExecute := FOriginalExecute;
  if Assigned(FSaveAction) then
    FSaveAction.RemoveFreeNotification(Self);
  FSaveAction := nil;
  inherited;
end;

function TJotaSaveGuard.IsHookInstalled: Boolean;
var
  Handler: TNotifyEvent;
begin
  Result := False;
  if Assigned(FSaveAction) then
  begin
    Handler := FSaveAction.OnExecute;
    Result := TMethod(Handler).Data = Pointer(Self);
  end;
end;

function TJotaSaveGuard.ExecuteOriginalSave: Boolean;
begin
  Result := Assigned(FSaveAction) and Assigned(FOriginalExecute);
  if Result then
    FOriginalExecute(FSaveAction);
end;

procedure TJotaSaveGuard.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FSaveAction) then
    FSaveAction := nil;
end;

procedure TJotaSaveGuard.SaveActionExecute(Sender: TObject);
begin
  if not HandleFormSave((BorlandIDEServices as IOTAModuleServices).CurrentModule,
    'File > Save') then
    if Assigned(FOriginalExecute) then
      FOriginalExecute(Sender);
end;

procedure RegisterSaveGuard;
begin
  if SaveGuard = nil then
    SaveGuard := TJotaSaveGuard.Create(nil);
end;

procedure UnregisterSaveGuard;
begin
  FreeAndNil(SaveGuard);
end;

end.
