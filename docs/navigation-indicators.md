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
does not hide a valid turn. An arrival instruction for an intermediate window is
replaced by a continuation instruction, such as “Continúa por N Interstate 35”,
using the current matched road name or the current SDK step's road name. The
continuation has a forward icon and no artificial arrival distance. If the road
name is unknown, it says “Continúa por la ruta marcada” without inventing a turn.
The final destination still uses the SDK's arrival instruction.

The wrapper supplies the internal `guidanceStatus` bridge prop. The native banner
shows “Preparando indicaciones” or “Indicaciones no disponibles” before GPS can
be classified against the route. The internal `isOnPlannedRoute` prop distinguishes
unknown GPS from an on-route or off-route location. On route, a continuation stays
visible while a new matching window loads, retries or has no renderable maneuver.
Off route, “Fuera de la ruta planificada” takes precedence over loading and errors.
It restores the current instruction on rejoining, without requiring another route
request or a new instruction event.
Android now constrains the banner to the available width and continues updating
the camera and progress when instructions are suppressed.

The original geometry, deviation validation, route windows, retry policy and
disabled rerouting remain authoritative. These changes do not synthesize turns
when Map Matching cannot provide a valid guide.

`onGuidanceStateChanged.state` describes the visible guidance. Once valid GPS
has been classified against a valid trace, it remains `available` because native
UI can show a maneuver, continuation or off-route message. Consumers must not
cover that UI with a loading overlay for internal matching-window changes.
Matching failures still populate `errorMessage`, and the internal retry state
continues independently. Before GPS is available, `preparing` and `unavailable`
retain their previous meaning.

## Overview and following camera

Planned overview frames the complete original trace rather than the current
100-point matching window or its remaining portion. Android includes the full
trace as additional overview framing points. iOS wraps the SDK viewport source,
replacing only its overview target with a camera fitted to the full trace; SDK
following targets remain intact. The fitted iOS target is cached until the trace,
viewport dimensions or padding changes.

The overview action is shown only while following. In overview or after a manual
pan, only the follow action is shown. Android places these actions in the same
control slot and registers its camera observer once per attachment. iOS uses the
SDK overview and resume controls, observing the SDK camera state. Internal route
window replacements preserve overview/manual camera mode on both platforms.

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
a road without speed metadata and a road with a known posted limit. On a long
straight road, confirm the continuation instruction stays visible between windows.
In overview, confirm the start, finish and intermediate detours of the entire
trace fit on screen, including after a matching-window change and rotation.
Check that only one camera action is visible in following, overview and manual
pan states. Check that the displayed path and rerouting policy are preserved.
Test with voice muted and
enabled; intermediate arrivals must not be announced as final destinations.

Deterministic regression commands are documented in `tests/README.md`.
