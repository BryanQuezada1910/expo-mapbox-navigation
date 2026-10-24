package expo.modules.mapboxnavigation

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.TextView

internal class SpeedLimitIndicatorView(context: Context) : FrameLayout(context) {
    private val border = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(Color.WHITE)
    }
    private val label = TextView(context).apply {
        setTextColor(Color.BLACK)
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        gravity = Gravity.CENTER
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        includeFontPadding = false
    }

    init {
        background = border
        addView(label, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        render(SpeedLimitPresentation.from(null, "km/h", locale = java.util.Locale.getDefault()))
    }

    fun render(presentation: SpeedLimitPresentation) {
        label.text = presentation.text
        label.textSize = if (presentation.available) 16f else 14f
        contentDescription = presentation.description
        border.setStroke((3 * resources.displayMetrics.density).toInt(), if (presentation.available) Color.RED else Color.DKGRAY)
    }
}
