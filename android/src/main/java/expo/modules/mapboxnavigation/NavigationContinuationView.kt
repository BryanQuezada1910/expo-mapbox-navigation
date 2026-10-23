package expo.modules.mapboxnavigation

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.ImageView
import android.widget.TextView

internal class NavigationContinuationView(context: Context) : LinearLayout(context) {
    private val icon = ImageView(context).apply { setImageDrawable(NavigationContinuationIcon()) }
    private val label = TextView(context).apply {
        textSize = 20f
        setTextColor(Color.BLACK)
    }

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setBackgroundColor(Color.WHITE)
        val spacing = (16 * resources.displayMetrics.density).toInt()
        setPadding(spacing, spacing, spacing, spacing)
        minimumHeight = (80 * resources.displayMetrics.density).toInt()
        addView(icon, LayoutParams(spacing * 3, spacing * 3).apply { marginEnd = spacing })
        addView(label, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
    }

    fun render(roadName: String?) {
        label.text = plannedContinuationInstruction(roadName)
        icon.visibility = if (roadName.isNullOrBlank()) View.GONE else View.VISIBLE
    }
}
