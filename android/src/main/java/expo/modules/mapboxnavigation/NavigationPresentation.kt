package expo.modules.mapboxnavigation

import kotlin.math.roundToInt

internal fun plannedGuidanceMessage(
    status: String,
    enabled: Boolean,
    onRoute: Boolean? = null
): String? = when {
    onRoute == false || status == "off-route" -> "Fuera de la ruta planificada"
    onRoute == true -> null
    status == "unavailable" -> "Indicaciones no disponibles"
    !enabled -> "Preparando indicaciones"
    else -> null
}

internal fun isArtificialArrival(finalChunk: Boolean, instructionType: String?): Boolean =
    !finalChunk && instructionType == "arrive"

internal fun plannedContinuationInstruction(roadName: String?): String =
    roadName?.trim()?.takeIf { it.isNotEmpty() }?.let { "Continúa por $it" }
        ?: "Continúa por la ruta marcada"

internal data class SpeedLimitPresentation(val text: String, val description: String, val available: Boolean) {
    companion object {
        fun from(speed: Double?, unit: String, failed: Boolean = false): SpeedLimitPresentation = when {
            failed -> SpeedLimitPresentation("Error de\ndatos", "No se pudo obtener el límite de velocidad", false)
            speed != null && speed.isFinite() && speed > 0 -> {
                val value = speed.roundToInt()
                SpeedLimitPresentation("$value\n$unit", "Límite de velocidad: $value $unit", true)
            }
            else -> SpeedLimitPresentation("Sin\ndatos", "Límite de velocidad: sin datos para esta carretera", false)
        }
    }
}
