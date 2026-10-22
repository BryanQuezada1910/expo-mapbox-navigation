package expo.modules.mapboxnavigation

import android.view.View
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.constraintlayout.widget.ConstraintSet

internal fun applyTripProgressVisibility(
    layout: ConstraintLayout,
    mapViewId: Int,
    tripProgressViewId: Int,
    cancelButtonId: Int,
    showTripProgress: Boolean,
    showCancelButton: Boolean
) {
    ConstraintSet().apply {
        clone(layout)
        setVisibility(tripProgressViewId, if (showTripProgress) View.VISIBLE else View.GONE)
        setVisibility(cancelButtonId, if (showTripProgress && showCancelButton) View.VISIBLE else View.GONE)
        // Reclaim the banner's space instead of leaving an empty strip below the map.
        connect(
            mapViewId, ConstraintSet.BOTTOM,
            if (showTripProgress) tripProgressViewId else ConstraintSet.PARENT_ID,
            if (showTripProgress) ConstraintSet.TOP else ConstraintSet.BOTTOM
        )
        applyTo(layout)
    }
}
