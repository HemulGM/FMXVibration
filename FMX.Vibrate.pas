unit FMX.Vibrate;

interface

// Best-effort host haptics. Android applications need android.permission.VIBRATE.
// Call from the frontend thread. Unsupported platforms safely return False.
function VibrationSupported: Boolean;
function CanCancelVibration: Boolean;
function TryVibrate(const Duration: UInt16; const Intensity: Byte = 255): Boolean;
// A short UI impact, independent of emulated game rumble. Frontend thread only.
procedure TouchImpact;
procedure CancelVibration;
// Backwards-compatible entry point; zero duration cancels an Android effect.
procedure Vibrate(const Duration: UInt16);

implementation

uses
  System.SysUtils
  {$IFDEF ANDROID}
  , Androidapi.JNI.Os, Androidapi.JNI.GraphicsContentViewText, Androidapi.Helpers,
  Androidapi.JNIBridge, Androidapi.JNI.JavaTypes
  {$ENDIF}
  {$IFDEF IOS}
  , Macapi.ObjCRuntime, iOSapi.UIKit
  {$ENDIF};

{$IFDEF ANDROID}
var
  HostVibrator: JVibrator;

function GetVibrator: JVibrator;
begin
  if HostVibrator = nil then
  begin
    if TAndroidHelper.Context = nil then Exit(nil);
    // API 31 moved vibrator discovery to VibratorManager. Avoid referring to
    // that Java class on older devices, which cannot load it.
    if TJBuild_VERSION.JavaClass.SDK_INT >= 31 then
    begin
      var Service := TAndroidHelper.Context.getSystemService(StringToJString('vibrator_manager'));
      if Service <> nil then
        HostVibrator := TJVibratorManager.Wrap((Service as ILocalObject).GetObjectID).getDefaultVibrator;
    end
    else
    begin
      var Service := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.VIBRATOR_SERVICE);
      if Service <> nil then HostVibrator := TJVibrator.Wrap((Service as ILocalObject).GetObjectID);
    end;
  end;
  Result := HostVibrator;
end;
{$ENDIF}

{$IFDEF IOS}
const
  AudioToolboxLibrary = '/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox';
  SystemSoundVibrate: UInt32 = $FFF;

procedure AudioServicesPlaySystemSound(SoundID: UInt32); cdecl;
  external AudioToolboxLibrary name _PU + 'AudioServicesPlaySystemSound';
var
  TouchFeedback: UIImpactFeedbackGenerator;
{$ENDIF}

procedure TouchImpact;
begin
  {$IFDEF ANDROID}
  TryVibrate(12, 160);
  {$ENDIF}
  {$IFDEF IOS}
  try
    if TouchFeedback = nil then
      TouchFeedback := TUIImpactFeedbackGenerator.Wrap(
        TUIImpactFeedbackGenerator.Alloc.initWithStyle(UIImpactFeedbackStyleLight));
    TouchFeedback.impactOccurred;
  except
    // Missing haptics must never interfere with touch input.
  end;
  {$ENDIF}
end;

function VibrationSupported: Boolean;
begin
  {$IFDEF ANDROID}
  try
    var Device := GetVibrator;
    Result := (Device <> nil) and Device.hasVibrator;
  except
    // A device/provider failure is not an emulation failure.
    Result := False;
  end;
  {$ELSE}
  {$IFDEF IOS}
  // AudioServices has no capability probe. Requests are best effort; iPad,
  // iPod and simulators may ignore them even though the API is available.
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
  {$ENDIF}
end;

function CanCancelVibration: Boolean;
begin
  {$IFDEF ANDROID}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure CancelVibration;
begin
  {$IFDEF ANDROID}
  try
    var Device := GetVibrator;
    if Device <> nil then Device.cancel;
  except
    // Permission/service failures must not prevent pausing or shutdown.
  end;
  {$ENDIF}
  // AudioServices on iOS exposes no cancellation of the system vibration.
end;

function TryVibrate(const Duration: UInt16; const Intensity: Byte): Boolean;
begin
  Result := False;
  if (Duration = 0) or (Intensity = 0) then
  begin
    CancelVibration;
    Exit;
  end;
  {$IFDEF ANDROID}
  try
    var Device := GetVibrator;
    if (Device = nil) or not Device.hasVibrator then Exit;
    var PulseDuration: Int64 := Duration;
    if TJBuild_VERSION.JavaClass.SDK_INT >= 26 then
    begin
      var Amplitude := Integer(Intensity);
      if not Device.hasAmplitudeControl then
      begin
        Amplitude := TJVibrationEffect.JavaClass.DEFAULT_AMPLITUDE;
        PulseDuration := (Integer(Duration) * Intensity + 254) div 255;
      end;
      Device.vibrate(TJVibrationEffect.JavaClass.createOneShot(PulseDuration, Amplitude));
    end
    else
    begin
      // Older hardware has on/off control only: approximate duty by duration.
      PulseDuration := (Integer(Duration) * Intensity + 254) div 255;
      Device.vibrate(PulseDuration);
    end;
    Result := True;
  except
    // Includes missing manifest permission and unavailable native services.
    Result := False;
  end;
  {$ENDIF}
  {$IFDEF IOS}
  // This is a fixed system pulse. Duration/intensity cannot be controlled by
  // AudioServices; callers must not use it as a repeatedly renewed motor.
  AudioServicesPlaySystemSound(SystemSoundVibrate);
  Result := True;
  {$ENDIF}
end;

procedure Vibrate(const Duration: UInt16);
begin
  TryVibrate(Duration);
end;

{$IFDEF IOS}
initialization
finalization
  if TouchFeedback <> nil then
    TouchFeedback.release;
  TouchFeedback := nil;
{$ENDIF}

end.
