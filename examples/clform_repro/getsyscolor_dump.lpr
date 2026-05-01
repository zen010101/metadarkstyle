{
  Minimal repro for Lazarus issue #42244 — demonstrates that Windows.GetSysColor
  on Win10/11 does NOT follow the system dark-mode setting for the COLOR_*
  indices that LCL clForm / clBtnFace / clWindow ultimately resolve to.

  This is a pure Win32 console program — no LCL widgets, no metadarkstyle, no
  custom code. It just calls Windows.GetSysColor and Windows.GetSystemMetrics
  and prints the results plus the running OS version. Build with:

    lazbuild getsyscolor_dump.lpi

  Run on a Windows host whose system theme is Dark (control panel > Personalize
  > Colors > Choose your default app/Windows mode = Dark), and observe that
  COLOR_BTNFACE / COLOR_3DFACE still return the classic light-gray RGB values,
  contradicting the assumption that the legacy GetSysColor API tracks the
  Win10/11 dark-mode setting.
}
program GetSysColorDump;

{$mode objfpc}{$H+}

uses
  Windows, SysUtils, Registry;

procedure DumpDarkModeReg;
var
  R: TRegistry;

  function ReadDword(const AName: string): string;
  begin
    if R.ValueExists(AName) then
      Result := IntToStr(R.ReadInteger(AName))
    else
      Result := '(not present)';
  end;

begin
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKeyReadOnly(
      'SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize') then
    begin
      WriteLn('HKCU\...\Themes\Personalize:');
      WriteLn('  AppsUseLightTheme    = ', ReadDword('AppsUseLightTheme'),
        '   (0 = apps in Dark mode)');
      WriteLn('  SystemUsesLightTheme = ', ReadDword('SystemUsesLightTheme'),
        '   (0 = system in Dark mode)');
      R.CloseKey;
    end
    else
      WriteLn('Could not open Personalize key');
  finally
    R.Free;
  end;
end;

procedure DumpC(const AName: string; NIndex: Integer);
var
  V: DWORD;
begin
  V := Windows.GetSysColor(NIndex);
  WriteLn(Format('  %-18s (idx %2d) = $%.6x  RGB(%3d,%3d,%3d)',
    [AName, NIndex,
     V,
     V and $FF, (V shr 8) and $FF, (V shr 16) and $FF]));
end;

begin
  WriteLn('Session is RDP: ',
    BoolToStr(Windows.GetSystemMetrics(SM_REMOTESESSION) <> 0, True));
  WriteLn;
  DumpDarkModeReg;
  WriteLn;
  WriteLn('Windows.GetSysColor results (no dark-mode hooks installed):');
  DumpC('COLOR_BTNFACE',    COLOR_BTNFACE);
  DumpC('COLOR_3DFACE',     15);
  DumpC('COLOR_WINDOW',     COLOR_WINDOW);
  DumpC('COLOR_WINDOWTEXT', COLOR_WINDOWTEXT);
  DumpC('COLOR_BTNTEXT',    COLOR_BTNTEXT);
  DumpC('COLOR_MENU',       COLOR_MENU);
  DumpC('COLOR_MENUTEXT',   COLOR_MENUTEXT);
  DumpC('COLOR_HIGHLIGHT',  COLOR_HIGHLIGHT);
  DumpC('COLOR_BTNSHADOW',  COLOR_BTNSHADOW);
end.
