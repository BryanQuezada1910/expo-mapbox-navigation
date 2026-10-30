package expo.modules.mapboxnavigation

import kotlin.math.roundToInt
import java.util.Locale

internal fun isArtificialArrival(finalChunk: Boolean, instructionType: String?): Boolean =
    !finalChunk && instructionType == "arrive"

internal fun canPresentNativeManeuver(
    planned: Boolean,
    enabled: Boolean,
    revisionMatches: Boolean,
    onRoute: Boolean?,
    finalChunk: Boolean,
    instructionType: String?,
    hasInstruction: Boolean
): Boolean = hasInstruction && (!planned || (
    enabled && revisionMatches && onRoute == true && !isArtificialArrival(finalChunk, instructionType)
))

internal fun plannedContinuationInstruction(roadName: String?, locale: Locale = Locale("es")): String =
    roadName?.trim()?.takeIf { it.isNotEmpty() }?.let { NavigationStrings(locale).continueOnRoad(it) }
        ?: NavigationStrings(locale).continueOnRoute

internal fun shouldPresentPlannedBanner(
    planned: Boolean,
    hasNativeManeuver: Boolean,
    hasPlannedRoute: Boolean
): Boolean = if (planned) (hasNativeManeuver || hasPlannedRoute) else hasNativeManeuver

internal fun resolveEffectiveSpeedLimit(
    liveSpeed: Double?,
    routeAnnotatedSpeed: Double?,
    lastValidSpeed: Double?,
    failed: Boolean = false
): Double? {
    if (failed) return null
    fun valid(value: Double?) = value?.takeIf { it.isFinite() && it > 0 && it < Int.MAX_VALUE }
    return valid(liveSpeed) ?: valid(routeAnnotatedSpeed) ?: valid(lastValidSpeed)
}

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
