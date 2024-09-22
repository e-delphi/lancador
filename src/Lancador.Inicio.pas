// Eduardo - 01/09/2024
unit Lancador.Inicio;

interface

{$SCOPEDENUMS ON}

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  Winapi.TlHelp32,
  Winapi.Messages,
  FMX.Platform.Win,
  System.Win.Registry,
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.RegularExpressions,
  System.JSON.Serializers,
  System.IOUtils,
  System.Zip,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Objects,
  FMX.Memo.Types,
  FMX.Controls.Presentation,
  FMX.ScrollBox,
  FMX.Memo,
  FMX.Layouts,
  FMX.Ani,
  FMX.StdCtrls,
  FMX.TextLayout,
  Lancador.Markdown;

type
  TVersao = record
    name: String;
    created_at: String;
    body: String;
    download: String;
  end;

  TConfiguracao = record
    api: String;
    iniciar_windows: Boolean;
    espera_iniciar: Integer;
    tempo_verificacao: Integer;
    repositorio: String;
    instalador: String;
    executavel: String;
    versao_atual: TVersao;
    versao_nova: TVersao;
  end;

  TInicio = class(TForm)
    lytTop: TLayout;
    rtgAcao: TRectangle;
    txtAcao: TText;
    caAcao: TColorAnimation;
    HTTPClient: TNetHTTPClient;
    txtNomeData: TText;
    pbAcao: TProgressBar;
    faAcao: TFloatAnimation;
    lytScale: TLayout;
    txtInformacoes: TText;
    rtgCancelar: TRectangle;
    txtCancelar: TText;
    caCancelar: TColorAnimation;
    procedure rtgAcaoClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure rtgCancelarClick(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
  private
    FProcessando: Boolean;
    FUltimaAtualizacao: TDateTime;
    procedure ReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64; var AAbort: Boolean);
    procedure AtualizaBotao;
    class procedure IniciarAplicativo(const bAtualizou: Boolean; var bSair: Boolean; var bAberto: Boolean);
    class procedure InicializarWindows(sApp: String; bAdd: Boolean);
  public
    class function CarregarConfiguracao: Boolean;
    class procedure SalvarConfiguracao;
    class procedure Iniciar;
    class procedure Exibir;
  end;

var
  Inicio: TInicio;

implementation

uses
  System.JSON,
  System.DateUtils,
  FMX.DialogService,
  REST.API;

var
  Configuracao: TConfiguracao;

{$R *.fmx}

{ TInicio }

function ContaProcessos(exeFileName: String): Integer;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := 0;
  while Integer(ContinueLoop) <> 0 do
  begin
    if (UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) = UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) = UpperCase(ExeFileName)) then
      Inc(Result);
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

function MatarProcesso(exeFileName: String): Integer;
const
  PROCESS_TERMINATE = $0001;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result := 0;
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) = UpperCase(exeFileName)) or (UpperCase(FProcessEntry32.szExeFile) = UpperCase(exeFileName))) then
      Result := Integer(TerminateProcess(OpenProcess(PROCESS_TERMINATE, BOOL(0), FProcessEntry32.th32ProcessID), 0));
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

class procedure TInicio.IniciarAplicativo(const bAtualizou: Boolean; var bSair: Boolean; var bAberto: Boolean);
var
  mr: TModalResult;
