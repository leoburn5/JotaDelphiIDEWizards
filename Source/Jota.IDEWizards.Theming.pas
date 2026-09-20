unit Jota.IDEWizards.Theming;

{
  Aplica aos formularios do "Jota IDE Wizards":

  1) O VCL Style que a IDE do Delphi esta usando no momento (Windows11
     Modern Light ou Dark, ou outro escolhido em Tools > Options >
     Appearance), via o mecanismo oficial para plugins de terceiros
     (RAD Studio DocWiki, "Using IDE Styles in Third-Party Plugins"):
       IOTAIDEThemingServices.RegisterFormClass(FormClass)
       IOTAIDEThemingServices.ApplyTheme(Form)
     Isso estiliza os controles do form (fundo, botoes, labels).

  2) O icone do projeto (icons\JotaIDEWizards.ico, ao lado da pasta
     "bpl" onde o pacote compilado fica) na barra de titulo. O caminho
     e calculado em tempo de execucao a partir da localizacao do
     proprio pacote (.bpl) carregado, entao nao depende de uma pasta
     fixa de uma maquina especifica.

  3) A cor de destaque ("accent") do proprio VCL Style ativo (a mesma
     cor azul usada nos botoes/realces do tema) na barra de titulo
     NATIVA do Windows, via a API do DWM (DwmSetWindowAttribute com
     DWMWA_CAPTION_COLOR / DWMWA_TEXT_COLOR - Windows 11 build 22000+,
     a mesma API que o Explorer/Windows Terminal usam pra colorir a
     propria barra de titulo).

  IMPORTANTE: ApplyIdeMatchingStyle deve ser chamado no FINAL do
  construtor do formulario, depois de BorderStyle/BorderIcons/controles
  filhos ja definidos. Essas propriedades recriam o handle da janela
  (RecreateWnd); se a cor do DWM fosse aplicada antes, seria perdida
  na recriacao. A chamada a AForm.Handle dentro desta unit forca a
  criacao do handle (caso ainda nao exista) para poder aplicar a cor.

  Observacao sobre o icone: formularios com BorderStyle = bsDialog nao
  desenham o icone na barra de titulo (convencao do Windows para
  janelas de dialogo). Por isso os formularios do projeto usam
  BorderStyle = bsSingle com BorderIcons = [biSystemMenu] (sem
  minimizar/maximizar - mesmo efeito visual de bsDialog, mas com
  icone).
}

interface

uses
  Vcl.Forms;

/// <summary>
///   Aplica a AForm o VCL Style que a IDE do Delphi esta usando
///   atualmente, o icone do projeto e a cor de destaque do tema na
///   barra de titulo nativa. Deve ser chamado por ultimo no
///   construtor do formulario, depois de BorderStyle, BorderIcons e
///   todos os controles filhos ja estarem definidos. Se nao for
///   possivel obter os servicos de tema da IDE, ou o tema estiver
///   desabilitado, nao faz nada.
/// </summary>
procedure ApplyIdeMatchingStyle(AForm: TForm);

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  Vcl.Graphics,
  ToolsAPI;

const
  DWMWA_CAPTION_COLOR = 35;
  DWMWA_TEXT_COLOR = 36;

function DwmSetWindowAttribute(hWnd: HWND; dwAttribute: DWORD;
  pvAttribute: Pointer; cbAttribute: DWORD): HRESULT; stdcall;
  external 'dwmapi.dll';

function GetProjectIconPath: string;
var
  PackageDir: string;
  ProjectDir: string;
begin
  // O pacote compilado (.bpl) fica em <projeto>\bpl\; os icones ficam
  // em <projeto>\icons\ - calculado a partir do proprio .bpl, sem
  // caminho fixo de maquina.
  PackageDir := ExtractFilePath(GetModuleName(HInstance));
  ProjectDir := ExtractFilePath(ExcludeTrailingPathDelimiter(PackageDir));
  Result := ProjectDir + 'icons\JotaIDEWizards.ico';
end;

procedure ApplyIdeMatchingStyle(AForm: TForm);
var
  ThemingServices: IOTAIDEThemingServices;
  AccentColor: TColor;
  AccentTextColor: TColor;
  CaptionColorRef: DWORD;
  TextColorRef: DWORD;
  IconPath: string;
  Wnd: HWND;
begin
  if not Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices) then
    Exit;

  if not ThemingServices.IDEThemingEnabled then
    Exit;

  ThemingServices.RegisterFormClass(TCustomFormClass(AForm.ClassType));
  ThemingServices.ApplyTheme(AForm);

  IconPath := GetProjectIconPath;
  if FileExists(IconPath) then
    AForm.Icon.LoadFromFile(IconPath);

  if ThemingServices.StyleServices = nil then
    Exit;

  AccentColor := ColorToRGB(ThemingServices.StyleServices.GetSystemColor(clHighlight));
  AccentTextColor := ColorToRGB(ThemingServices.StyleServices.GetSystemColor(clHighlightText));

  Wnd := AForm.Handle; // forca a criacao do handle, se ainda nao existir

  CaptionColorRef := DWORD(AccentColor);
  DwmSetWindowAttribute(Wnd, DWMWA_CAPTION_COLOR, @CaptionColorRef, SizeOf(CaptionColorRef));

  TextColorRef := DWORD(AccentTextColor);
  DwmSetWindowAttribute(Wnd, DWMWA_TEXT_COLOR, @TextColorRef, SizeOf(TextColorRef));
end;

end.
