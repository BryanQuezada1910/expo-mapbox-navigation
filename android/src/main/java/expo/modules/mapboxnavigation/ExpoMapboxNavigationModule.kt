package expo.modules.mapboxnavigation

import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.mapbox.geojson.Point
import com.mapbox.navigation.base.options.NavigationOptions
import com.mapbox.navigation.core.lifecycle.MapboxNavigationApp
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class ExpoMapboxNavigationModule : Module() {
  @com.mapbox.navigation.base.ExperimentalPreviewMapboxNavigationAPI
  override fun definition() = ModuleDefinition {
    Name("ExpoMapboxNavigation")

    OnActivityEntersForeground {
      val currentActivity = appContext.activityProvider?.currentActivity ?: return@OnActivityEntersForeground
      val applicationContext = currentActivity.applicationContext

      (currentActivity as LifecycleOwner).lifecycleScope.launch(Dispatchers.Main) {
        if (!MapboxNavigationApp.isSetup()) {
          MapboxNavigationApp.setup {
            NavigationOptions.Builder(applicationContext).build()
          }
        }
        MapboxNavigationApp.attach(currentActivity as LifecycleOwner)
      }
    }

    View(ExpoMapboxNavigationView::class) {
      Events(
              "onRouteProgressChanged",
              "onCancelNavigation",
              "onWaypointArrival",
              "onFinalDestinationArrival",
              "onRouteChanged",
              "onUserOffRoute",
              "onRoutesLoaded",
              "onRouteFailedToLoad",
              "onMarkerPress",
              "onPlannedRouteLocation"
      )

      Prop("routeMode") { view: ExpoMapboxNavigationView, value: String? -> view.setRouteMode(value) }
      Prop("reroutingEnabled") { view: ExpoMapboxNavigationView, value: Boolean? -> view.setReroutingEnabled(value) }
      Prop("routeDeviationTolerance") { view: ExpoMapboxNavigationView, value: Double? -> view.setRouteDeviationTolerance(value) }
      Prop("routeRevision") { view: ExpoMapboxNavigationView, value: String? -> view.setRouteRevision(value) }
      Prop("guidanceEnabled") { view: ExpoMapboxNavigationView, value: Boolean? -> view.setGuidanceEnabled(value) }
      Prop("guidanceStatus") { view: ExpoMapboxNavigationView, value: String? -> view.setGuidanceStatus(value) }
      Prop("isFinalRouteChunk") { view: ExpoMapboxNavigationView, value: Boolean? -> view.setFinalRouteChunk(value) }
      Prop("plannedRouteCoordinates") { view: ExpoMapboxNavigationView, value: List<Map<String, Double>>? ->
        view.setPlannedRouteCoordinates(value?.map { Point.fromLngLat(it.getValue("longitude"), it.getValue("latitude")) } ?: emptyList())
      }
      Prop("prefetchCoordinates") { view: ExpoMapboxNavigationView, value: List<Map<String, Double>>? ->
        view.setPrefetchCoordinates(value?.map { Point.fromLngLat(it.getValue("longitude"), it.getValue("latitude")) } ?: emptyList())
      }
      Prop("plannedRouteProgress") { view: ExpoMapboxNavigationView, value: Map<String, Double>? -> view.setPlannedRouteProgress(value) }

      Prop("coordinates") { view: ExpoMapboxNavigationView, coordinates: List<Map<String, Any>> ->
        val points = mutableListOf<Point>()
        for (coordinate in coordinates) {
          val longValue = coordinate.get("longitude")
          val latValue = coordinate.get("latitude")
          if (longValue is Double && latValue is Double) {
            points.add(Point.fromLngLat(longValue, latValue))
          }
        }
        view.setCoordinates(points)
      }

      Prop("vehicleMaxHeight") { view: ExpoMapboxNavigationView, maxHeight: Double? ->
        view.setVehicleMaxHeight(maxHeight)
      }

      Prop("vehicleMaxWidth") { view: ExpoMapboxNavigationView, maxWidth: Double? ->
        view.setVehicleMaxWidth(maxWidth)
      }

      Prop("waypointIndices") { view: ExpoMapboxNavigationView, indices: List<Int>? ->
        view.setWaypointIndices(indices)
      }

      Prop("locale") { view: ExpoMapboxNavigationView, localeStr: String? ->
        view.setLocale(localeStr)
      }

      Prop("useRouteMatchingApi") { view: ExpoMapboxNavigationView, useRouteMatchingApi: Boolean? ->
        view.setIsUsingRouteMatchingApi(useRouteMatchingApi)
      }

      Prop("routeProfile") { view: ExpoMapboxNavigationView, profile: String? ->
        view.setRouteProfile(profile)
      }

      Prop("routeExcludeList") { view: ExpoMapboxNavigationView, excludeList: List<String>? ->
        view.setRouteExcludeList(excludeList)
      }

      Prop("mapStyle") { view: ExpoMapboxNavigationView, style: String? -> view.setMapStyle(style) }

      Prop("mute") { view: ExpoMapboxNavigationView, isMuted: Boolean? -> view.setIsMuted(isMuted) }

      Prop("initialLocation") { view: ExpoMapboxNavigationView, initialLocation: Map<String, Any>?
        ->
        val longValue = initialLocation?.get("longitude")
        val latValue = initialLocation?.get("latitude")
        val zoomValue = initialLocation?.get("zoom")

        if (longValue is Double && latValue is Double && zoomValue is Double?) {
          view.setInitialLocation(Point.fromLngLat(longValue, latValue), zoomValue)
        }
      }

      Prop("customRasterSourceUrl") { view: ExpoMapboxNavigationView, url: String? ->
        view.setCustomRasterSourceUrl(url)
      }

      Prop("placeCustomRasterLayerAbove") { view: ExpoMapboxNavigationView, layerId: String? ->
        view.setPlaceCustomRasterLayerAbove(layerId)
      }

      Prop("disableAlternativeRoutes") {
              view: ExpoMapboxNavigationView,
              disableAlternativeRoutes: Boolean? ->
        view.setDisableAlternativeRoutes(disableAlternativeRoutes)
      }

      Prop("followingZoom") { view: ExpoMapboxNavigationView, followingZoom: Double? ->
        view.setFollowingZoom(followingZoom)
      }

      Prop("markers") { view: ExpoMapboxNavigationView, markers: List<Map<String, Any>>? ->
        view.setMarkers(markers)
      }

      Prop("bottomLegend") { view: ExpoMapboxNavigationView, text: String? ->
        view.setBottomLegend(text)
      }

      Prop("showTripProgress") { view: ExpoMapboxNavigationView, show: Boolean? ->
        view.setShowTripProgress(show)
      }

      Prop("showCancelButton") { view: ExpoMapboxNavigationView, show: Boolean? ->
        view.setShowCancelButton(show)
      }

      AsyncFunction("recenterMap") { view: ExpoMapboxNavigationView -> view.recenterMap() }
    }
  }
}
