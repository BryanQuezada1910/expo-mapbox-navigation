# Current-road speed limit bridge

`onSpeedLimitChanged` emits the same posted speed limit used by the native
indicator, on every location-matching update, in calculated and planned modes:

```ts
type SpeedLimitEvent = {
  speedLimit: number | null;
  unit: 'km/h' | 'mph';
  latitude: number;
  longitude: number;
  timestamp: number; // Unix milliseconds at emission
};
```

An unavailable, nonfinite or nonpositive posted limit emits `null`. Consumers
must expire old metadata and compare it with a fresh vehicle-speed source. This
event is not the vehicle's current speed, and does not guarantee map coverage.

`playAlertSound(filename)` plays a short audio asset from the host app bundle.
The host must register the file (for example with the Expo notifications plugin).
Android resolves a `raw` resource and iOS resolves the main bundle. Playback uses
native audio rather than notification permission. A new invocation replaces the
previous sound; player resources are released on completion/module destruction.

Both APIs require rebuilding the native app. MOC LOAD's integration uses its GPS
provider for vehicle speed and owns country thresholds and background notifications.
