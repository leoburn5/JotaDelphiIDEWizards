unit Jota.IDEWizards.OTAUtils;

{
  Funcoes utilitarias de acesso ao Open Tools API (OTA) do Delphi.
  Usadas por todos os experts/atalhos do pacote "Jota IDE Wizards".
}

interface

uses
  System.Types,
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

function InsertTextAtCursor(const AText: string): Boolean;
function GetCursorColumn: Integer;
function GetEditorPopupPoint: TPoint;
function FindImplementationInsertOffset(const ASource: UTF8String): Integer;
function InsertTextAtCursorAndImplementation(const ACursorText, AImplementationText: string;
  out AImplementationFound: Boolean): Boolean;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Controls;

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

function InsertTextAtCursor(const AText: string): Boolean;
var
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  EditWriter: IOTAEditWriter;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;
  InsertPos: Longint;
begin
  Result := False;
  SourceEditor := GetActiveSourceEditor;
  EditView := GetActiveEditView;
  if (SourceEditor <> nil) and (EditView <> nil) then
  begin
    EditPos := EditView.CursorPos;
    EditView.ConvertPos(True, EditPos, CharPos);
    InsertPos := EditView.CharPosToPos(CharPos);

    EditWriter := SourceEditor.CreateUndoableWriter;
    try
      EditWriter.CopyTo(InsertPos);
      EditWriter.Insert(PAnsiChar(UTF8Encode(AText)));
    finally
      EditWriter := nil;
    end;

    EditView.Paint;
    Result := True;
  end;
end;

function GetCursorColumn: Integer;
var
  EditView: IOTAEditView;
begin
  Result := 0;
  EditView := GetActiveEditView;
  if EditView <> nil then
    Result := EditView.CursorPos.Col;
end;

function GetEditorPopupPoint: TPoint;
var
  Info: TGUIThreadInfo;
begin
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  if GetGUIThreadInfo(GetCurrentThreadId, Info) and (Info.hwndCaret <> 0) then
  begin
    Result := Point(Info.rcCaret.Left, Info.rcCaret.Bottom);
    Winapi.Windows.ClientToScreen(Info.hwndCaret, Result);
  end
  else
    Result := Mouse.CursorPos;
end;

function ReadEditorText(const ASourceEditor: IOTASourceEditor): UTF8String;
const
  ChunkSize = 32768;
var
  Reader: IOTAEditReader;
  Chunk: UTF8String;
  Position, ReadCount: Integer;
begin
  Result := '';
  Reader := ASourceEditor.CreateReader;
  Position := 0;
  repeat
    SetLength(Chunk, ChunkSize);
    ReadCount := Reader.GetText(Position, PAnsiChar(Chunk), ChunkSize);
    SetLength(Chunk, ReadCount);
    Result := Result + Chunk;
    Inc(Position, ReadCount);
  until ReadCount < ChunkSize;
end;

function FindImplementationInsertOffset(const ASource: UTF8String): Integer;
var
  I, J, Len, InitPos, EndPos, Target: Integer;
  Token: string;
begin
  InitPos := 0;
  EndPos := 0;
  Len := Length(ASource);
  I := 1;
  while I <= Len do
  begin
    if ASource[I] = '{' then
    begin
      while (I <= Len) and (ASource[I] <> '}') do
        Inc(I);
      Inc(I);
    end
    else if (ASource[I] = '(') and (I < Len) and (ASource[I + 1] = '*') then
    begin
      J := Pos(UTF8String('*)'), ASource, I + 2);
      if J = 0 then
        I := Len + 1
      else
        I := J + 2;
    end
    else if (ASource[I] = '/') and (I < Len) and (ASource[I + 1] = '/') then
    begin
      while (I <= Len) and not CharInSet(ASource[I], [#10, #13]) do
        Inc(I);
    end
    else if ASource[I] = '''' then
    begin
      Inc(I);
      while (I <= Len) and (ASource[I] <> '''') do
        Inc(I);
      Inc(I);
    end
    else if CharInSet(ASource[I], ['A'..'Z', 'a'..'z', '_']) then
    begin
      J := I;
      while (J <= Len) and CharInSet(ASource[J], ['A'..'Z', 'a'..'z', '_', '0'..'9']) do
        Inc(J);
      Token := LowerCase(string(Copy(ASource, I, J - I)));
      if (InitPos = 0) and ((Token = 'initialization') or (Token = 'finalization')) then
        InitPos := I;
      if (Token = 'end') and (J <= Len) and (ASource[J] = '.') then
        EndPos := I;
      I := J;
    end
    else
      Inc(I);
  end;

  if InitPos > 0 then
    Target := InitPos
  else
    Target := EndPos;

  if Target > 0 then
  begin
    while (Target > 1) and (ASource[Target - 1] <> #10) do
      Dec(Target);
    Result := Target - 1;
  end
  else
    Result := -1;
end;

function InsertTextAtCursorAndImplementation(const ACursorText, AImplementationText: string;
  out AImplementationFound: Boolean): Boolean;
var
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  EditWriter: IOTAEditWriter;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;
  CursorPos, ImplementationPos: Longint;
begin
  Result := False;
  AImplementationFound := False;
  SourceEditor := GetActiveSourceEditor;
  EditView := GetActiveEditView;
  if (SourceEditor <> nil) and (EditView <> nil) then
  begin
    ImplementationPos := FindImplementationInsertOffset(ReadEditorText(SourceEditor));
    AImplementationFound := ImplementationPos >= 0;

    EditPos := EditView.CursorPos;
    EditView.ConvertPos(True, EditPos, CharPos);
    CursorPos := EditView.CharPosToPos(CharPos);

    EditWriter := SourceEditor.CreateUndoableWriter;
    try
      if not AImplementationFound then
      begin
        EditWriter.CopyTo(CursorPos);
        EditWriter.Insert(PAnsiChar(UTF8Encode(ACursorText + sLineBreak + sLineBreak +
          AImplementationText)));
      end
      else if CursorPos <= ImplementationPos then
      begin
        EditWriter.CopyTo(CursorPos);
        EditWriter.Insert(PAnsiChar(UTF8Encode(ACursorText)));
        EditWriter.CopyTo(ImplementationPos);
        EditWriter.Insert(PAnsiChar(UTF8Encode(AImplementationText + sLineBreak)));
      end
      else
      begin
        EditWriter.CopyTo(ImplementationPos);
        EditWriter.Insert(PAnsiChar(UTF8Encode(AImplementationText + sLineBreak)));
        EditWriter.CopyTo(CursorPos);
        EditWriter.Insert(PAnsiChar(UTF8Encode(ACursorText)));
      end;
    finally
      EditWriter := nil;
    end;

    EditView.Paint;
    Result := True;
  end;
end;

end.
