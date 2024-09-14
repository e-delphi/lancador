// Eduardo - 01/09/2024
program Lancador;

uses
  System.StartUpCopy,
  FMX.Forms,
  Lancador.Inicio in 'src\Lancador.Inicio.pas' {Inicio},
  REST.API in 'src\REST.API.pas',
  Lancador.Markdown in 'src\Lancador.Markdown.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;

  if not TInicio.CarregarConfiguracao then
    Exit;

  TInicio.Iniciar;
end.