begin
  // Se não tem nenhuma versão instalada, avisa
  if not TFile.Exists(GetCurrentDir +'\'+ Configuracao.versao_atual.name +'\'+ Configuracao.executavel) then
  begin
    ShowMessage('Aplicativo ainda não instalado, instale para poder abrir!');
    bSair := True;
    Exit;
  end;

  bAberto := True;

  // Se atualizou e a aplicação já está aberta, pergunta se deseja encerra-la e abrir a nova..
  if bAtualizou then
  begin
    if ContaProcessos(Configuracao.executavel) > 0 then
    begin
      TDialogService.PreferredMode := TDialogService.TPreferredMode.Sync;
      TDialogService.MessageDialog(
        'Deseja encerrar a aplicação atual e abrir a nova versão?',
        TMsgDlgType.mtConfirmation,
        [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
        TMsgDlgBtn.mbYes,
        0,
        procedure(const AResult: TModalResult)
        begin
          mr := AResult;
        end
      );
      if mr = mrYes then
        MatarProcesso(Configuracao.executavel)
      else
        Exit;
    end;
  end;

  ShellExecute(0, 'open', PChar(GetCurrentDir +'\'+ Configuracao.versao_atual.name +'\'+ Configuracao.executavel), '', PChar(GetCurrentDir +'\'+ Configuracao.versao_atual.name +'\'), SW_SHOWNORMAL);
end;

class procedure TInicio.Iniciar;
var
  API: TRESTAPI;
  vJSON: TJSONValue;
  vItem: TJSONValue;
  bAberto: Boolean;
  bAtualizou: Boolean;
  bSair: Boolean;
begin
  bSair      := False;
  bAberto    := False;
  bAtualizou := False;

  if ParamStr(1).Equals('-inicializar') then
    Sleep(Configuracao.espera_iniciar * MSecsPerSec);

  if ContaProcessos(ExtractFileName(ParamStr(0))) > 1 then
  begin
    TInicio.IniciarAplicativo(False, bSair, bAberto);
    Exit;
  end;

  InicializarWindows(Configuracao.executavel, Configuracao.iniciar_windows);

  while True do
  try
    try
      try
        API := TRESTAPI.Create;
        try
          API.Timeout(5);
          API.Host(Configuracao.api);
          API.Route('repos/'+ Configuracao.repositorio +'/releases/latest');
          API.GET;
          if API.Response.Status <> TResponseStatus.Sucess then
            raise Exception.Create(API.Response.ToString);

          vJSON := API.Response.ToJSON;

          // Se está desatualizado
          if Configuracao.versao_atual.name <> vJSON.GetValue<String>('name') then
          begin
            Configuracao.versao_nova.name := vJSON.GetValue<String>('name');
            Configuracao.versao_nova.created_at := vJSON.GetValue<String>('created_at');
            Configuracao.versao_nova.body := vJSON.GetValue<String>('body');

            for vItem in vJSON.GetValue<TJSONArray>('assets') do
            begin
              if vItem.GetValue<String>('name').Equals(Configuracao.instalador) then
              begin
                Configuracao.versao_nova.download := vItem.GetValue<String>('browser_download_url');
                Break;
              end;
            end;

            TInicio.SalvarConfiguracao;
            TInicio.Exibir;

            bAberto := False;
            bAtualizou := Configuracao.versao_atual.name = vJSON.GetValue<String>('name');
          end;
        finally
          FreeAndNil(API);
        end;
      except on E: Exception do
        ShowMessage('Erro ao buscar novas versões no Github!'+ sLineBreak + E.Message);
      end;

      // Se já está aberto não abre outro
      if not bAberto then
      begin
        TInicio.IniciarAplicativo(bAtualizou, bSair, bAberto);
        if bSair then
          Exit;
      end;
    finally
      if not bSair then
        Sleep(Configuracao.tempo_verificacao * MSecsPerSec);
    end;
  except
  end;
end;

class procedure TInicio.Exibir;
var
  Form: TInicio;
begin
  Form := TInicio.Create(nil);
  try
    Form.BorderStyle := TFmxFormBorderStyle.None;
    Form.FormStyle := TFormStyle.StayOnTop;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

class function TInicio.CarregarConfiguracao: Boolean;
var
  js: TJsonSerializer;
begin
  SetCurrentDir(ExtractFileDir(ParamStr(0)));

  if not TFile.Exists(GetCurrentDir +'\configuracao.json') then
  begin
    ShowMessage('Arquivo de configuração não encontrado!');
    Exit(False);
  end;

  js := TJsonSerializer.Create;
  try
    Configuracao := js.Deserialize<TConfiguracao>(TFile.ReadAllText(GetCurrentDir +'\configuracao.json'));
    if Configuracao.api.IsEmpty then
      Configuracao.api := 'https://api.github.com';
    Result := True;
  finally
    FreeAndNil(js);
  end;
end;

class procedure TInicio.SalvarConfiguracao;
var
  js: TJsonSerializer;
begin
  js := TJsonSerializer.Create;
  try
    TFile.WriteAllText(GetCurrentDir +'\configuracao.json', js.Serialize<TConfiguracao>(Configuracao));
  finally
    FreeAndNil(js);
  end;
end;

class procedure TInicio.InicializarWindows(sApp: String; bAdd: Boolean);
var
  Reg: TRegistry;
  Nome: String;
begin
  try
    Reg := TRegistry.Create;
    try
      Reg.RootKey := HKEY_CURRENT_USER;
      Reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', False);

      Nome := ChangeFileExt(ExtractFileName(sApp), EmptyStr);

      if bAdd then
        Reg.WriteString(Nome, '"'+ ParamStr(0) +'" -inicializar')
      else
      if Reg.ValueExists(Nome) then
        Reg.DeleteValue(Nome);

      Reg.CloseKey;
    finally
      FreeAndNil(Reg);
    end;
  except
  end;
end;

procedure TInicio.FormShow(Sender: TObject);
var
  AppHandle : HWND;
begin
  AppHandle := GetParent(FmxHandleToHWND(Self.Handle));
  ShowWindow(AppHandle, SW_HIDE);
  SetWindowLong(AppHandle, GWL_EXSTYLE, GetWindowLong(AppHandle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW);

  FProcessando := False;
  FUltimaAtualizacao := 0;
  txtInformacoes.IsMarkdown := True;
  lytScale.Scale.X := 0.75;
  lytScale.Scale.Y := 0.75;

  AtualizaBotao;

  txtNomeData.Text := Configuracao.versao_nova.name +' - '+ FormatDateTime('dd/mm/yyyy hh:nn', ISO8601ToDate(Configuracao.versao_nova.created_at));
  txtInformacoes.Text := Configuracao.versao_nova.body;
end;

procedure TInicio.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  WinHandle: HWND;
begin
  WinHandle := FormToHWND(Self);
  ReleaseCapture;
  SendMessage(WinHandle, WM_NCLBUTTONDOWN, HTCAPTION, 0);
end;

procedure TInicio.ReceiveData(const Sender: TObject; AContentLength: Int64; AReadCount: Int64; var AAbort: Boolean);
begin
  if MilliSecondsBetween(Now, FUltimaAtualizacao) < 500 then
    Exit;

  FUltimaAtualizacao := Now;

  TThread.Synchronize(
    nil,
    procedure
    begin
      if pbAcao.Max <> AContentLength then
        pbAcao.Max := AContentLength;

      faAcao.Stop;
      faAcao.StopValue := AReadCount;
      faAcao.Start;
    end
  );
end;

procedure TInicio.AtualizaBotao;
begin
  if FProcessando then
  begin
    rtgAcao.Fill.Color := TAlphaColorRec.Gray;
    caAcao.StartValue := TAlphaColorRec.Gray;
    caAcao.StopValue := TAlphaColorRec.Dimgray;

    rtgCancelar.Fill.Color := TAlphaColorRec.Gray;
    caCancelar.StartValue := TAlphaColorRec.Gray;
    caCancelar.StopValue := TAlphaColorRec.Dimgray;
  end
  else
  if not TFile.Exists(GetCurrentDir +'\download\'+ Configuracao.versao_nova.name +'\'+ Configuracao.instalador) then
  begin
    txtAcao.Text := 'Download';
    rtgAcao.Fill.Color := TAlphaColorRec.Royalblue;
    caAcao.StartValue := TAlphaColorRec.Royalblue;
    caAcao.StopValue := $FF1248E9;

    rtgCancelar.Fill.Color := TAlphaColorRec.Brown;
    caCancelar.StartValue := TAlphaColorRec.Brown;
    caCancelar.StopValue := TAlphaColorRec.Darkred;
  end
  else
  begin
    txtAcao.Text := 'Instalar';
    rtgAcao.Fill.Color := TAlphaColorRec.Seagreen;
    caAcao.StartValue := TAlphaColorRec.Seagreen;
    caAcao.StopValue := $FF3AA96B;

    rtgCancelar.Fill.Color := TAlphaColorRec.Brown;
    caCancelar.StartValue := TAlphaColorRec.Brown;
    caCancelar.StopValue := TAlphaColorRec.Darkred;
  end;
end;

procedure TInicio.rtgAcaoClick(Sender: TObject);
begin
  if FProcessando then
    Exit;

  FProcessando := True;
  AtualizaBotao;

  if not TFile.Exists(GetCurrentDir +'\download\'+ Configuracao.versao_nova.name +'\'+ Configuracao.instalador) then
  begin
    if not TDirectory.Exists(GetCurrentDir +'\download\'+ Configuracao.versao_nova.name) then
      TDirectory.CreateDirectory(GetCurrentDir +'\download\'+ Configuracao.versao_nova.name);

    TThread.CreateAnonymousThread(
      procedure
      var
        API: TRESTAPI;
      begin
        try
          API := TRESTAPI.Create;
          try
            API.Host(Configuracao.versao_nova.download);
            API.ReceiveData(ReceiveData);
            API.GET;

            if API.Response.Status = TResponseStatus.Sucess then
              API.Response.ToStream.SaveToFile(GetCurrentDir +'\download\'+ Configuracao.versao_nova.name +'\'+ Configuracao.instalador);

            TThread.Synchronize(
              nil,
              procedure
              begin
                faAcao.Stop;
                faAcao.StopValue := pbAcao.Max;
                faAcao.Start;

                FProcessando := False;
                AtualizaBotao;
              end
            );
          finally
            FreeAndNil(API);
          end;
        except on E: Exception do
          begin
            ShowMessage(E.Message);
            FProcessando := False;
            AtualizaBotao;
          end;
        end;
      end
    ).Start;
  end
  else
  begin
    if TDirectory.Exists(GetCurrentDir +'\'+ Configuracao.versao_nova.name) then
      TDirectory.Delete(GetCurrentDir +'\'+ Configuracao.versao_nova.name, True);

    pbAcao.Value := 0;
    pbAcao.Max := 100;

    TThread.CreateAnonymousThread(
      procedure
      var
        Zip: TZipFile;
        BytesProcessados: Int64;
        BytesParaExtrair: Int64;
      begin
        try
          Zip := TZipFile.Create;
          try
            Zip.Open(GetCurrentDir +'\download\'+ Configuracao.versao_nova.name +'\'+ Configuracao.instalador, TZipMode.zmRead);

            BytesParaExtrair := TFile.GetSize(GetCurrentDir +'\download\'+ Configuracao.versao_nova.name +'\'+ Configuracao.instalador);
            BytesProcessados := 0;

            for var I := 0 to Pred(Zip.FileCount) do
            begin
              BytesProcessados := BytesProcessados + Integer(Zip.FileInfo[I].CompressedSize);
              Zip.Extract(I, GetCurrentDir +'\'+ Configuracao.versao_nova.name);

              if MilliSecondsBetween(Now, FUltimaAtualizacao) < 500 then
                Continue;

              FUltimaAtualizacao := Now;

              TThread.Synchronize(
                nil,
                procedure
                begin
                  faAcao.Stop;
                  faAcao.StopValue := BytesProcessados / BytesParaExtrair * 100;
                  faAcao.Start;
                end
              );
            end;

            faAcao.Stop;
            faAcao.StopValue := pbAcao.Max;
            faAcao.Start;

            // Confirma atualização
            Configuracao.versao_atual := Configuracao.versao_nova;
            Configuracao.versao_nova  := Default(TVersao);
            SalvarConfiguracao;

            Close;
          finally
            FreeAndNil(Zip);
          end;
        except on E: Exception do
          begin
            ShowMessage(E.Message);
            FProcessando := False;
            AtualizaBotao;
          end;
        end;
      end
    ).Start;
  end;
end;

procedure TInicio.rtgCancelarClick(Sender: TObject);
begin
  if FProcessando then
    Exit;

  Close;
end;

end.
