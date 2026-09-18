unit Jota.IDEWizards.KeyBindings;

{
  Atalhos de teclado do editor de codigo registrados pelo "Jota IDE Wizards".

  Ctrl+Alt+J converte o texto selecionado, verificado nesta ordem:
    1) Contem "sLineBreak"     -> e uma constante string Delphi
                                  ('...' + sLineBreak + ...) -> SQL puro,
                                  copiado para a area de transferencia
                                  (clipboard) + toast de confirmacao.
    2) Contem ".Sql.Add("      -> e um ObjectSqlScript
                                  (Objeto.Sql.Add('...'); um por linha)
                                  -> SQL puro, copiado para a area de
                                  transferencia + toast de confirmacao.
    3) Nenhum dos dois         -> e SQL puro -> pergunta ao usuario para
                                  qual formato converter (Constant String
                                  ou Query Object Script) e substitui a
                                  propria selecao no editor com o
                                  resultado escolhido.

  Novos atalhos podem ser adicionados dentro de BindKeyboard,
  cada um com seu proprio handler.
}

interface

uses
  ToolsAPI,
  System.Classes,
  Vcl.Menus;

type
  TJotaKeyBindings = class(TNotifierObject, IOTAKeyboardBinding)
  private
    procedure ShowSelectedTextHandler(const Context: IOTAKeyContext;
      KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
  public
    { IOTAKeyboardBinding }
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  end;

implementation

uses
  Vcl.Dialogs,
  Vcl.Clipbrd,
  Jota.IDEWizards.OTAUtils,
  Jota.IDEWizards.SqlDelphiConverter,
  Jota.IDEWizards.Toast,
  Jota.IDEWizards.SqlConvertChoiceDialog;

{ TJotaKeyBindings }

function TJotaKeyBindings.GetBindingType: TBindingType;
begin
  // btPartial: este binding apenas ADICIONA atalhos aos existentes na IDE
  // (nao substitui um esquema de teclado inteiro, que seria btComplete).
  Result := btPartial;
end;

function TJotaKeyBindings.GetDisplayName: string;
begin
  Result := 'Jota IDE Wizards - Atalhos de teclado';
end;

function TJotaKeyBindings.GetName: string;
begin
  Result := 'Jota.IDEWizards.KeyBindings';
end;

procedure TJotaKeyBindings.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
begin
  BindingServices.AddKeyBinding([TextToShortCut('Ctrl+Alt+J')],
    ShowSelectedTextHandler, nil);
end;

procedure TJotaKeyBindings.ShowSelectedTextHandler(const Context: IOTAKeyContext;
  KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
var
  SelectedText: string;
  ConvertedText: string;
  SqlConvertTarget: TSqlConvertTarget;
begin
  // Marca o atalho como tratado, para a IDE nao repassa-lo adiante.
  BindingResult := krHandled;

  SelectedText := GetSelectedText;

  if SelectedText = '' then
  begin
    ShowMessage('(nenhum texto selecionado)');
    Exit;
  end;

  if Pos('sLineBreak', SelectedText) > 0 then
  begin
    // Constante string Delphi -> script SQL puro: vai para a area de
    // transferencia, pronta para colar em uma ferramenta como o DBeaver.
    ConvertedText := DelphiConstantToSql(SelectedText);
    Clipboard.AsText := ConvertedText;
    ShowToast('Script convertido e copiado para a área de transferência');
  end
  else if Pos('.Sql.Add(', SelectedText) > 0 then
  begin
    // ObjectSqlScript (Objeto.Sql.Add('...'); um por linha) -> script SQL
    // puro: tambem vai para a area de transferencia.
    ConvertedText := ObjectSqlScriptToSql(SelectedText);
    Clipboard.AsText := ConvertedText;
    ShowToast('Script convertido e copiado para a área de transferência');
  end
  else
  begin
    // Script SQL puro -> pergunta para qual formato Delphi converter.
    if AskSqlConvertTarget(SqlConvertTarget) then
    begin
      case SqlConvertTarget of
        sctConstantString:
          // 1 - Constant String: mesma conversao de sempre (uma linha
          // por '...' + sLineBreak +).
          ConvertedText := SqlToDelphiConstant(SelectedText);
        sctObjectSqlScript:
          // 2 - Query Object Script: MyQuery.Sql.Add('...'); uma
          // chamada por linha do SQL.
          ConvertedText := SqlToObjectSqlScript(SelectedText, 'MyQuery');
      end;

      // Nos dois casos, substitui o texto selecionado no proprio editor.
      ReplaceSelectedText(ConvertedText);
    end;
    // Se o usuario cancelar o dialogo, nao faz nada.
  end;
end;

end.
