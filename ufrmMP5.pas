unit ufrmMP5;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Ani,
  FMX.Objects,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Layouts,
  FMX.Edit,
  clisitef,
  wbt.CliSiTefI,
  FMX.Platform.Android,
  constants;

type
  TfromTransacao = class(TForm)
    StyleBook1: TStyleBook;
    layout_campos: TLayout;
    Layout1: TLayout;
    rrtCredito: TRoundRect;
    lblCredito: TLabel;
    ArcCredito: TArc;
    fanCreditoLarg: TFloatAnimation;
    fanCredito: TFloatAnimation;
    Layout2: TLayout;
    rctDebito: TRoundRect;
    lblDebito: TLabel;
    arcDebito: TArc;
    fanDebito: TFloatAnimation;
    fanDebitoLarg: TFloatAnimation;
    lblMensagem: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure TransacacaodebitoTAP(Sender: TObject; const Point: TPointF);
    procedure TransacaoCreditoTAP(Sender: TObject; const Point: TPointF);
    procedure fanCreditoFinish(Sender: TObject);
    procedure fanDebitoFinish(Sender: TObject);
  private
    FEspera: boolean;
    FRodando: boolean;
    FProximoComando: integer;
    procedure addStrRes(texto: string);
    procedure handleMessage(value: integer);
    procedure RotinaColeta(comando: integer);
    procedure RotinaResultado(campo: integer);
    procedure ExecutaTransacao(AFuncao: integer; AValor, ARestricoes, ATerminal, ANumeroDocumento: string);
    procedure StatusSitef(AStatus: string);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fromTransacao: TfromTransacao;

implementation

{$R *.fmx}

procedure TfromTransacao.ExecutaTransacao(AFuncao: integer; AValor, ARestricoes, ATerminal, ANumeroDocumento: string);
var
  lHora: string;
  lData: string;
  lsts: integer;
begin
  lHora := FormatDateTime('HHNNSS', now);
  lData := FormatDateTime('YYYYMMDD', now);
  lsts := iniciaFuncaoSiTefInterativo(AFuncao, AValor, ANumeroDocumento, lData, lHora, ATerminal, ARestricoes);

  if lsts = 10000 then
  begin
    tthread.CreateAnonymousThread(
      procedure
      begin
        tthread.Current.FreeOnTerminate := true;

        FRodando := true;
        repeat
          lsts := continuaFuncaoSiTefInterativo;
          if (lsts = 10000) then
          begin
            FProximoComando := getProximoComando;
            FEspera := true;
            handleMessage(FProximoComando);
          end;
        until not(FRodando or (lsts = 10000));

        if lsts = 0 then
        begin
          lsts := finalizaTransacaoSiTefInterativoEx(1, lHora, lData, '120000', '');
          if lsts = 10000 then
            repeat
              lsts := continuaFuncaoSiTefInterativo;
              if lsts = 10000 then
              begin
                FProximoComando := getProximoComando;
                FEspera := true;
                handleMessage(FProximoComando);
              end;
            until not(FRodando or (lsts = 10000));
        end;
      end).Start;
  end;
end;

procedure TfromTransacao.fanCreditoFinish(Sender: TObject);
begin
  if NOT fanCreditoLarg.Inverse then
  begin
    ArcCredito.Visible := true;
    fanCredito.Start;
  end;
end;

procedure TfromTransacao.fanDebitoFinish(Sender: TObject);
begin
  if NOT fanDebitoLarg.Inverse then
  begin
    arcDebito.Visible := true;
    fanDebito.Start;
  end;
end;

procedure TfromTransacao.FormCreate(Sender: TObject);
var
  lsts: integer;
begin
  setDebug(true);
  setActivity(MainActivity);
  tthread.CreateAnonymousThread(
    procedure
    begin
      // Inicializa o SITEF
      lsts := configuraIntSiTefInterativoEx('45.237.81.1', '00000000', '00000000', '');
    end).Start;
end;

procedure TfromTransacao.handleMessage(value: integer);
begin
  if (value = CMD_RETORNO_VALOR) then
    RotinaResultado(getTipoCampo)
  else
    RotinaColeta(value);
end;

procedure TfromTransacao.TransacaoCreditoTAP(Sender: TObject; const Point: TPointF);
begin
  fanCreditoLarg.Inverse := false;
  fanCreditoLarg.Start;
  lblCredito.AnimateFloat('Opacity', 0, 0.4);

  tthread.CreateAnonymousThread(
    procedure
    begin
      ExecutaTransacao(3, '10000', '', 'EC0000001', '0000000001');

      tthread.Synchronize(nil,
        procedure
        begin
          fanCredito.Stop;
          ArcCredito.Visible := false;

          fanCreditoLarg.Inverse := true;
          fanCreditoLarg.Stop;
          lblCredito.Text := 'Crédito';
          lblCredito.AnimateFloat('Opacity', 1, 0.4);
        end);

    end).Start;
end;

procedure TfromTransacao.TransacacaodebitoTAP(Sender: TObject; const Point: TPointF);
begin
  fanDebitoLarg.Inverse := false;
  fanDebitoLarg.Start;
  lblDebito.AnimateFloat('Opacity', 0, 0.4);

  tthread.CreateAnonymousThread(
    procedure
    begin

      ExecutaTransacao(2, '10000', '', 'EC0000001', '0000000001');

      tthread.Synchronize(nil,
        procedure
        begin
          fanDebito.Stop;
          arcDebito.Visible := false;

          fanDebitoLarg.Inverse := true;
          fanDebitoLarg.Stop;
          lblDebito.Text := 'Débito';
          lblDebito.AnimateFloat('Opacity', 1, 0.4);
        end);

    end).Start;
end;

procedure TfromTransacao.RotinaColeta(comando: integer);
begin
  case comando of
    CMD_MENSAGEM_OPERADOR, CMD_MENSAGEM_CLIENTE, CMD_MENSAGEM:
      begin
        StatusSitef(getBuffer);
      end;

    CMD_TITULO_MENU, CMD_EXIBE_CABECALHO:
      begin
      end;

    CMD_REMOVE_MENSAGEM_OPERADOR, CMD_REMOVE_MENSAGEM_CLIENTE, CMD_REMOVE_MENSAGEM, CMD_REMOVE_TITULO_MENU, CMD_REMOVE_CABECALHO:
      begin
        StatusSitef(getBuffer);
      end;

    19, CMD_CONFIRMA_CANCELA:
      begin
      end;

    CMD_OBTEM_CAMPO, CMD_OBTEM_VALOR:
      begin
      end;
    CMD_SELECIONA_MENU:
      begin
      end;
    CMD_OBTEM_QUALQUER_TECLA, CMD_PERGUNTA_SE_INTERROMPE:
      begin
      end
  end;
  FEspera := false;
end;

procedure TfromTransacao.RotinaResultado(campo: integer);
begin
  case campo of
    CAMPO_COMPROVANTE_CLIENTE, CAMPO_COMPROVANTE_ESTAB:
      begin
        addStrRes(getBuffer);
      end
  end;
  FEspera := false;
end;

procedure TfromTransacao.StatusSitef(AStatus: string);
begin
  if AStatus <> lblMensagem.Text then
  begin
    lblMensagem.Text := AStatus;
    lblMensagem.Repaint();
  end;
end;

procedure TfromTransacao.addStrRes(texto: string);
begin

end;

end.
