unit Jota.IDEWizards.SplashScreen;

{
  Registra o icone/legenda do "Jota IDE Wizards" na splash screen do
  Delphi, via SplashScreenServices (IOTASplashScreenServices), disponivel
  desde o Delphi 2005. A IDE exige um bitmap 24x24 para esse fim.

  O icone e carregado de um arquivo PNG (24x24) no disco, em vez de ser
  compilado como recurso .res, para nao depender de brcc32/rc no build.
  O caminho e calculado em tempo de execucao a partir da localizacao do
  proprio pacote (.bpl) carregado (<projeto>\bpl\...bpl -> <projeto>\icons\
  icon24.png), entao nao depende de uma pasta fixa de uma maquina
  especifica.

  A splash screen da IDE nao suporta canal alfa de verdade - ela so
  reconhece transparencia "color-key" (uma cor especifica vira
  transparente). Se a gente preencher o fundo do bitmap com uma cor
  fixa (branco, por exemplo) e a splash screen usar outro fundo (como
  o gradiente vinho/rosa do Delphi 13), o icone aparece como uma caixa
  solida feia por cima do fundo. Por isso, antes de desenhar o PNG,
  a gente detecta a cor real de fundo da splash screen (tecnica
  documentada em parnassus.co/antialiased-images-delphi-splash-screen)
  e preenche o bitmap com ela, para as bordas anti-aliased do icone se
  misturarem naturalmente com o fundo de verdade.

  A versao mostrada (ex.: "1.0.0.2") vem direto do campo "FileVersion"
  do VERSIONINFO embutido no proprio .bpl compilado (Project Options >
  Version Info > grid de baixo, chave "FileVersion"), lido em tempo de
  execucao via GetFileVersionInfo/VerQueryValue - nao e mais uma string
  fixa no codigo. O projeto ja tem "Auto generate build number" ligado,
  entao o 4o numero (build) sobe sozinho a cada compilacao, e a splash
  screen reflete exatamente esse valor.
}

interface

/// <summary>
///   Adiciona a entrada do "Jota IDE Wizards" na splash screen da IDE.
///   Chamar uma unica vez, no carregamento do pacote (initialization).
/// </summary>
procedure RegisterSplashScreen;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  Vcl.Imaging.PngImage,
  Vcl.Forms,
  ToolsAPI;

const
  JotaIDEWizardsFallbackVersion = '1.0.0';
  SplashIconSize = 24;

function GetSplashIconPath: string;
var
  PackageDir: string;
  ProjectDir: string;
begin
  // O pacote compilado (.bpl) fica em <projeto>\bpl\; os icones ficam
  // em <projeto>\icons\ - calculado a partir do proprio .bpl, sem
  // caminho fixo de maquina.
  PackageDir := ExtractFilePath(GetModuleName(HInstance));
  ProjectDir := ExtractFilePath(ExcludeTrailingPathDelimiter(PackageDir));
  Result := ProjectDir + 'icons\icon24.png';
end;

function FindSplashScreenBackgroundColor: TColor;
var
  I: Integer;
  CandidateForm: TCustomForm;
  SplashForm: TCustomForm;
  SplashBmp: TBitmap;
begin
  // Fallback razoavel se a splash screen nao for encontrada: mais
  // proximo do fundo escuro das splash screens modernas do Delphi do
  // que branco.
  Result := clBlack;

  SplashForm := nil;
  for I := 0 to Screen.FormCount - 1 do
  begin
    CandidateForm := Screen.Forms[I];
    if SameText(CandidateForm.Caption, 'SplashScreen')
      or (Pos('SPLASH', UpperCase(CandidateForm.ClassName)) > 0) then
    begin
      SplashForm := CandidateForm;
      Break;
    end;
  end;

  if SplashForm = nil then
    Exit;

  SplashBmp := TBitmap.Create;
  try
    SplashBmp.Width := SplashForm.ClientWidth;
    SplashBmp.Height := SplashForm.ClientHeight;
    if (SplashBmp.Width <= 0) or (SplashBmp.Height <= 0) then
      Exit;

    SplashForm.PaintTo(SplashBmp.Canvas.Handle, 0, 0);

    // Amostra um pixel perto de onde a lista de icones de plugins fica
    // (canto inferior esquerdo da area dos icones) - mesma tecnica
    // documentada por parnassus.co para blend de icones na splash
    // screen do Delphi.
    Result := SplashBmp.Canvas.Pixels[4, SplashBmp.Height - (SplashBmp.Height div 4)];
  finally
    SplashBmp.Free;
  end;
end;

type
  TVerTranslation = packed record
    Language: Word;
    CodePage: Word;
  end;

