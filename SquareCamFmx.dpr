program SquareCamFmx;

uses
  System.StartUpCopy,
  FMX.MobilePreview,
  FMX.Forms,
  uFMain in 'uFMain.pas' {FMain};

{$R *.res}

begin
  Application.Initialize;
  Application.FormFactor.Orientations := [TFormOrientation.soPortrait];
  Application.CreateForm(TFMain, FMain);
  Application.Run;
end.
