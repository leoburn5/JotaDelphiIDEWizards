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
  Jota.IDEWizards.KeyBindings,
  Jota.IDEWizards.JotaMenu,
  Jota.IDEWizards.SplashScreen;

var
  JotaKeyBindingIndex: Integer = -1;

procedure RegisterJotaWizards;
begin
  JotaKeyBindingIndex := (BorlandIDEServices as IOTAKeyboardServices)
    .AddKeyboardBinding(TJotaKeyBindings.Create);
  RegisterJotaMenu;
  RegisterSplashScreen;
end;

procedure UnregisterJotaWizards;
begin
  UnregisterJotaMenu;

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
