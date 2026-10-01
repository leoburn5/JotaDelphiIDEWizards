unit Jota.IDEWizards.Config;

interface

uses
  System.SysUtils;

const
  JotaConfigFileName = 'JotaDelphiIdeWizards.Cfg.Json';
  DefaultPostgreSQLHost = 'localhost';
  DefaultPostgreSQLPort = 5432;

type
  EJotaConfigError = class(Exception);

  TJotaBaseDadosTrabalho = record
    Host: string;
    Porta: Integer;
    NomeBD: string;
    Usuario: string;
    Senha: string;
    VendorLib32: string;
    VendorLib64: string;
    class function Default: TJotaBaseDadosTrabalho; static;
    function IsConfigured: Boolean;
    function ActiveVendorLib: string;
  end;

function GetJotaConfigFilePath: string;
function LoadBaseDadosTrabalho: TJotaBaseDadosTrabalho;
procedure SaveBaseDadosTrabalho(const AConfig: TJotaBaseDadosTrabalho);

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.NetEncoding,
  Winapi.Windows;

const
  JsonBaseDadosTrabalho = 'BaseDadosTrabalho';
  JsonHost = 'Host';
  JsonPorta = 'Porta';
  JsonNomeBD = 'NomeBD';
  JsonUsuario = 'Usuario';
  JsonSenha = 'Senha';
  JsonVendorLib32 = 'VendorLib32';
  JsonVendorLib64 = 'VendorLib64';

function EncodeSenha(const APlain: string): string;
var
  Encoding: TBase64Encoding;
begin
  Result := '';
  if APlain <> '' then
  begin
    Encoding := TBase64Encoding.Create(0);
    try
      Result := Encoding.EncodeBytesToString(TEncoding.UTF8.GetBytes(APlain));
    finally
      Encoding.Free;
    end;
  end;
end;

function DecodeSenha(const AStored: string): string;
var
  Encoding: TBase64Encoding;
begin
  Result := '';
  if AStored <> '' then
  begin
    Encoding := TBase64Encoding.Create(0);
    try
      try
        Result := TEncoding.UTF8.GetString(Encoding.DecodeStringToBytes(AStored));
      except
        on EEncodingError do
          Result := '';
      end;
    finally
      Encoding.Free;
    end;
  end;
end;

class function TJotaBaseDadosTrabalho.Default: TJotaBaseDadosTrabalho;
begin
  Result.Host := DefaultPostgreSQLHost;
  Result.Porta := DefaultPostgreSQLPort;
  Result.NomeBD := '';
  Result.Usuario := '';
  Result.Senha := '';
  Result.VendorLib32 := '';
  Result.VendorLib64 := '';
end;

function TJotaBaseDadosTrabalho.ActiveVendorLib: string;
begin
{$IFDEF WIN64}
  Result := VendorLib64;
{$ELSE}
  Result := VendorLib32;
{$ENDIF}
end;

function TJotaBaseDadosTrabalho.IsConfigured: Boolean;
begin
  Result := (Host <> '') and (Porta > 0) and (NomeBD <> '') and (Usuario <> '');
end;

function GetJotaConfigFilePath: string;
begin
  Result := TPath.Combine(TPath.Combine(TPath.GetHomePath, 'JotaDelphiIDEWizards'),
    JotaConfigFileName);
end;

function ReadRootObject(const APath: string): TJSONObject;
var
  Text: string;
  Value: TJSONValue;
begin
  Result := nil;
  if TFile.Exists(APath) then
  begin
    Text := TFile.ReadAllText(APath, TEncoding.UTF8);
    if Trim(Text) <> '' then
    begin
      Value := TJSONObject.ParseJSONValue(Text);
      if Value is TJSONObject then
        Result := TJSONObject(Value)
      else
      begin
        Value.Free;
        raise EJotaConfigError.CreateFmt('O arquivo de configuração não é um JSON válido:'
          + sLineBreak + '%s', [APath]);
      end;
    end;
  end;
end;

function ReadString(AObj: TJSONObject; const AName, ADefault: string): string;
begin
  if not AObj.TryGetValue<string>(AName, Result) then
    Result := ADefault;
end;

function ReadInteger(AObj: TJSONObject; const AName: string; ADefault: Integer): Integer;
var
  Value: TJSONValue;
begin
  Value := AObj.GetValue(AName);
  if Value is TJSONNumber then
    Result := TJSONNumber(Value).AsInt
  else if Value is TJSONString then
    Result := StrToIntDef(TJSONString(Value).Value, ADefault)
  else
    Result := ADefault;
end;

function LoadBaseDadosTrabalho: TJotaBaseDadosTrabalho;
var
  Root: TJSONObject;
  Obj: TJSONObject;
begin
  Result := TJotaBaseDadosTrabalho.Default;

  Root := ReadRootObject(GetJotaConfigFilePath);
  if Root <> nil then
  try
    if Root.TryGetValue<TJSONObject>(JsonBaseDadosTrabalho, Obj) then
    begin
      Result.Host := ReadString(Obj, JsonHost, Result.Host);
      Result.Porta := ReadInteger(Obj, JsonPorta, Result.Porta);
      Result.NomeBD := ReadString(Obj, JsonNomeBD, '');
      Result.Usuario := ReadString(Obj, JsonUsuario, '');
      Result.Senha := DecodeSenha(ReadString(Obj, JsonSenha, ''));
      Result.VendorLib32 := ReadString(Obj, JsonVendorLib32, '');
      Result.VendorLib64 := ReadString(Obj, JsonVendorLib64, '');
    end;
  finally
    Root.Free;
  end;
end;

procedure WriteFileAtomically(const APath, AText: string);
var
  TempPath: string;
begin
  TempPath := APath + '.tmp';
  TFile.WriteAllBytes(TempPath, TEncoding.UTF8.GetBytes(AText));
  if not MoveFileEx(PChar(TempPath), PChar(APath),
    MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
    raise EJotaConfigError.CreateFmt('Não foi possível gravar "%s": %s',
      [APath, SysErrorMessage(GetLastError)]);
end;

procedure SaveBaseDadosTrabalho(const AConfig: TJotaBaseDadosTrabalho);
var
  Path: string;
  Root: TJSONObject;
  Obj: TJSONObject;
begin
  Path := GetJotaConfigFilePath;
  ForceDirectories(ExtractFilePath(Path));

  try
    Root := ReadRootObject(Path);
  except
    on EJotaConfigError do
    begin
      TFile.Copy(Path, Path + '.bak', True);
      Root := nil;
    end;
  end;

  if Root = nil then
    Root := TJSONObject.Create;
  try
    Root.RemovePair(JsonBaseDadosTrabalho).Free;

    Obj := TJSONObject.Create;
    Root.AddPair(JsonBaseDadosTrabalho, Obj);
    Obj.AddPair(JsonHost, AConfig.Host);
    Obj.AddPair(JsonPorta, TJSONNumber.Create(AConfig.Porta));
    Obj.AddPair(JsonNomeBD, AConfig.NomeBD);
    Obj.AddPair(JsonUsuario, AConfig.Usuario);
    Obj.AddPair(JsonSenha, EncodeSenha(AConfig.Senha));
    Obj.AddPair(JsonVendorLib32, AConfig.VendorLib32);
    Obj.AddPair(JsonVendorLib64, AConfig.VendorLib64);

    WriteFileAtomically(Path, Root.Format(2));
  finally
    Root.Free;
  end;
end;

end.
