# FMXVibration

Small Delphi vibration wrapper for Android and iOS. Call on the frontend thread.

```pascal
if VibrationSupported then
  TryVibrate(40, 128); // milliseconds, intensity 1..255
CancelVibration;
```

`Vibrate(Duration)` remains compatible with existing callers. Zero duration or
zero intensity cancels the current Android effect and does not start another.
`TryVibrate` returns false if unavailable or a native request fails. This does
not guarantee a physical effect: system settings may suppress vibrations.

Android needs `android.permission.VIBRATE` in the application manifest. API 31+
uses VibratorManager, API 26+ uses VibrationEffect, and earlier supported APIs
use the legacy duration overload. Amplitude is used when the motor supports it;
otherwise pulse duration approximates intensity. Effects are finite and can be
stopped using `CancelVibration` (`CanCancelVibration` returns true).

iOS AudioServices produces a fixed system vibration: duration and intensity
cannot be selected and the pulse cannot be cancelled. `VibrationSupported`
reports API availability there; iPads, iPods and simulators may ignore requests.
Use one request per event rather than continuously renewing a rumble motor.

Other platforms report unsupported and perform no action.
