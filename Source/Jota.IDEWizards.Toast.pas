unit Jota.IDEWizards.Toast;

{
  "Toast" simples: mensagem temporaria, sem interacao, que aparece no
  canto da tela e desaparece sozinha (fade in/out), sem roubar o foco
  do editor de codigo e sem interromper o fluxo como um ShowMessage faria.

  Uso:
    ShowToast('Script convertido e copiado para a area de transferencia');
}

interface

procedure ShowToast(const AMessage: string; ADurationMs: Integer = 2000);

implementation

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.SysUtils,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Controls,
  Jota.IDEWizards.Theming;

type
  TJotaToastForm = class(TForm)
  private
    FCaptionLabel: TLabel;
    FFadeTimer: TTimer;
    FCloseTimer: TTimer;
    FFadingIn: Boolean;
    procedure FadeTimerTimer(Sender: TObject);
    procedure CloseTimerTimer(Sender: TObject);
    procedure FormCloseHandler(Sender: TObject; var Action: TCloseAction);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor CreateToast(const AMessage: string; ADurationMs: Integer);
  end;

const
  PaddingH = 18;
  PaddingV = 12;
  MarginFromEdge = 28;
  MaxAlpha = 235;
  FadeStep = 25;
  FadeIntervalMs = 15;

{ TJotaToastForm }

constructor TJotaToastForm.CreateToast(const AMessage: string; ADurationMs: Integer);
begin
  inherited CreateNew(nil);

  ApplyIdeMatchingStyle(Self);

  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  Position := poDesigned;
  // Nao usamos a propriedade ShowInTaskBar: o WS_EX_TOOLWINDOW definido em
  // CreateParams ja tira o toast da barra de tarefas e do Alt+Tab.
  Color := RGB(39, 122, 60); // verde escuro (sucesso)
  AlphaBlend := True;
  AlphaBlendValue := 0;

  FCaptionLabel := TLabel.Create(Self);
  FCaptionLabel.Parent := Self;
  FCaptionLabel.Caption := AMessage;
  FCaptionLabel.Font.Name := 'Segoe UI';
  FCaptionLabel.Font.Size := 10;
  FCaptionLabel.Font.Style := [fsBold];
  FCaptionLabel.Font.Color := clWhite;
  FCaptionLabel.AutoSize := True;

  ClientWidth := FCaptionLabel.Width + (PaddingH * 2);
  ClientHeight := FCaptionLabel.Height + (PaddingV * 2);
  FCaptionLabel.Left := PaddingH;
  FCaptionLabel.Top := PaddingV;

  Left := Screen.WorkAreaRect.Right - Width - MarginFromEdge;
  Top := Screen.WorkAreaRect.Bottom - Height - MarginFromEdge;

  OnClose := FormCloseHandler;

  FFadeTimer := TTimer.Create(Self);
  FFadeTimer.Interval := FadeIntervalMs;
  FFadeTimer.OnTimer := FadeTimerTimer;
  FFadeTimer.Enabled := False;

  FCloseTimer := TTimer.Create(Self);
  FCloseTimer.Interval := ADurationMs;
  FCloseTimer.OnTimer := CloseTimerTimer;
  FCloseTimer.Enabled := False;

  FFadingIn := True;

  Show;

  FFadeTimer.Enabled := True;
end;

procedure TJotaToastForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // Evita que o toast roube o foco do editor de codigo e apareca na
  // barra de tarefas / Alt+Tab.
  Params.ExStyle := Params.ExStyle or WS_EX_NOACTIVATE or WS_EX_TOOLWINDOW;
end;

procedure TJotaToastForm.FadeTimerTimer(Sender: TObject);
begin
  if FFadingIn then
  begin
    if AlphaBlendValue + FadeStep >= MaxAlpha then
    begin
      AlphaBlendValue := MaxAlpha;
      FFadeTimer.Enabled := False;
      FCloseTimer.Enabled := True;
    end
    else
      AlphaBlendValue := AlphaBlendValue + FadeStep;
  end
  else
  begin
    if AlphaBlendValue - FadeStep <= 0 then
    begin
      AlphaBlendValue := 0;
      FFadeTimer.Enabled := False;
      Close;
    end
    else
      AlphaBlendValue := AlphaBlendValue - FadeStep;
  end;
end;

procedure TJotaToastForm.CloseTimerTimer(Sender: TObject);
begin
  FCloseTimer.Enabled := False;
  FFadingIn := False;
  FFadeTimer.Enabled := True;
end;

procedure TJotaToastForm.FormCloseHandler(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure ShowToast(const AMessage: string; ADurationMs: Integer);
begin
  // O form se auto-destroi (caFree) quando termina o fade-out, entao nao
  // precisa (nem deve) ser liberado aqui.
  TJotaToastForm.CreateToast(AMessage, ADurationMs);
end;

end.
