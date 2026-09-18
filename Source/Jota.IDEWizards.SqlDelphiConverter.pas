unit Jota.IDEWizards.SqlDelphiConverter;

{
  Conversao (nos dois sentidos) entre um script SQL "puro" e uma constante
  string Delphi multilinha, no formato usado em
  ExemploQuerySqlToConsntantString.txt:

      'linha 1 do sql...' + sLineBreak +
      'linha 2 do sql...' + sLineBreak +
      'ultima linha do sql';

  - Aspas simples do SQL sao escapadas dobrando: ' -> ''
  - Cada linha do SQL vira uma linha de codigo, com indentacao fixa e
    preenchida com espacos para todas ficarem do mesmo tamanho.
}

interface

/// <summary>
///   Converte um script SQL em uma constante string Delphi multilinha,
///   uma linha do SQL por linha de codigo, concatenada com sLineBreak.
/// </summary>
function SqlToDelphiConstant(const SqlScript: string): string;

/// <summary>
///   Converte um script SQL em um "ObjectSqlScript": chamadas
///   "&lt;ObjectName&gt;.Sql.Add('...');", uma por linha do SQL, no
///   formato usado em ExemploObjectQueryToSqlScript.txt.
/// </summary>
function SqlToObjectSqlScript(const SqlScript: string;
  const ObjectName: string = 'MyQuery'): string;

/// <summary>
///   Caminho inverso: recebe uma constante string Delphi (contendo
///   sLineBreak) e reconstroi o script SQL original, uma linha por linha.
/// </summary>
function DelphiConstantToSql(const DelphiConst: string): string;

/// <summary>
///   Recebe um "ObjectSqlScript": um objeto de query (TQuery, TFDQuery,
///   TZQuery etc.) montado linha a linha com
///   "&lt;Objeto&gt;.Sql.Add('...');", e reconstroi o script SQL puro
///   original, pronto para rodar em uma ferramenta como o DBeaver.
/// </summary>
function ObjectSqlScriptToSql(const ObjectSqlScript: string): string;

implementation

uses
  System.SysUtils,
  System.Classes;

const
  IndentSpaces = 6;
  SLineBreakSuffix = ' + sLineBreak +';

function SqlToDelphiConstant(const SqlScript: string): string;
var
  Lines: TStringList;
  EscapedLines: TStringList;
  Output: TStringList;
  MaxLen: Integer;
  I: Integer;
  Line: string;
  Indent: string;
begin
  Indent := StringOfChar(' ', IndentSpaces);

  Lines := TStringList.Create;
  EscapedLines := TStringList.Create;
  Output := TStringList.Create;
  try
    Lines.Text := SqlScript;

    // Escapa aspas simples (' -> '') e descobre a maior linha, para
    // alinhar todas as linhas na mesma largura.
    MaxLen := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := StringReplace(Lines[I], '''', '''''', [rfReplaceAll]);
      EscapedLines.Add(Line);
      if Length(Line) > MaxLen then
        MaxLen := Length(Line);
    end;

    for I := 0 to EscapedLines.Count - 1 do
    begin
      Line := EscapedLines[I];
      Line := Line + StringOfChar(' ', MaxLen - Length(Line));

      if I < EscapedLines.Count - 1 then
        Output.Add(Indent + '''' + Line + '''' + SLineBreakSuffix)
      else
        Output.Add(Indent + '''' + Line + ''';');
    end;

    Result := TrimRight(Output.Text);
  finally
    Lines.Free;
    EscapedLines.Free;
    Output.Free;
  end;
end;

// Varre uma linha de codigo Delphi e extrai o conteudo de todo(s) literal(is)
// de string presentes nela (tratando '' como aspas simples escapada).
// Found indica se algum literal de string foi encontrado na linha (mesmo
// que vazio, ex: '').
function SqlToObjectSqlScript(const SqlScript: string;
  const ObjectName: string): string;
const
  IndentSpaces = 2;
var
  Lines: TStringList;
  Output: TStringList;
  I: Integer;
  EscapedLine: string;
  Indent: string;
begin
  Indent := StringOfChar(' ', IndentSpaces);

  Lines := TStringList.Create;
  Output := TStringList.Create;
  try
    Lines.Text := SqlScript;

    for I := 0 to Lines.Count - 1 do
    begin
      EscapedLine := StringReplace(Lines[I], '''', '''''', [rfReplaceAll]);
      Output.Add(Indent + ObjectName + '.Sql.Add(''' + EscapedLine + ''');');
    end;

    Result := TrimRight(Output.Text);
  finally
    Lines.Free;
    Output.Free;
  end;
end;

function ExtractQuotedLiterals(const Line: string; out Found: Boolean): string;
var
  I, Len: Integer;
  InString: Boolean;
  C: Char;
begin
  Result := '';
  Found := False;
  InString := False;
  I := 1;
  Len := Length(Line);

  while I <= Len do
  begin
    C := Line[I];

    if not InString then
    begin
      if C = '''' then
      begin
        InString := True;
        Found := True;
      end;
      Inc(I);
    end
    else
    begin
      if C = '''' then
      begin
        if (I < Len) and (Line[I + 1] = '''') then
        begin
          // '' dentro da string = aspas simples literal
          Result := Result + '''';
          Inc(I, 2);
        end
        else
        begin
          InString := False;
          Inc(I);
        end;
      end
      else
      begin
        Result := Result + C;
        Inc(I);
      end;
    end;
  end;
end;

function DelphiConstantToSql(const DelphiConst: string): string;
var
  Lines: TStringList;
  Output: TStringList;
  I: Integer;
  Extracted: string;
  Found: Boolean;
begin
  Lines := TStringList.Create;
  Output := TStringList.Create;
  try
    Lines.Text := DelphiConst;

    for I := 0 to Lines.Count - 1 do
    begin
      Extracted := ExtractQuotedLiterals(Lines[I], Found);
      if Found then
        Output.Add(TrimRight(Extracted));
    end;

    Result := TrimRight(Output.Text);
  finally
    Lines.Free;
    Output.Free;
  end;
end;

function ObjectSqlScriptToSql(const ObjectSqlScript: string): string;
begin
  // Mesma extracao de literais de string por linha usada em
  // DelphiConstantToSql: ExtractQuotedLiterals ignora tudo que estiver
  // fora das aspas (identificador do objeto, ".Sql.Add(", ");"), entao
  // o mesmo algoritmo serve tanto para "'...' + sLineBreak +" quanto
  // para "Objeto.Sql.Add('...');".
  Result := DelphiConstantToSql(ObjectSqlScript);
end;

end.
