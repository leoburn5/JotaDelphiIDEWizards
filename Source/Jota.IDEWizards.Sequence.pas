unit Jota.IDEWizards.Sequence;

interface

uses
  System.SysUtils,
  Jota.IDEWizards.Config;

type
  EJotaSequenceError = class(Exception);

  TJotaSequenceKind = (sqkParametroEmpresa, sqkParametroSistema, sqkFuncaoPrograma, sqkMenu);

  TJotaSequenceParam = record
    Name: string;
    Caption: string;
    IsIndicator: Boolean;
  end;

  TJotaSequenceDefinition = record
    Caption: string;
    FunctionName: string;
    Params: TArray<TJotaSequenceParam>;
  end;

const
  SequenceKindCaptions: array[TJotaSequenceKind] of string = (
    'Parâmetro por empresa [cps_emp]',
    'Parâmetro do sistema [spkcps]',
    'Função Programa [spkfupr]',
    'Menu [spkspk]');

function GetSequenceDefinition(AKind: TJotaSequenceKind): TJotaSequenceDefinition;
function ValidateSequenceConfig(const AConfig: TJotaBaseDadosSequencias): string;
function ExecuteSequenceFunction(const AConfig: TJotaBaseDadosSequencias; const AVendorLib: string;
  const ADefinition: TJotaSequenceDefinition; const AValues: TArray<string>): string;
function FindLastScriptFile(const AFolder, APrefix: string): string;
function NewScriptFileName(const AFolder, APrefix: string): string;
function AppendScriptToFile(const AFolder, APrefix, AScript: string; out ACreated: Boolean): string;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Jota.IDEWizards.Metadata;

function MakeParam(const AName, ACaption: string; AIsIndicator: Boolean = False): TJotaSequenceParam;
begin
  Result.Name := AName;
  Result.Caption := ACaption;
  Result.IsIndicator := AIsIndicator;
end;

function GetSequenceDefinition(AKind: TJotaSequenceKind): TJotaSequenceDefinition;
begin
  Result.Caption := SequenceKindCaptions[AKind];
  case AKind of
    sqkParametroEmpresa:
      begin
        Result.FunctionName := 'fu_get_sequencia_cps_emp_defs';
        Result.Params := [
          MakeParam('e_des_parametro', 'Descrição do parâmetro'),
          MakeParam('e_val_padrao', 'Valor padrão'),
          MakeParam('e_des_predominancia', 'Descrição da predominância')];
      end;
    sqkParametroSistema:
      begin
        Result.FunctionName := 'fu_get_sequencia_spkcps';
        Result.Params := [
          MakeParam('e_des_parametro', 'Descrição do parâmetro'),
          MakeParam('e_val_parametro', 'Valor do parâmetro'),
          MakeParam('e_informacao_parametro', 'Informação do parâmetro')];
      end;
    sqkFuncaoPrograma:
      begin
        Result.FunctionName := 'fu_get_sequencia_spkfupr';
        Result.Params := [
          MakeParam('e_des_funcao', 'Descrição da função')];
      end;
    sqkMenu:
      begin
        Result.FunctionName := 'fu_get_sequencia_spkspk';
        Result.Params := [
          MakeParam('e_des_programa', 'Descrição do programa'),
          MakeParam('e_ind_modulo', 'É módulo', True)];
      end;
  end;
end;

function ValidateSequenceConfig(const AConfig: TJotaBaseDadosSequencias): string;
begin
  Result := '';
  if not AConfig.IsConfigured then
    Result := 'A base de dados de sequências não está configurada.'
  else if AConfig.PrefixoArquivosScript = '' then
    Result := 'O prefixo dos scripts não está configurado.'
  else if AConfig.PastaArquivosScript = '' then
    Result := 'A pasta dos scripts não está configurada.'
  else if not DirectoryExists(AConfig.PastaArquivosScript) then
    Result := 'A pasta dos scripts não existe:' + sLineBreak + AConfig.PastaArquivosScript;
end;

function BuildFunctionCallSql(const ADefinition: TJotaSequenceDefinition): string;
var
  I: Integer;
  Arguments: string;
