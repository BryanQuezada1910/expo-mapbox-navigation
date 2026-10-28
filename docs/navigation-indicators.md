# Navigation instructions and speed limits

These fixes live in the library on Android and iOS. Consumers using
`routeMode="planned"` do not need an application patch or additional props.
Rebuild the native app after installing the updated library; an OTA update cannot
replace its Kotlin or Swift code.

## Instructions

Both platforms use only the original Mapbox maneuver component: Android's
`MapboxManeuverView` and iOS's `InstructionsBannerView`. If the SDK cannot provide
an instruction, the maneuver area is hidden. Custom continuation, preparing,
unavailable and off-route banners have been removed. The host application must
also avoid drawing a replacement banner over the navigation map.

Planned guidance requires an accepted match for the current revision and a GPS
position on the original trace. An intermediate window's artificial arrival is
hidden; a valid turn before that arrival remains visible, and the real final
arrival continues to use the SDK component. On rejoining, the current SDK
instruction is rendered again without waiting for another instruction event.
Camera, route progress, speed-limit updates and off-route events continue while
the maneuver area is hidden.

Android enables `ExpoView.shouldUseAndroidLayout` so native changes to maneuver
visibility and height trigger measure/layout outside React Native's Yoga tree.
Without this, an instruction that became visible after initial layout could
remain at zero height. Both native route controllers deliver each active revision
only once: unrelated prop updates and prefetch changes reuse the guide instead
of reinstalling it and resetting its progress. A new revision or a reset still
installs normally. iOS also attaches the navigation child controller only once,
avoiding repeated containment and constraints across matching windows.

The original geometry, deviation validation, route windows, retry policy and
disabled rerouting remain authoritative. These changes do not synthesize turns
when Map Matching cannot provide a valid guide.

`onGuidanceStateChanged.state` describes readiness for native guidance. It becomes
`available` only after the current match is accepted and GPS is on the original
trace. GPS classification alone no longer reports available instructions.
While loading or retrying a window it reports `preparing` or `unavailable`;
off-route positions report `unavailable`. Matching failures still include
`errorMessage`. The SDK can still lack a visual maneuver even with an accepted
match; in that case the original component stays hidden.

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
straight road, confirm that only valid SDK maneuvers appear; gaps between
windows must remain empty, with no continuation or status replacement.
In overview, confirm the start, finish and intermediate detours of the entire
trace fit on screen, including after a matching-window change and rotation.
Check that only one camera action is visible in following, overview and manual
pan states. Check that the displayed path and rerouting policy are preserved.
Test with voice muted and
enabled; intermediate arrivals must not be announced as final destinations.

Deterministic regression commands are documented in `tests/README.md`.
