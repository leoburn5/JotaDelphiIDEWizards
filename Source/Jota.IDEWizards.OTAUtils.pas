unit Jota.IDEWizards.OTAUtils;

{
  Funcoes utilitarias de acesso ao Open Tools API (OTA) do Delphi.
  Usadas por todos os experts/atalhos do pacote "Jota IDE Wizards".
}

interface

uses
  ToolsAPI;

/// <summary>
///   Retorna o IOTASourceEditor do modulo atualmente ativo na IDE.
///   Retorna nil se nao houver um editor de codigo-fonte ativo
///   (por exemplo, com o Form Designer em foco).
/// </summary>
function GetActiveSourceEditor: IOTASourceEditor;

/// <summary>
///   Retorna a primeira IOTAEditView do editor de codigo-fonte ativo.
///   Retorna nil se nao houver editor ativo.
/// </summary>
function GetActiveEditView: IOTAEditView;

/// <summary>
///   Retorna o texto atualmente selecionado no editor de codigo.
///   Retorna string vazia se nao houver selecao ou nao houver editor ativo.
/// </summary>
function GetSelectedText: string;

/// <summary>
///   Substitui o texto atualmente selecionado no editor de codigo por
///   NewText. Nao faz nada se nao houver editor ativo ou nao houver
///   selecao valida.
/// </summary>
procedure ReplaceSelectedText(const NewText: string);

implementation

uses
  System.SysUtils;

function GetActiveSourceEditor: IOTASourceEditor;
var
  Module: IOTAModule;
  I: Integer;
begin
  Result := nil;

  if BorlandIDEServices = nil then
    Exit;

  Module := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  if Module = nil then
    Exit;

  for I := 0 to Module.GetModuleFileCount - 1 do
    if Supports(Module.GetModuleFileEditor(I), IOTASourceEditor, Result) then
      Exit;
end;

function GetActiveEditView: IOTAEditView;
var
  SourceEditor: IOTASourceEditor;
begin
  Result := nil;

  SourceEditor := GetActiveSourceEditor;
  if SourceEditor = nil then
    Exit;

  if SourceEditor.EditViewCount > 0 then
    Result := SourceEditor.EditViews[0];
end;

function GetSelectedText: string;
var
  EditView: IOTAEditView;
  EditBlock: IOTAEditBlock;
begin
  Result := '';

  EditView := GetActiveEditView;
  if EditView = nil then
    Exit;

  EditBlock := EditView.Block;
  if (EditBlock <> nil) and EditBlock.IsValid and (EditBlock.Size > 0) then
    Result := EditBlock.Text;
end;

procedure ReplaceSelectedText(const NewText: string);
var
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  EditBlock: IOTAEditBlock;
  EditWriter: IOTAEditWriter;
  StartEditPos, EndEditPos: TOTAEditPos;
  StartCharPos, EndCharPos: TOTACharPos;
  StartPos, EndPos: Longint;
begin
  // Observacao: a substituicao e feita direto no buffer via
  // IOTAEditWriter (CreateUndoableWriter + CopyTo/DeleteTo/Insert), em
  // vez de IOTAEditPosition.InsertText. InsertText simula digitacao
  // tecla-a-tecla, entao cada quebra de linha inserida disparava o
  // auto-indent do editor, somando a indentacao da linha anterior a
  // indentacao ja presente no texto gerado (efeito "escada"). Escrever
  // direto no buffer evita isso, pois nao passa pelo auto-indent.
  SourceEditor := GetActiveSourceEditor;
  if SourceEditor = nil then
    Exit;

  EditView := GetActiveEditView;
  if EditView = nil then
    Exit;

  EditBlock := EditView.Block;
  if (EditBlock = nil) or not EditBlock.IsValid or (EditBlock.Size = 0) then
    Exit;

  // Converte inicio e fim do bloco selecionado (linha/coluna) para
  // offsets absolutos ("Pos"), usados pelo IOTAEditWriter. Calculamos os
  // dois pelo mesmo caminho (linha/coluna -> CharPos -> Pos) em vez de
  // "StartPos + EditBlock.Size", para não depender de Size estar na
  // mesma unidade de medida do offset usado pelo writer.
  StartEditPos.Line := EditBlock.StartingRow;
  StartEditPos.Col := EditBlock.StartingColumn;
  EditView.ConvertPos(True, StartEditPos, StartCharPos);
  StartPos := EditView.CharPosToPos(StartCharPos);

  EndEditPos.Line := EditBlock.EndingRow;
  EndEditPos.Col := EditBlock.EndingColumn;
  EditView.ConvertPos(True, EndEditPos, EndCharPos);
  EndPos := EditView.CharPosToPos(EndCharPos);

  EditWriter := SourceEditor.CreateUndoableWriter;
  try
    EditWriter.CopyTo(StartPos);
    EditWriter.DeleteTo(EndPos);
    EditWriter.Insert(PAnsiChar(UTF8Encode(NewText)));
  finally
    EditWriter := nil;
  end;

  EditView.Paint;
end;

end.