// Le o valor de string exato da chave "FileVersion" (StringFileInfo),
// a mesma que aparece na grid de Project Options > Version Info. Usa o
// par idioma/codepage de \VarFileInfo\Translation, que e como o
// VERSIONINFO indica em qual subbloco de strings procurar.
function GetFileVersionString(VerInfoBuf: Pointer): string;
var
  TranslationPtr: Pointer;
  TranslationLen: UINT;
  Translation: TVerTranslation;
  SubBlock: string;
  ValuePtr: Pointer;
  ValueLen: UINT;
begin
  Result := '';

  if not VerQueryValue(VerInfoBuf, '\VarFileInfo\Translation', TranslationPtr, TranslationLen) then
    Exit;
  if TranslationLen < SizeOf(TVerTranslation) then
    Exit;

  Move(TranslationPtr^, Translation, SizeOf(Translation));

  SubBlock := Format('\StringFileInfo\%.4x%.4x\FileVersion',
    [Translation.Language, Translation.CodePage]);

  if not VerQueryValue(VerInfoBuf, PChar(SubBlock), ValuePtr, ValueLen) then
    Exit;

  Result := string(PChar(ValuePtr));
end;

// Respaldo: monta a versao a partir dos 4 numeros do bloco fixo
// (VS_FIXEDFILEINFO), caso o bloco de strings nao exista por algum
// motivo. Normalmente identico ao que GetFileVersionString retorna.
function GetFixedFileVersion(VerInfoBuf: Pointer): string;
var
  FixedInfoPtr: Pointer;
  FixedInfo: PVSFixedFileInfo;
  FixedInfoLen: UINT;
  MajorVer, MinorVer, ReleaseVer, BuildVer: Word;
begin
  Result := '';

  if not VerQueryValue(VerInfoBuf, '\', FixedInfoPtr, FixedInfoLen) then
    Exit;

  FixedInfo := PVSFixedFileInfo(FixedInfoPtr);

  MajorVer := FixedInfo.dwFileVersionMS shr 16;
  MinorVer := FixedInfo.dwFileVersionMS and $FFFF;
  ReleaseVer := FixedInfo.dwFileVersionLS shr 16;
  BuildVer := FixedInfo.dwFileVersionLS and $FFFF;

  Result := Format('%d.%d.%d.%d', [MajorVer, MinorVer, ReleaseVer, BuildVer]);
end;

function GetPackageFileVersion: string;
var
  ModulePath: string;
  InfoSize: DWORD;
  Dummy: DWORD;
  VerInfoBuf: Pointer;
begin
  Result := '';

  ModulePath := GetModuleName(HInstance);

  InfoSize := GetFileVersionInfoSize(PChar(ModulePath), Dummy);
  if InfoSize = 0 then
    Exit;

  GetMem(VerInfoBuf, InfoSize);
  try
    if not GetFileVersionInfo(PChar(ModulePath), 0, InfoSize, VerInfoBuf) then
      Exit;

    // Fonte primaria: a string "FileVersion" configurada em Project
    // Options > Version Info. Se nao existir, cai para o bloco fixo.
    Result := GetFileVersionString(VerInfoBuf);
    if Result = '' then
      Result := GetFixedFileVersion(VerInfoBuf);
  finally
    FreeMem(VerInfoBuf);
  end;
end;

function GetDisplayVersion: string;
begin
  // Le a versao de verdade do .bpl compilado (Project Options > Version
  // Info); se por algum motivo nao conseguir (nenhum VERSIONINFO
  // embutido, por exemplo), cai para a constante fixa como fallback.
  Result := GetPackageFileVersion;
  if Result = '' then
    Result := JotaIDEWizardsFallbackVersion;
end;

procedure RegisterSplashScreen;
var
  PngIcon: TPngImage;
  Bitmap: TBitmap;
  SplashIconPath: string;
begin
  if SplashScreenServices = nil then
    Exit;

  SplashIconPath := GetSplashIconPath;
  if not FileExists(SplashIconPath) then
    Exit;

  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(SplashIconSize, SplashIconSize);
    Bitmap.Canvas.Brush.Color := FindSplashScreenBackgroundColor;
    Bitmap.Canvas.FillRect(Rect(0, 0, SplashIconSize, SplashIconSize));

    PngIcon := TPngImage.Create;
    try
      PngIcon.LoadFromFile(SplashIconPath);
      // TPngImage.Draw compõe a transparência do PNG sobre o que ja
      // estiver no canvas (o fundo com a cor da splash screen, preenchido
      // acima).
      Bitmap.Canvas.Draw(0, 0, PngIcon);
    finally
      PngIcon.Free;
    end;

    SplashScreenServices.AddPluginBitmap(
      'Jota Delphi IDE Wizards ' + GetDisplayVersion,
      Bitmap.Handle,
      False,
      '',
      '');
  finally
    Bitmap.Free;
  end;
end;

end.
