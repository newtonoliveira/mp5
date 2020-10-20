unit Unit1;

interface

uses
  clisitef,
  wbt.CliSiTefI,
  FMX.Platform.Android,
  FMX.Memo.Types,
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
  FMX.Controls.Presentation,
  FMX.ScrollBox,
  FMX.Memo,
  FMX.StdCtrls;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    str_res: string;
    espera: boolean;
    rodando: boolean;
    proximoComando: integer;
    procedure addStrRes(texto: string);
    procedure handleMessage(value: integer);
    procedure RotinaColeta(comando: integer);
    procedure RotinaResultado(campo: integer);
    procedure ExecutaTransacao(AFuncao: integer; AValor, ARestricoes, ATerminal, ANumeroDocumento: string);
  end;

var
  Form1: TForm1;

implementation

uses
  constants;

{$R *.fmx}

procedure TForm1.FormCreate(Sender: TObject);
var
  v: boolean;
  i: integer;
  sts: integer;
  config: tstrings;
begin
  setDebug(true);
  setActivity(MainActivity);
  tthread.CreateAnonymousThread(
    procedure
    begin
      sts := configuraIntSiTefInterativoEx('sitefdemo.pinpag.com.br', '00000000', '00000000', '');
      if (sts <> 0) then
      begin
        Memo1.Lines.Add(inttostr(sts));
      end;
    end).Start;

end;

procedure TForm1.addStrRes(texto: string);
begin
  str_res := str_res + #13#10 + '[' + FormatDateTime('HH:NN:SS', now) + ']:' + texto;
  str_res := StringReplace(str_res, #13#10#13#10, #13#10, [rfReplaceAll, rfIgnoreCase]);
  Memo1.Lines.Add(str_res);
end;

procedure TForm1.handleMessage(value: integer);
begin
  // titulo := '';
  if (value = CMD_RETORNO_VALOR) then
    RotinaResultado(getTipoCampo)
  else
    RotinaColeta(value);
end;

procedure TForm1.RotinaColeta(comando: integer);
var
  i: integer;
  aitens: TArray<string>;
begin
  Memo1.Lines.Add(getBuffer);
  case comando of
    CMD_MENSAGEM_OPERADOR, CMD_MENSAGEM_CLIENTE, CMD_MENSAGEM:
      begin
      end;

    CMD_TITULO_MENU, CMD_EXIBE_CABECALHO:
      begin
      end;

    CMD_REMOVE_MENSAGEM_OPERADOR, CMD_REMOVE_MENSAGEM_CLIENTE, CMD_REMOVE_MENSAGEM, CMD_REMOVE_TITULO_MENU, CMD_REMOVE_CABECALHO:
      begin
        Memo1.Lines.Add(getBuffer);
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
        if getBuffer <> EmptyStr then
          addStrRes('alerta:' + getBuffer);
      end
  end;
  espera := false;
end;

procedure TForm1.RotinaResultado(campo: integer);
begin
  case campo of
    CAMPO_COMPROVANTE_CLIENTE, CAMPO_COMPROVANTE_ESTAB:
      begin
        addStrRes(getBuffer);
      end
  end;
  espera := false;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  ExecutaTransacao(2, '10,00', '');
end;

procedure TForm1.ExecutaTransacao(AFuncao: integer; AValor, ARestricoes, ATerminal, ANumeroDocumento: string);
var
  lhora: string;
  ldata: string;
  lsts: integer;
begin
  lhora := FormatDateTime('HHNNSS', now);
  ldata := FormatDateTime('YYYYMMDD', now);
  lsts := iniciaFuncaoSiTefInterativo(AFuncao, AValor, ANumeroDocumento, data, hora, ATerminal, ARestricoes);

  if lsts = 10000 then
  begin
    tthread.CreateAnonymousThread(
      procedure
      begin
        tthread.Current.FreeOnTerminate := true;

        rodando := true;
        repeat
          lsts := continuaFuncaoSiTefInterativo;
          if (lsts = 10000) then
          begin
            proximoComando := getProximoComando;
            espera := true;
            handleMessage(proximoComando);
          end;
        until not(rodando or (lsts = 10000));

        if lsts = 0 then
        begin
          lsts := finalizaTransacaoSiTefInterativoEx(1, lhora, ldata, '120000', '');
          if lsts = 10000 then
            repeat
              lsts := continuaFuncaoSiTefInterativo;
              if lsts = 10000 then
              begin
                proximoComando := getProximoComando;
                espera := true;
                handleMessage(proximoComando);
              end;
            until not(rodando or (lsts = 10000));
        end
        else
        begin
          Memo1.Lines.Add('Erro: ' + inttostr(lsts));
        end;
      end).Start;
  end;
end;

end.