begin
  Arguments := '';
  for I := 0 to High(ADefinition.Params) do
  begin
    if I > 0 then
      Arguments := Arguments + ', ';
    if ADefinition.Params[I].IsIndicator then
      Arguments := Arguments + ':p' + IntToStr(I) + '::char(1)'
    else
      Arguments := Arguments + ':p' + IntToStr(I) + '::varchar';
  end;
  Result := 'select s_script from ' + ADefinition.FunctionName + '(' + Arguments + ')';
end;

function ExecuteSequenceFunction(const AConfig: TJotaBaseDadosSequencias; const AVendorLib: string;
  const ADefinition: TJotaSequenceDefinition; const AValues: TArray<string>): string;
var
  Connection: TFDConnection;
  Qry: TFDQuery;
  UsesSsl: Boolean;
  I: Integer;
begin
  Connection := CreateBaseDadosSequenciasConnection(AConfig, AVendorLib, UsesSsl);
  try
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := Connection;
      Qry.ResourceOptions.MacroCreate := False;
      Qry.ResourceOptions.MacroExpand := False;
      Qry.SQL.Text := BuildFunctionCallSql(ADefinition);
      for I := 0 to High(ADefinition.Params) do
      begin
        Qry.Params[I].DataType := ftWideString;
        Qry.Params[I].AsWideString := AValues[I];
      end;
      Qry.Open;
      if Qry.IsEmpty then
        raise EJotaSequenceError.CreateFmt('A função %s não retornou o script.',
          [ADefinition.FunctionName]);
      Result := Qry.Fields[0].AsString;
      Qry.Close;
    finally
      Qry.Free;
    end;
    Connection.Connected := False;
  finally
    Connection.Free;
  end;
end;

function FindLastScriptFile(const AFolder, APrefix: string): string;
var
  Files: TList<string>;
  FileName: string;
begin
  Result := '';
  Files := TList<string>.Create;
  try
    for FileName in TDirectory.GetFiles(AFolder) do
      if ContainsText(ExtractFileName(FileName), APrefix) then
        Files.Add(FileName);

    Files.Sort(TComparer<string>.Construct(
      function(const ALeft, ARight: string): Integer
      begin
        Result := CompareText(ExtractFileName(ALeft), ExtractFileName(ARight));
      end));

    if Files.Count > 0 then
      Result := Files.Last;
  finally
    Files.Free;
  end;
end;

function NewScriptFileName(const AFolder, APrefix: string): string;
begin
  Result := TPath.Combine(AFolder, FormatDateTime('yyyymmdd', Date) + ' - ' + APrefix +
    ' - AlterarNome.sql');
end;

function FileEndsWithLineBreak(const AFileName: string): Boolean;
var
  Stream: TFileStream;
  LastByte: Byte;
begin
  Result := True;
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size > 0 then
    begin
      Stream.Position := Stream.Size - 1;
      Stream.ReadBuffer(LastByte, 1);
      Result := LastByte = 10;
    end;
  finally
    Stream.Free;
  end;
end;

procedure AppendUtf8(const AFileName, AText: string);
var
  Stream: TFileStream;
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(AText);
  Stream := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyWrite);
  try
    Stream.Position := Stream.Size;
    if Length(Bytes) > 0 then
      Stream.WriteBuffer(Bytes[0], Length(Bytes));
  finally
    Stream.Free;
  end;
end;

function AppendScriptToFile(const AFolder, APrefix, AScript: string; out ACreated: Boolean): string;
var
  Separator: string;
begin
  Result := FindLastScriptFile(AFolder, APrefix);
  ACreated := Result = '';
  if ACreated then
  begin
    Result := NewScriptFileName(AFolder, APrefix);
    TFile.WriteAllBytes(Result, TEncoding.UTF8.GetPreamble +
      TEncoding.UTF8.GetBytes(AScript + sLineBreak));
  end
  else
  begin
    if FileEndsWithLineBreak(Result) then
      Separator := sLineBreak
    else
      Separator := sLineBreak + sLineBreak;
    AppendUtf8(Result, Separator + AScript + sLineBreak);
  end;
end;

end.
