package expo.modules.mapboxnavigation

import kotlin.math.roundToInt
import java.util.Locale

internal fun plannedGuidanceMessage(
    status: String,
    enabled: Boolean,
    onRoute: Boolean? = null,
    locale: Locale = Locale("es")
): String? = when {
    onRoute == false || status == "off-route" -> NavigationStrings(locale).offPlannedRoute
    onRoute == true -> null
    status == "unavailable" -> NavigationStrings(locale).instructionsUnavailable
    !enabled -> NavigationStrings(locale).preparingInstructions
    else -> null
}

internal fun isArtificialArrival(finalChunk: Boolean, instructionType: String?): Boolean =
    !finalChunk && instructionType == "arrive"

internal fun plannedContinuationInstruction(roadName: String?, locale: Locale = Locale("es")): String =
    roadName?.trim()?.takeIf { it.isNotEmpty() }?.let { NavigationStrings(locale).continueOnRoad(it) }
        ?: NavigationStrings(locale).continueOnRoute

internal data class SpeedLimitPresentation(val text: String, val description: String, val available: Boolean) {
    companion object {
        fun from(speed: Double?, unit: String, failed: Boolean = false, locale: Locale = Locale("es")): SpeedLimitPresentation = when {
            failed -> SpeedLimitPresentation(NavigationStrings(locale).speedDataError, NavigationStrings(locale).speedUnavailableDescription, false)
            speed != null && speed.isFinite() && speed > 0 -> {
                val value = speed.roundToInt()
                SpeedLimitPresentation("$value\n$unit", NavigationStrings(locale).speedLimitDescription(value.toString(), unit), true)
            }
            else -> SpeedLimitPresentation(NavigationStrings(locale).speedNoData, NavigationStrings(locale).speedNoDataDescription, false)
        }
    }
}
