# Navigation instructions and speed limits

These fixes live in the library on Android and iOS. Consumers using
`routeMode="planned"` do not need an application patch or additional props.
Rebuild the native app after installing the updated library; an OTA update cannot
replace its Kotlin or Swift code.

## Instructions

The old planned-route policy hid the entire banner when either the current step
or the upcoming step was an arrival. A window with only a departure and an
artificial arrival could therefore hide instructions throughout that window.
The policy now examines the current visual instruction first. A later arrival
does not hide a valid turn. Only an arrival instruction for an intermediate
window is suppressed, with “Continuando ruta planificada” shown during the
transition. The final destination still uses the SDK's arrival instruction.

The wrapper supplies the internal `guidanceStatus` bridge prop. The native banner
shows “Preparando indicaciones”, “Indicaciones no disponibles” or “Fuera de la
ruta planificada” when turn instructions cannot be shown. It restores the current
instruction on rejoining, without requiring another route request or a new
instruction event. Empty/error maneuver results also show an explicit status.
Android now constrains the banner to the available width and continues updating
the camera and progress when instructions are suppressed.

The original geometry, deviation validation, route windows, retry policy and
disabled rerouting remain authoritative. These changes do not synthesize turns
when Map Matching cannot provide a valid guide.

## Speed limits

The indicator is driven by location matching independently of guidance or route
progress. Android previously returned before updating it in planned mode. iOS
previously only updated its unit label on route progress, so missing progress or
road metadata could leave the native sign empty.

Both platforms now show a persistent circle with:

- A positive posted limit and its existing regional unit (`km/h` or `mph`).
- “Sin datos” when the SDK provides no usable posted limit for the current road.
- “Error de datos” when processing the speed update fails (Android's throwing API).

Missing limits are never replaced with the vehicle's current speed or an assumed
legal limit. Unknown/error states use a neutral border and full accessibility
descriptions. The next valid location-matching update restores the numeric limit.
Planned Map Matching requests explicitly request `maxspeed` metadata on both
platforms; iOS also explicitly requests steps and visual/spoken instructions.

SDK references: [maneuver rendering](https://docs.mapbox.com/android/navigation/guides/ui-components/maneuver/)
and [Map Matching parameters](https://docs.mapbox.com/api/navigation/map-matching/).

## Verification on a device

Use a new native build to check a planned route with a turn inside a window,
an intermediate window boundary, departure/rejoin, a rejected matching response,
a road without speed metadata and a road with a known posted limit. Check that
the displayed path and rerouting policy are preserved. Test with voice muted and
enabled; intermediate arrivals must not be announced as final destinations.

Deterministic regression commands are documented in `tests/README.md`.
