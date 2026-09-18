# Jota IDE Wizards

Pacote de design-time (expert de IDE) para o Delphi. Primeiro atalho, só de teste:

**Ctrl+Alt+J** no editor de código → converte o texto selecionado, checado nesta ordem:

1. Contém `"sLineBreak"` → é uma constante string Delphi (`'...' + sLineBreak + ...`) → convertida de volta para script SQL puro, copiada para a **área de transferência (clipboard)** e mostra um toast de confirmação.
2. Contém `".Sql.Add("` → é um **ObjectSqlScript** (um `TQuery`/`TFDQuery`/etc. montado como `Objeto.Sql.Add('...');`, uma chamada por linha) → convertido para script SQL puro, também copiado para a **área de transferência** e com toast de confirmação.
3. Nenhum dos dois → é tratado como script SQL puro → aparece um diálogo perguntando **"Converter o SQL Script para:"**, com duas opções:
   - **1 - Constant String**: mesma conversão de sempre, uma constante string Delphi multilinha (uma linha por `'...' + sLineBreak +`, aspas simples do SQL escapadas dobrando, todas as linhas alinhadas pela mais longa **daquela query**).
   - **2 - Query Object Script**: `MyQuery.Sql.Add('...');`, uma chamada por linha do SQL (aspas simples escapadas, sem alinhamento/padding), no formato de `ExemploObjectQueryToSqlScript.txt`.

   Em ambos os casos o resultado **substitui o próprio texto selecionado no editor**. Se o diálogo for fechado/cancelado, nada é alterado.

O toast ("Script convertido e copiado para a área de transferência") aparece no canto da tela e some sozinho, sem roubar o foco do editor.

## Arquivos

- `JotaIDEWizards.dpk` — projeto do pacote (design-only, requer `designide`).
- `Jota.IDEWizards.OTAUtils.pas` — funções utilitárias de OTA (pegar o editor/seleção ativos). Reaproveitável pelos próximos wizards.
- `Jota.IDEWizards.KeyBindings.pas` — classe `TJotaKeyBindings`, que implementa `IOTAKeyboardBinding` e registra o Ctrl+Alt+J.
- `Jota.IDEWizards.SqlDelphiConverter.pas` — conversão nos dois sentidos entre script SQL, constante string Delphi (`SqlToDelphiConstant` / `DelphiConstantToSql`) e ObjectSqlScript (`ObjectSqlScriptToSql`).
- `Jota.IDEWizards.Toast.pas` — toast simples (`ShowToast`), form sem borda com fade in/out, usado para feedback rápido sem interromper o fluxo.
- `Jota.IDEWizards.SqlConvertChoiceDialog.pas` — diálogo modal simples (`AskSqlConvertTarget`) perguntando para qual formato Delphi converter um SQL puro.
- `Jota.IDEWizards.Theming.pas` — aplica aos formulários do projeto (`ApplyIdeMatchingStyle`) o VCL Style "Windows11 Modern Light" ou "Windows11 Modern Dark", conforme o tema atual da IDE (via `IOTAIDEThemingServices`), sem alterar o estilo global da IDE.
- `Jota.IDEWizards.Register.pas` — registra/desregistra os wizards junto à IDE (`initialization`/`finalization`).

## Como instalar

1. No Delphi: **File → Open**, selecione `JotaIDEWizards.dpk`.
   - Se a IDE pedir para criar o `.dproj`, aceite (ela gera automaticamente a partir do `.dpk`).
2. Confirme em **Project → Options** que o *Target Platform* é **Windows 32-bit**. No Delphi 13 (Florence) a IDE de 32 bits ainda é a padrão (a IDE de 64 bits é um componente opcional, instalado lado a lado); um pacote de design-time precisa ser compilado para a mesma arquitetura da IDE que vai carregá-lo — então só compile para Win64 se você estiver rodando a IDE de 64 bits.
3. Clique com o botão direito no projeto no *Project Manager* e escolha **Install**.
4. A IDE deve reportar `"JotaIDEWizards.bpl" foi instalado.` Se dependências como `designide.dcp` não forem encontradas, confira o caminho das `.dcp` no *Library Path*.

## Como testar

1. Abra qualquer arquivo `.pas` no editor de código.
2. Selecione um trecho de texto.
3. Pressione **Ctrl+Alt+J**.
4. Deve aparecer uma caixa de mensagem com o texto selecionado (ou `"(nenhum texto selecionado)"` se nada estiver selecionado).

Para desinstalar/desabilitar: **Component → Install Packages**, desmarque "Jota IDE Wizards".

## Compatibilidade

Testado/ajustado para **Delphi 13 (Florence)**. O código usa nomes de unit com namespace (`Vcl.Menus`, `Vcl.Dialogs`, `System.SysUtils`), padrão desde o Delphi XE2 — não precisa de ajuste nesse ponto.

## Notas técnicas / fontes verificadas

- `IOTAKeyboardBinding.BindKeyboard` + `IOTAKeyBindingServices.AddKeyBinding([TextToShortCut(...)], Handler, nil)` é o padrão oficial de registro de atalhos no editor — confirmado em Cary Jensen, *"Creating Editor Key Bindings in Delphi"* (caryjensen.blogspot.com) e David Hoyle, *"Key Bindings and Debugging Tools"* (davidghoyle.co.uk).
- `(BorlandIDEServices as IOTAKeyboardServices).AddKeyboardBinding(...)` retorna um índice inteiro, usado depois em `RemoveKeyboardBinding` no `finalization` — mesma fonte.
- `IOTAEditView.Block: IOTAEditBlock` e `IOTAEditBlock.Text: string` (com `.IsValid` e `.Size`) são os membros usados para ler a seleção — confirmados contra a declaração de interfaces do `ToolsAPI.pas` espelhada no projeto open-source `cnpack/cnwizards` (arquivo `Bin/PSDecl/ToolsAPI_D5.pas`).
- `GetActiveSourceEditor` (varrer `IOTAModule.GetModuleFileEditor` até achar um que suporte `IOTASourceEditor`) é o idioma padrão usado em experts de IDE (GExperts e outros) para achar o editor de código ativo.

## Próximos passos (quando quiser evoluir)

- Adicionar mais atalhos: basta outra chamada `BindingServices.AddKeyBinding(...)` dentro de `BindKeyboard`, com seu próprio handler.
- Adicionar um wizard com item de menu (`IOTAWizard` + `IOTAMenuWizard`) além do atalho de teclado.
- Trocar o `ShowMessage` de teste pela ação real desejada.
