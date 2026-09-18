unit Jota.IDEWizards.SqlConvertChoiceDialog;

{
  Dialogo simples: quando o texto selecionado for um script SQL puro,
  pergunta para qual formato Delphi ele deve ser convertido.

  Atalhos: teclas 1 e 2 escolhem a opcao correspondente diretamente,
  sem precisar clicar no botao (alem do clique normal e do Alt+1/Alt+2
  via mnemonico do "&" na legenda).
}

interface

type
  TSqlConvertTarget = (sctConstantString, sctObjectSqlScript);

/// <summary>
///   Pergunta ao usuario para qual formato converter o script SQL
///   selecionado. Retorna True e preenche Target se o usuario escolheu
///   uma opcao; retorna False se o usuario cancelou/fechou o dialogo.
/// </summary>
function AskSqlConvertTarget(out Target: TSqlConvertTarget): Boolean;

implementation

uses
  System.Classes,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Controls,
  Jota.IDEWizards.Theming;

type
  TJotaSqlConvertChoiceForm = class(TForm)
  private
    procedure FormKeyPressHandler(Sender: TObject; var Key: Char);
  public
    constructor CreateChoiceForm;
  end;

const
  FormWidth = 340;
  Margin = 16;
  ButtonHeight = 32;
  ButtonSpacing = 10;

{ TJotaSqlConvertChoiceForm }

constructor TJotaSqlConvertChoiceForm.CreateChoiceForm;
var
  CaptionLabel: TLabel;
  BtnConstantString: TButton;
  BtnObjectSqlScript: TButton;
begin
  inherited CreateNew(nil);

  ApplyIdeMatchingStyle(Self);

  Caption := 'Jota IDE Wizards';
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  ClientWidth := FormWidth;

  // KeyPreview garante que a tecla passe primeiro pelo form (OnKeyPress)
  // antes de ir para o controle com foco, para o atalho 1/2 funcionar
  // independente de qual botao estiver focado.
  KeyPreview := True;
  OnKeyPress := FormKeyPressHandler;

  CaptionLabel := TLabel.Create(Self);
  CaptionLabel.Parent := Self;
  CaptionLabel.Caption := 'Converter o SQL Script para:';
  CaptionLabel.Left := Margin;
  CaptionLabel.Top := Margin;
  CaptionLabel.AutoSize := True;

  BtnConstantString := TButton.Create(Self);
  BtnConstantString.Parent := Self;
  BtnConstantString.Caption := '&1 - Constant String';
  BtnConstantString.Left := Margin;
  BtnConstantString.Top := CaptionLabel.Top + CaptionLabel.Height + Margin;
  BtnConstantString.Width := FormWidth - (Margin * 2);
  BtnConstantString.Height := ButtonHeight;
  BtnConstantString.ModalResult := mrYes;
  BtnConstantString.Default := True;

  BtnObjectSqlScript := TButton.Create(Self);
  BtnObjectSqlScript.Parent := Self;
  BtnObjectSqlScript.Caption := '&2 - Query Object Script';
  BtnObjectSqlScript.Left := Margin;
  BtnObjectSqlScript.Top := BtnConstantString.Top + BtnConstantString.Height + ButtonSpacing;
  BtnObjectSqlScript.Width := FormWidth - (Margin * 2);
  BtnObjectSqlScript.Height := ButtonHeight;
  BtnObjectSqlScript.ModalResult := mrNo;

  ClientHeight := BtnObjectSqlScript.Top + BtnObjectSqlScript.Height + Margin;
end;

procedure TJotaSqlConvertChoiceForm.FormKeyPressHandler(Sender: TObject; var Key: Char);
begin
  case Key of
    '1':
      begin
        ModalResult := mrYes;
        Key := #0;
      end;
    '2':
      begin
        ModalResult := mrNo;
        Key := #0;
      end;
  end;
end;

function AskSqlConvertTarget(out Target: TSqlConvertTarget): Boolean;
var
  DlgForm: TJotaSqlConvertChoiceForm;
begin
  Result := False;

  DlgForm := TJotaSqlConvertChoiceForm.CreateChoiceForm;
  try
    case DlgForm.ShowModal of
      mrYes:
        begin
          Target := sctConstantString;
          Result := True;
        end;
      mrNo:
        begin
          Target := sctObjectSqlScript;
          Result := True;
        end;
    else
      // Fechado pelo X / Alt+F4 / Esc -> ShowModal retorna mrCancel:
      // nao converte nada.
      Result := False;
    end;
  finally
    DlgForm.Free;
  end;
end;

end.
