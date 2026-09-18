unit Jota.IDEWizards.Theming;

{
  Aplica aos formularios do "Jota IDE Wizards" o VCL Style que combina com
  o tema atual da IDE: "Windows11 Modern Light" se a IDE estiver no tema
  claro, "Windows11 Modern Dark" se estiver no tema escuro.

  Usa o recurso de "Per-Control Styles" (propriedade TControl.StyleName,
  disponivel desde o Delphi 10.4) para estilizar somente os nossos
  proprios formularios, sem alterar o estilo global da IDE. Atribuir um
  nome de estilo que nao esteja carregado e inofensivo: o controle
  simplesmente usa o estilo padrao (documentacao da Embarcadero sobre
  Per-Control Styles).
}

interface

uses
  Vcl.Controls;

/// <summary>
///   Aplica a AControl (tipicamente um TForm) o VCL Style "Windows11
///   Modern Light" ou "Windows11 Modern Dark", conforme o tema atual da
///   IDE. Se nao for possivel detectar o tema da IDE (versao antiga sem
///   IOTAIDEThemingServices, por exemplo), nao faz nada.
/// </summary>
procedure ApplyIdeMatchingStyle(AControl: TControl);

implementation

uses
  System.SysUtils,
  ToolsAPI,
  Vcl.Themes;

const
  LightStyleName = 'Windows11 Modern Light';
  DarkStyleName = 'Windows11 Modern Dark';

procedure ApplyIdeMatchingStyle(AControl: TControl);
var
  ThemingServices: IOTAIDEThemingServices;
  IsDarkTheme: Boolean;
begin
  if not Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices) then
    Exit;

  if ThemingServices.StyleServices = nil then
    Exit;

  IsDarkTheme := Pos('Dark', ThemingServices.StyleServices.Name) > 0;

  if IsDarkTheme then
    AControl.StyleName := DarkStyleName
  else
    AControl.StyleName := LightStyleName;
end;

end.
