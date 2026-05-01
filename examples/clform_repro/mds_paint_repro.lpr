{
  Minimal metadarkstyle application that reproduces the wrong-color paint
  for issue #42244, requested by @zamtmn:
  https://gitlab.com/freepascal.org/lazarus/lazarus/-/work_items/42244

  No Lazarus IDE, no AnchorDocking. Just the smallest possible LCL form that:
    1. activates metadarkstyle (PreferredAppMode := pamAllowDark; ApplyMetaDarkStyle(DefaultDark)),
    2. paints two side-by-side rectangles - "A" using clForm (the buggy
       literal that anchordocking and friends use), "B" using the active
       scheme's COLOR_BTNFACE color (the correct value),
    3. shows the live numeric values: Windows.GetSysColor(COLOR_BTNFACE),
       ColorToRGB(clForm), and DefaultDark.SysColor[COLOR_BTNFACE].

  Expected on Windows 10/11 with system Dark mode set, especially over RDP:
    - A is rendered LIGHT GRAY (the bug).
    - B is rendered DARK (correct).
  Both PaintBoxes are children of the same metadarkstyle-themed form;
  the only difference is the color literal: clForm vs scheme color.

  Build:  lazbuild mds_paint_repro.lpi
}
program MdsPaintRepro;

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
    procedure PaintA(Sender: TObject);
    procedure PaintB(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
  end;

var
  Form1: TForm1;

constructor TForm1.Create(TheOwner: TComponent);
var
  LblA, LblB, Info: TLabel;
begin
  inherited CreateNew(TheOwner);
  Caption := 'metadarkstyle: clForm vs Scheme[COLOR_BTNFACE] (issue #42244)';
  Width := 720;
  Height := 420;
  Position := poScreenCenter;

  LblA := TLabel.Create(Self);
  LblA.Parent := Self;
  LblA.SetBounds(20, 12, 320, 18);
  LblA.Caption := 'A: Canvas.Brush.Color := clForm   (the bug path)';

  FPbA := TPaintBox.Create(Self);
  FPbA.Parent := Self;
  FPbA.SetBounds(20, 32, 320, 120);
  FPbA.OnPaint := @PaintA;

  LblB := TLabel.Create(Self);
  LblB.Parent := Self;
  LblB.SetBounds(360, 12, 340, 18);
  LblB.Caption := 'B: Canvas.Brush.Color := Scheme.SysColor[COLOR_BTNFACE]';

  FPbB := TPaintBox.Create(Self);
  FPbB.Parent := Self;
  FPbB.SetBounds(360, 32, 340, 120);
  FPbB.OnPaint := @PaintB;

  Info := TLabel.Create(Self);
  Info.Parent := Self;
  Info.SetBounds(20, 170, 680, 230);
  Info.AutoSize := False;
  Info.WordWrap := True;
  Info.Caption := Format(
    'Live measurements:' + LineEnding +
    '  Windows.GetSysColor(COLOR_BTNFACE) = $%.6x' + LineEnding +
    '  ColorToRGB(clForm)                 = $%.6x' + LineEnding +
    '  DefaultDark.SysColor[COLOR_BTNFACE] = $%.6x' + LineEnding +
    LineEnding +
    'Setup: PreferredAppMode := pamAllowDark; ApplyMetaDarkStyle(DefaultDark);' +
    LineEnding + LineEnding +
    'Expected on Windows 10/11 with system Dark mode (especially over RDP):' +
    LineEnding +
    '  A is rendered LIGHT GRAY (the bug).  B is rendered DARK (correct).' +
    LineEnding +
    'Both PaintBoxes are inside the same metadarkstyle-themed form, so the' +
    LineEnding +
    'difference is purely the color literal: clForm vs the explicit scheme' +
    LineEnding +
    'color. clForm resolves to GetSysColor(COLOR_BTNFACE), which does not' +
    LineEnding +
    'follow the system dark-mode setting (see issue #42244).',
    [Windows.GetSysColor(COLOR_BTNFACE),
     ColorToRGB(clForm),
     DefaultDark.SysColor[COLOR_BTNFACE]]);
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
  C.Brush.Color := DefaultDark.SysColor[COLOR_BTNFACE];
  C.FillRect(R);
  C.Pen.Color := clBlack;
  C.Rectangle(R);
end;

{$R *.res}

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  PreferredAppMode := pamAllowDark;
  uMetaDarkStyle.ApplyMetaDarkStyle(DefaultDark);
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
