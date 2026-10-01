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

## Menu Jota IDE Wizards (Ctrl+Shift+J)

**Ctrl+Shift+J** abre um menu popup (teclas 1, 2... escolhem direto o item). Os itens também ficam em **Tools → Jota IDE Wizards**.

**No editor de código** (menu abre logo abaixo do cursor de texto):

1. **Configurar** — abre o diálogo de configurações (ver abaixo). Ao confirmar com OK, recarrega os metadados.
2. **Recarregar metadados** — ver "Metadados da base de trabalho".
3. **SQL Query para Entidade** — ver abaixo.
4. **SyncEdit** — repassa o Ctrl+Shift+J para o SyncEdit nativo do Delphi (o handler do Jota devolve `krUnhandled` e a IDE segue para o próximo binding). Fechar o menu com Esc não ativa o SyncEdit.

**No Form Designer** (menu na posição do mouse):

1. **Configurar**
2. **Recarregar metadados**
3. **Novo campo FMTBCD**: cria um `TFMTBCDField` persistente em qualquer `TDataSet` do form/data module ativo (`TFDQuery`, `TFDMemTable`, `TClientDataSet`...). O dataset selecionado (ou o dataset do campo selecionado) já vem escolhido. Padrões: `Precision = 21`, `Scale (Size) = 2` (compatível com `numeric(21,2)`), `DisplayFormat = '#,##0.00;(#,##0.00)'`, `EditFormat = '0.00'`. O `EditFormat` não usa separador de milhar porque a conversão string→BCD na edição não o aceita. `Name`, `DisplayFormat` e `EditFormat` são recalculados ao mudar dataset/FieldName/Scale, enquanto não forem editados à mão. Se o dataset estiver aberto, ele é fechado antes de criar o campo. Depois de criar, `Data.FmtBcd` é adicionada ao `uses` da interface se ainda não estiver declarada (se já estiver no `uses` da implementation, fica como está).

Se houver um dataset selecionado no designer, o menu é pulado e o diálogo **Novo campo FMTBCD** abre direto, já com esse dataset.

### SQL Query para Entidade

Abre um formulário só com o memo da consulta SQL. **Ctrl+Enter** ou **Confirmar** executa; Enter quebra linha. O SQL é lembrado enquanto a IDE estiver aberta.

A consulta roda na base de trabalho **sem trazer dados**: vira `select * from (<sql>) jota_query limit 0`, com `;` final removido e parâmetros `:nome` trocados por `null` (strings, comentários e casts `::tipo` são preservados). UPDATE/DELETE não passam por esse formato. Se der erro, a mensagem aparece e o formulário reabre com o SQL.

Em seguida abre um menu na posição do cursor:

1. **Converter em TObject Com Property** — pede o **Nome da classe** (sugestão `TDados` + primeira tabela do FROM, sem os prefixos `spk`/`tb`/`_` e com cada parte separada por `_` iniciando em maiúscula: `tb_cliente_endereco` → `TDadosClienteEndereco`) e insere na posição do cursor uma classe `class(TObject)` com um field `F<coluna>` e uma `property <coluna>` por coluna retornada, com o nome exato da coluna. Tipos: string/memo → `string`; int2/int4/int8 → `SmallInt`/`Integer`/`Int64`; numeric/decimal/float8 → `Double`; float4 → `Single`; money → `Currency`; boolean → `Boolean`; date → `TDate`; time → `TTime`; timestamp → `TDateTime`; uuid → `TGUID`; bytea → `TBytes`; demais → `Variant`. Nomes inválidos como identificador têm os caracteres inválidos trocados por `_`; palavras reservadas recebem `&` na property; nomes repetidos (sem diferenciar maiúsculas) recebem sufixo `_2`, `_3`...
2. **Converter em Record** — pede o **Nome do record** (mesma sugestão `TDados...`) e insere na posição do cursor um `record` com um campo por coluna retornada, com o nome exato da coluna e os mesmos tipos e regras de nome do item 1 (palavra reservada recebe `&`).
3. **Converter em Interfaced Object** — pede **Nome da classe** e **Nome da interface** (a interface acompanha a classe trocando o `T` inicial por `I`, até ser editada à mão). Gera no cursor a interface (com GUID novo) e a classe `class(TInterfacedObject, IDados...)` com `class function New`, fields `F<coluna>` e, por coluna, um getter e um setter fluente sobrecarregados: `function id: Integer; overload;` e `function id(const Value: Integer): IDadosCliente; overload;` (o setter grava o field e retorna `Self`). Os corpos dos métodos são inseridos no final da seção implementation (antes de `initialization`/`finalization` ou do `end.` final). Uma coluna chamada `new` vira `new_2`, para não conflitar com `New`.

