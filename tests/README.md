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
kotlinc android/src/main/java/expo/modules/mapboxnavigation/PlannedRouteGeometry.kt tests/plannedRouteGeometry.test.kt -classpath "$MAPBOX_GEOJSON_JAR:$GSON_JAR" -include-runtime -d /tmp/planned-route-geometry.jar
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
xcrun swiftc ios/PlannedRouteGeometry.swift tests/plannedRouteGeometry.test.swift -o /tmp/planned-route-geometry
/tmp/planned-route-geometry tests/plannedRouteGeometryCases.json
```

Both platforms must pass all shared fixtures. Device verification of real route
responses, location, and voice remains separate from these deterministic tests.
