package expo.modules.mapboxnavigation

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
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
    private val statusLabel = TextView(context).apply {
        setTextColor(Color.BLACK)
        setBackgroundColor(Color.WHITE)
        textSize = 18f
        gravity = Gravity.CENTER_VERTICAL
        val padding = (16 * resources.displayMetrics.density).toInt()
        setPadding(padding, padding, padding, padding)
        minHeight = (64 * resources.displayMetrics.density).toInt()
        visibility = View.GONE
    }

    init {
        addView(maneuverView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        addView(statusLabel, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        showStatus("Preparando indicaciones")
    }

    fun showStatus(message: String) {
        maneuverView.visibility = View.GONE
        statusLabel.text = message
        statusLabel.visibility = View.VISIBLE
    }

    fun renderManeuvers(maneuvers: Expected<ManeuverError, List<Maneuver>>, planned: Boolean) {
        maneuvers.fold(
            { showStatus("Indicaciones no disponibles") },
            { values ->
                if (values.isEmpty()) showStatus("Indicaciones no disponibles")
                else {
                    statusLabel.visibility = View.GONE
                    maneuverView.visibility = View.VISIBLE
                    // The list may include the artificial destination of a planned window.
                    maneuverView.upcomingManeuverRenderingEnabled = !planned
                    maneuverView.renderManeuvers(maneuvers)
                }
            }
        )
    }
}