### Metadados da base de trabalho

`LoadJotaMetadata` (`Jota.IDEWizards.Metadata.pas`) conecta na base de trabalho via FireDAC (driver virtual `JotaPG`, baseado no PG, com a `VendorLib` da arquitetura da IDE; `LoginTimeout` de 5 s), lê o catálogo do PostgreSQL e desconecta. O resultado fica em memória em `JotaMetadata` (`TJotaMetadata`):

- tabelas, views, views materializadas e foreign tables (todos os schemas, exceto `pg_catalog`, `information_schema`, `pg_toast*`, `pg_temp*`; partições filhas são ignoradas);
- colunas: nome, posição, tipo (`format_type`), tamanho de varchar/char, precisão e escala de numeric, NOT NULL, default, se é PK;
- chave primária e chaves estrangeiras (colunas de origem, tabela e colunas referenciadas).

Busca: `JotaMetadata.FindTable('schema.tabela')` ou `FindTable('tabela')` (prefere `public`); `Table.FindColumn('coluna')`.

É chamado de forma **síncrona na carga do pacote** (status na splash screen; toast com o resumo ou o erro quando a IDE termina de abrir) e pelo item **Recarregar metadados**. Se a base não estiver configurada, nada é feito na carga. Se falhar, os metadados anteriores são mantidos e o erro fica em `JotaMetadataLastError`.

Requer os pacotes `FireDAC`, `FireDACCommon`, `FireDACCommonDriver`, `FireDACPgDriver` e `vclFireDAC`, e um `libpq.dll` da mesma arquitetura da IDE (32 bits na IDE padrão) acessível ao processo da IDE.

### Configurar

Group box **Base de dados de trabalho** (PostgreSQL): Host, Porta, NomeBD, Usuário, Senha (com "Mostrar senha") e **libpq 32 bits** / **libpq 64 bits** (caminho completo da `libpq.dll`, com botão "..." para selecionar; vazio = FireDAC procura no PATH). A IDE de 32 bits usa a de 32 bits e a IDE de 64 bits usa a de 64 bits (o campo em uso aparece em negrito); ao confirmar, cada DLL informada é validada pelo cabeçalho PE para garantir que é da arquitetura certa; as DLLs de que ela depende (libssl, libcrypto, libintl, libiconv...) devem estar na mesma pasta, porque o FireDAC procura as dependências primeiro na pasta da libpq informada. Host, Porta (1–65535), NomeBD e Usuário são obrigatórios; senha vazia é aceita.

Salvo em `%APPDATA%\JotaDelphiIDEWizards\JotaDelphiIdeWizards.Cfg.Json`:

```json
{
  "BaseDadosTrabalho": {
    "Host": "localhost",
    "Porta": 5432,
    "NomeBD": "minha_base",
    "Usuario": "postgres",
    "Senha": "cG9zdGdyZXM=",
    "VendorLib32": "C:\\PostgreSQL32\\bin\\libpq.dll",
    "VendorLib64": "C:\\Program Files\\PostgreSQL\\bin\\libpq.dll"
  }
}
```

- A senha é gravada em **Base64** (UTF-8). Base64 não é criptografia: só evita a senha legível de relance; qualquer um com acesso ao arquivo decodifica. Aceito porque as bases de trabalho não têm dados sensíveis.
- Outras chaves do JSON são preservadas ao salvar. Se o arquivo estiver corrompido, ele é copiado para `.bak` antes de ser recriado.

## Arquivos

