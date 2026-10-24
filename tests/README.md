# Planned route regression tests

Run the JavaScript route-window and guidance tests from the package root:

```sh
node --test tests/plannedRoute.test.cjs
```

The native validators share `plannedRouteGeometryCases.json`. Fixture coordinates
are local offsets in meters around latitude 19, longitude -99, rather than live
customer routes. Both harnesses check acceptance and the reason for each rejection.
The nearby-hairpin cases reproduce the old nearest-edge false rejection at a
6-meter offset with a 25-meter tolerance. The omitted-hairpin and reversed-loop
cases ensure the fix does not accept a different traversal inside the same corridor.

## Android

Compile the production validator and its JVM harness using Kotlin and the
Mapbox GeoJSON and Gson jars resolved by the app's Gradle build. Set
`MAPBOX_GEOJSON_JAR` and `GSON_JAR` to those jar paths, and run from this directory's
parent (the package root):

```sh
kotlinc android/src/main/java/expo/modules/mapboxnavigation/NavigationStrings.kt android/src/main/java/expo/modules/mapboxnavigation/PlannedRouteGeometry.kt tests/plannedRouteGeometry.test.kt -classpath "$MAPBOX_GEOJSON_JAR:$GSON_JAR" -include-runtime -d /tmp/planned-route-geometry.jar
java -cp "/tmp/planned-route-geometry.jar:$MAPBOX_GEOJSON_JAR:$GSON_JAR" expo.modules.mapboxnavigation.PlannedRouteGeometry_testKt tests/plannedRouteGeometryCases.json
```

This runs the actual Android validator without an emulator or a live API token.
Compile the integrated Android module from the app's `android` directory:

```sh
./gradlew :bryandev-expo-mapbox-navigation:compileDebugKotlin --offline --console=plain
```

## iOS

On macOS, from the package root:

```sh
xcrun swiftc ios/NavigationLocale.swift ios/NavigationStrings.swift ios/PlannedRouteGeometry.swift tests/plannedRouteGeometry.test.swift -o /tmp/planned-route-geometry
/tmp/planned-route-geometry tests/plannedRouteGeometryCases.json
```

Both platforms must pass all shared fixtures. Device verification of real route
responses, location, and voice remains separate from these deterministic tests.

## Navigation indicator regression tests

`navigationPresentationCases.json` is shared by Kotlin and Swift. It covers
preparing/unavailable/off-route instructions, turns before an artificial arrival,
intermediate versus final arrivals, on-route continuity during matching-window
loading/retries, road-name continuation instructions, numeric limits, missing
limits and errors.
Both harnesses also reject nonfinite speed values. The JavaScript suite above
checks the bridge status through route loads, window changes, failures, retries,
departure and rejoining without another route request.
It also verifies that matching retries keep running while visible guidance stays
available and that off-route status takes precedence over a failed match.

```sh
kotlinc android/src/main/java/expo/modules/mapboxnavigation/NavigationStrings.kt android/src/main/java/expo/modules/mapboxnavigation/NavigationPresentation.kt tests/navigationPresentation.test.kt -classpath "$GSON_JAR" -include-runtime -d /tmp/navigation-presentation-tests.jar
java -cp "/tmp/navigation-presentation-tests.jar:$GSON_JAR" expo.modules.mapboxnavigation.NavigationPresentation_testKt tests/navigationPresentationCases.json
xcrun swiftc ios/NavigationLocale.swift ios/NavigationStrings.swift ios/NavigationPresentation.swift tests/navigationPresentation.test.swift -o /tmp/navigation-presentation-tests
/tmp/navigation-presentation-tests tests/navigationPresentationCases.json
```

See `docs/navigation-indicators.md` for behavior and device verification cases.

## Camera controller regression

This harness runs the production Android camera controller with recording test
doubles for Android views and the SDK camera/viewport. It checks full-trace
framing inputs, exclusive overview/follow controls, preserving overview across
window replacements (including a delayed first matching response), manual pan,
calculated-mode cleanup and observer registration/removal.

```sh
kotlinc android/src/main/java/expo/modules/mapboxnavigation/NavigationCameraController.kt tests/navigationCamera.test.kt tests/navigation-camera/*.kt -classpath "$MAPBOX_GEOJSON_JAR:$GSON_JAR" -include-runtime -d /tmp/navigation-camera-tests.jar
java -cp "/tmp/navigation-camera-tests.jar:$MAPBOX_GEOJSON_JAR:$GSON_JAR" expo.modules.mapboxnavigation.NavigationCamera_testKt
```

The test doubles are only for the standalone JVM harness and never enter the
Android library build. Compilation against the installed SDK verifies the real
API separately; framing on screen, layout/rotation and iOS camera controls still
require device verification.

## Locale and SDK resource regression tests

The shared catalog generates the native catalogs; the JavaScript suite checks
that they are synchronized. Shared fixtures cover explicit Spanish/English,
regional variants, underscore/case normalization, device defaults and custom-UI
fallback. Hook tests cover a live locale change, stale old-language responses,
and invalid-geometry messages changing language without a route change.

```sh
node --test tests/plannedRoute.test.cjs tests/navigationLocalization.test.cjs
kotlinc android/src/main/java/expo/modules/mapboxnavigation/NavigationLocale.kt android/src/main/java/expo/modules/mapboxnavigation/NavigationStrings.kt android/src/main/java/expo/modules/mapboxnavigation/NavigationPresentation.kt tests/navigationLocalization.test.kt -classpath "$GSON_JAR" -include-runtime -d /tmp/navigation-localization-tests.jar
java -cp "/tmp/navigation-localization-tests.jar:$GSON_JAR" expo.modules.mapboxnavigation.NavigationLocalization_testKt tests/navigationLocalizationCases.json src/configs/localization/navigationStrings.json
xcrun swiftc ios/NavigationLocale.swift ios/NavigationStrings.swift ios/NavigationPresentation.swift tests/navigationLocalization.test.swift -o /tmp/navigation-localization-tests
/tmp/navigation-localization-tests tests/navigationLocalizationCases.json src/configs/localization/navigationStrings.json
xcrun swiftc ios/NavigationLocale.swift ios/NavigationLocalization.swift tests/navigationBundles.test.swift -o /tmp/navigation-bundle-tests
/tmp/navigation-bundle-tests
```

The bundle harness switches actual temporary Mapbox resource bundles between
Spanish and English while checking that a host-app bundle and `AppleLanguages`
remain unchanged. Native UI layout, generated Mapbox turns and speech still
require verification in a fresh device build.
