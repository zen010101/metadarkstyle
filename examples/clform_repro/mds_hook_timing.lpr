{
  Repro for issue #42244 — isolates whether the late-installed mds IAT hook
  retroactively changes Canvas paint output for clForm.

  Sequence:
    1. App starts WITHOUT ApplyMetaDarkStyle. mds IAT hook is NOT yet
       installed on user32.GetSysColor.
    2. Form is created. PaintBox A fires its first paint using
       Canvas.Brush.Color := clForm. At this point ColorToRGB(clForm)
       resolves to the unhooked GetSysColor, returning $F0F0F0 (light).
    3. User clicks the button. The handler calls ApplyMetaDarkStyle
       (which installs the IAT hook on Windows.GetSysColor and
       Windows.GetSysColorBrush) and then Self.Invalidate, forcing a
       repaint.
    4. PaintBox A repaints. The same code path (Canvas.Brush.Color := clForm;
       Canvas.FillRect(r)) is executed - the question is whether ColorToRGB(clForm)
       on this second paint observes the hook (-> $353535 dark) or returns
       a stale value (-> still $F0F0F0 light).

  This isolates the timing variable: identical code, identical Canvas, only
  difference is whether mds hook was installed before or after the paint.

  PaintBox B is a control: it always uses DefaultDark.SysColor[COLOR_BTNFACE]
  literal, so it switches to dark as soon as MdsApplied flips - independent
  of any hook.
}
program MdsHookTiming;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls,
  Windows, LCLType,
  uDarkStyleParams, uMetaDarkStyle, uDarkStyleSchemes;

type
  TForm1 = class(TForm)
  private
    FPbA, FPbB: TPaintBox;
    FBtn: TButton;
    FInfo: TLabel;
    procedure PaintA(Sender: TObject);
    procedure PaintB(Sender: TObject);
    procedure ButtonClick(Sender: TObject);
    procedure UpdateInfo;
  public
    constructor Create(TheOwner: TComponent); override;
  end;

var
  Form1: TForm1;
  MdsApplied: Boolean = False;

constructor TForm1.Create(TheOwner: TComponent);
var
  LblA, LblB: TLabel;
begin
  inherited CreateNew(TheOwner);
  Caption := 'mds hook TIMING repro (issue #42244)';
  Width := 720;
  Height := 520;
  Position := poScreenCenter;

  LblA := TLabel.Create(Self);
  LblA.Parent := Self;
  LblA.SetBounds(20, 12, 320, 18);
  LblA.Caption := 'A: Canvas.Brush.Color := clForm';

  FPbA := TPaintBox.Create(Self);
  FPbA.Parent := Self;
  FPbA.SetBounds(20, 32, 320, 120);
  FPbA.OnPaint := @PaintA;

  LblB := TLabel.Create(Self);
  LblB.Parent := Self;
  LblB.SetBounds(360, 12, 340, 18);
  LblB.Caption := 'B: explicit DefaultDark.SysColor[...] (control)';

  FPbB := TPaintBox.Create(Self);
  FPbB.Parent := Self;
  FPbB.SetBounds(360, 32, 340, 120);
  FPbB.OnPaint := @PaintB;

  FBtn := TButton.Create(Self);
  FBtn.Parent := Self;
  FBtn.SetBounds(20, 170, 680, 36);
  FBtn.Caption := 'Click to call ApplyMetaDarkStyle, then Invalidate';
  FBtn.OnClick := @ButtonClick;

  FInfo := TLabel.Create(Self);
  FInfo.Parent := Self;
  FInfo.SetBounds(20, 220, 680, 280);
  FInfo.WordWrap := True;
  FInfo.AutoSize := False;
  UpdateInfo;
end;

procedure TForm1.UpdateInfo;
begin
  FInfo.Caption := Format(
    'mds applied: %s' + LineEnding +
    'Live: GetSysColor(COLOR_BTNFACE) = $%.6x   ColorToRGB(clForm) = $%.6x' +
    LineEnding + LineEnding +
    'Before clicking the button: A should be LIGHT (hook not installed,' +
    LineEnding +
    'clForm resolves to original $F0F0F0). B is white (control, mds not active).' +
    LineEnding + LineEnding +
    'After clicking the button:' + LineEnding +
    '  - If A becomes DARK on repaint: LCL Canvas re-queries GetSysColor on' +
    LineEnding +
    '    every FillRect, so the late-installed hook DOES retroactively fix' +
    LineEnding +
    '    paint. -> IDE dock header bug must be an Invalidate / event-loop' +
    LineEnding +
    '    coverage problem (anchordocking does not get a repaint event).' +
    LineEnding +
    '  - If A stays LIGHT despite Invalidate: there is a brush / handle' +
    LineEnding +
    '    cache somewhere that bypasses the hook on subsequent paints.' +
    LineEnding +
    '    -> the hook itself does not retroactively cover everything.' +
    LineEnding + LineEnding +
    'B will become dark immediately on click - it does not depend on hook.',
    [BoolToStr(MdsApplied, True),
     Windows.GetSysColor(COLOR_BTNFACE),
     ColorToRGB(clForm)]);
end;

procedure TForm1.PaintA(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
begin
  C := TPaintBox(Sender).Canvas;
  R := TPaintBox(Sender).ClientRect;
  C.Brush.Color := clForm;
  C.FillRect(R);
  C.Pen.Color := clBlack;
  C.Rectangle(R);
end;

procedure TForm1.PaintB(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
begin
  C := TPaintBox(Sender).Canvas;
  R := TPaintBox(Sender).ClientRect;
  if MdsApplied then
    C.Brush.Color := DefaultDark.SysColor[COLOR_BTNFACE]
  else
    C.Brush.Color := clWhite;
  C.FillRect(R);
  C.Pen.Color := clBlack;
  C.Rectangle(R);
end;

procedure TForm1.ButtonClick(Sender: TObject);
begin
  PreferredAppMode := pamAllowDark;
  uMetaDarkStyle.ApplyMetaDarkStyle(DefaultDark);
  MdsApplied := True;
  UpdateInfo;
  Self.Invalidate;
end;

{$R *.res}

begin
  // INTENTIONAL: ApplyMetaDarkStyle is NOT called here. mds hook is installed
  // only after the user clicks the button, AFTER the form's first paint.
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