- `JotaIDEWizards.dpk` — projeto do pacote (design-only, requer `designide`).
- `Jota.IDEWizards.OTAUtils.pas` — funções utilitárias de OTA (pegar o editor/seleção ativos). Reaproveitável pelos próximos wizards.
- `Jota.IDEWizards.KeyBindings.pas` — classe `TJotaKeyBindings`, que implementa `IOTAKeyboardBinding` e registra o Ctrl+Alt+J e o Ctrl+Shift+J do editor.
- `Jota.IDEWizards.SqlDelphiConverter.pas` — conversão nos dois sentidos entre script SQL, constante string Delphi (`SqlToDelphiConstant` / `DelphiConstantToSql`) e ObjectSqlScript (`ObjectSqlScriptToSql`).
- `Jota.IDEWizards.Toast.pas` — toast simples (`ShowToast`), form sem borda com fade in/out, usado para feedback rápido sem interromper o fluxo.
- `Jota.IDEWizards.SqlConvertChoiceDialog.pas` — diálogo modal simples (`AskSqlConvertTarget`) perguntando para qual formato Delphi converter um SQL puro.
- `Jota.IDEWizards.Theming.pas` — aplica aos formulários do projeto (`ApplyIdeMatchingStyle`) o VCL Style "Windows11 Modern Light" ou "Windows11 Modern Dark", conforme o tema atual da IDE (via `IOTAIDEThemingServices`), sem alterar o estilo global da IDE.
- `Jota.IDEWizards.SplashScreen.pas` — registra o ícone (24x24) e a legenda "Jota Delphi IDE Wizards <versão>" na splash screen da IDE, via `SplashScreenServices.AddPluginBitmap` (carrega o PNG de `icons\icon24.png`).
- `Jota.IDEWizards.JotaMenu.pas` — menu popup do Ctrl+Shift+J: no Form Designer via ação no ActionList da IDE (desabilitada com o editor de código em foco); no editor via `ShowJotaEditorMenu` (síncrono, `TrackPopupMenuEx` + `TPM_RETURNCMD`), chamado pelo keybinding. Também o submenu em Tools.
- `Jota.IDEWizards.Config.pas` — leitura/gravação do `JotaDelphiIdeWizards.Cfg.Json` (`LoadBaseDadosTrabalho` / `SaveBaseDadosTrabalho`) (senha em Base64).
- `Jota.IDEWizards.ConfigDialog.pas` — diálogo "Configurar" (`ExecuteConfigDialog`).
- `Jota.IDEWizards.Metadata.pas` — conexão com a base de trabalho (`CreateBaseDadosTrabalhoConnection`), modelo e carga dos metadados (`LoadJotaMetadata`, `JotaMetadata`).
- `Jota.IDEWizards.SqlEntity.pas` — prepara a consulta (`limit 0`, parâmetros → `null`), lê as colunas e gera a classe.
- `Jota.IDEWizards.SqlEntityDialog.pas` — formulário "SQL Query para Entidade".
- `Jota.IDEWizards.SqlEntityWizard.pas` — fluxo completo: formulário, execução, menu de conversão e inserção no cursor.
- `Jota.IDEWizards.MetadataActions.pas` — carga na splash screen (`LoadJotaMetadataAtStartup`) e recarga pelo menu (`ReloadJotaMetadataInteractive`).
- `Jota.IDEWizards.FieldWizards.pas` — wizards de campos; `RunNewFMTBCDFieldWizard` cria o campo pelo `IDesigner` do form ativo.
- `Jota.IDEWizards.UsesClause.pas` — `EnsureUnitInInterfaceUses`: adiciona uma unit ao `uses` da interface direto no buffer do editor (com undo), ignorando comentários e strings.
- `Jota.IDEWizards.NewFMTBCDFieldDialog.pas` — diálogo do "Novo campo FMTBCD" e `BuildBcdFormats`.
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

## Splash screen

Ao carregar, o pacote registra um ícone e a legenda "Jota Delphi IDE Wizards <versão>" na splash screen da IDE (`SplashScreenServices.AddPluginBitmap`, disponível desde o Delphi 2005). O ícone é um PNG 24x24 carregado em tempo de execução de `icons\icon24.png`, dentro da pasta do projeto — esse arquivo precisa continuar existindo nesse caminho para o ícone aparecer (se não existir, a entrada da splash screen simplesmente não é adicionada, sem erro). A versão exibida é controlada pela constante `JotaIDEWizardsVersion` em `Jota.IDEWizards.SplashScreen.pas`.

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
