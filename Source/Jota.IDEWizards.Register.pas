unit Jota.IDEWizards.Register;

{
  Ponto central de registro/desregistro dos experts do "Jota IDE Wizards"
  junto a IDE do Delphi. Conforme o pacote crescer (novos wizards, menus,
  etc.), registre/desregistre cada um aqui.
}

interface

implementation

uses
  ToolsAPI,
  Jota.IDEWizards.KeyBindings;

var
  JotaKeyBindingIndex: Integer = -1;

procedure RegisterJotaWizards;
begin
  JotaKeyBindingIndex := (BorlandIDEServices as IOTAKeyboardServices)
    .AddKeyboardBinding(TJotaKeyBindings.Create);
end;

procedure UnregisterJotaWizards;
begin
  if JotaKeyBindingIndex >= 0 then
  begin
    (BorlandIDEServices as IOTAKeyboardServices).RemoveKeyboardBinding(JotaKeyBindingIndex);
    JotaKeyBindingIndex := -1;
  end;
end;

initialization
  RegisterJotaWizards;

finalization
  UnregisterJotaWizards;

end.
