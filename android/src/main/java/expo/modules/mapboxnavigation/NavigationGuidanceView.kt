package expo.modules.mapboxnavigation

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.mapbox.api.directions.v5.models.BannerComponents
import com.mapbox.api.directions.v5.models.ManeuverModifier
import com.mapbox.api.directions.v5.models.StepManeuver
import com.mapbox.bindgen.Expected
import com.mapbox.bindgen.ExpectedFactory
import com.mapbox.geojson.Point
import com.mapbox.navigation.base.ExperimentalMapboxNavigationAPI
import com.mapbox.navigation.base.formatter.DistanceFormatterOptions
import com.mapbox.navigation.core.formatter.MapboxDistanceFormatter
import com.mapbox.navigation.tripdata.maneuver.model.Component
import com.mapbox.navigation.tripdata.maneuver.model.Maneuver
import com.mapbox.navigation.tripdata.maneuver.model.ManeuverError
import com.mapbox.navigation.tripdata.maneuver.model.ManeuverFactory
import com.mapbox.navigation.tripdata.maneuver.model.PrimaryManeuverFactory
import com.mapbox.navigation.tripdata.maneuver.model.StepDistanceFactory
import com.mapbox.navigation.tripdata.maneuver.model.TextComponentNode
import com.mapbox.navigation.ui.components.maneuver.model.ManeuverPrimaryOptions
import com.mapbox.navigation.ui.components.maneuver.model.ManeuverViewOptions
import com.mapbox.navigation.ui.components.maneuver.view.MapboxManeuverView

@OptIn(ExperimentalMapboxNavigationAPI::class)
internal class NavigationGuidanceView(context: Context) : FrameLayout(context) {
    private var lastValidManeuvers: List<Maneuver>? = null
    private val maneuverView = MapboxManeuverView(context).apply {
        updateManeuverViewOptions(
            ManeuverViewOptions.Builder().primaryManeuverOptions(
                ManeuverPrimaryOptions.Builder().textAppearance(R.style.ManeuverTextAppearance).build()
            ).build()
        )
    }
    init {
        addView(maneuverView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        hide()
    }

    fun resetCache() {
        lastValidManeuvers = null
    }

    fun hide() {
        visibility = View.GONE
    }

    fun renderCachedIfAvailable(planned: Boolean): Boolean {
        val cached = lastValidManeuvers?.takeIf { it.isNotEmpty() } ?: return false
        maneuverView.upcomingManeuverRenderingEnabled = !planned || cached.size > 1
        maneuverView.renderManeuvers(ExpectedFactory.createValue(cached))
        visibility = View.VISIBLE
        return true
    }

    fun renderContinuation(
        continuationText: String,
        distanceFormatterOptions: DistanceFormatterOptions,
        distanceRemaining: Double?,
        anchorPoint: Point? = null
    ) {
        val primary = PrimaryManeuverFactory.buildPrimaryManeuver(
            "planned-continue",
            continuationText,
            StepManeuver.CONTINUE,
            null,
            ManeuverModifier.STRAIGHT,
            "right",
            listOf(
                Component(
                    BannerComponents.TEXT,
                    TextComponentNode.Builder().text(continuationText).build()
                )
            )
        )
        val remaining = distanceRemaining?.takeIf { it.isFinite() && it > 5.0 }
        val total = remaining ?: 0.0
        val stepDistance = StepDistanceFactory.buildStepDistance(
            MapboxDistanceFormatter(distanceFormatterOptions),
            total,
            remaining
        )
        val point = anchorPoint ?: Point.fromLngLat(0.0, 0.0)
        val maneuver = ManeuverFactory.buildManeuver(primary, stepDistance, null, null, null, point)
        maneuverView.upcomingManeuverRenderingEnabled = false
        maneuverView.renderManeuvers(ExpectedFactory.createValue(listOf(maneuver)))
        visibility = View.VISIBLE
    }

    fun renderManeuvers(
        maneuvers: Expected<ManeuverError, List<Maneuver>>,
        plannedMode: Boolean,
        finalChunk: Boolean = true,
        continuationText: String = "",
        distanceFormatterOptions: DistanceFormatterOptions? = null,
        distanceRemaining: Double? = null,
        anchorPoint: Point? = null
    ) {
        maneuvers.fold(
            {
                if (plannedMode && distanceFormatterOptions != null && continuationText.isNotBlank()) {
                    renderContinuation(continuationText, distanceFormatterOptions, distanceRemaining, anchorPoint)
                } else {
                    hide()
                }
            },
            { values ->
                val filtered = if (!plannedMode || finalChunk) {
                    values
                } else {
                    values
                        .filterNot { isArtificialArrival(false, it.primary.type) }
                        .map { item ->
                            if (isArtificialArrival(false, item.sub?.type)) {
                                ManeuverFactory.buildManeuver(
                                    item.primary,
                                    item.stepDistance,
                                    item.secondary,
                                    null,
                                    item.laneGuidance,
                                    item.maneuverPoint
                                )
                            } else {
                                item
                            }
                        }
                }
                if (filtered.isEmpty()) {
                    if (plannedMode && distanceFormatterOptions != null && continuationText.isNotBlank()) {
                        val fallbackRemaining = distanceRemaining ?: values.firstOrNull()?.stepDistance?.distanceRemaining
                        val fallbackPoint = anchorPoint ?: values.firstOrNull()?.maneuverPoint
                        renderContinuation(continuationText, distanceFormatterOptions, fallbackRemaining, fallbackPoint)
                    } else {
                        hide()
                    }
                } else {
                    lastValidManeuvers = filtered
                    maneuverView.upcomingManeuverRenderingEnabled = !plannedMode || filtered.size > 1
                    maneuverView.renderManeuvers(ExpectedFactory.createValue(filtered))
                    visibility = View.VISIBLE
                }
            }
        )
    }
}
