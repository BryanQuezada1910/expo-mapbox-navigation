package expo.modules.mapboxnavigation

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.mapbox.bindgen.Expected
import com.mapbox.navigation.tripdata.maneuver.model.Maneuver
import com.mapbox.navigation.tripdata.maneuver.model.ManeuverError
import com.mapbox.navigation.ui.components.maneuver.model.ManeuverPrimaryOptions
import com.mapbox.navigation.ui.components.maneuver.model.ManeuverViewOptions
import com.mapbox.navigation.ui.components.maneuver.view.MapboxManeuverView

internal class NavigationGuidanceView(context: Context) : FrameLayout(context) {
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

    fun hide() {
        visibility = View.GONE
    }

    fun renderManeuvers(maneuvers: Expected<ManeuverError, List<Maneuver>>, planned: Boolean) {
        maneuvers.fold(
            { hide() },
            { values ->
                if (values.isEmpty()) {
                    hide()
                }
                else {
                    // The list may include the artificial destination of a planned window.
                    maneuverView.upcomingManeuverRenderingEnabled = !planned
                    maneuverView.renderManeuvers(maneuvers)
                    visibility = View.VISIBLE
                }
            }
        )
    }
}
