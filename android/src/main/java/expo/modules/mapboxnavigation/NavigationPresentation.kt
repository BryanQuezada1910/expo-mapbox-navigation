package expo.modules.mapboxnavigation

import kotlin.math.roundToInt

internal fun plannedGuidanceMessage(
    status: String,
    enabled: Boolean,
    finalChunk: Boolean,
    instructionType: String?
): String? = when {
    status == "unavailable" -> "Indicaciones no disponibles"
    status == "off-route" -> "Fuera de la ruta planificada"
    !enabled -> "Preparando indicaciones"
    !finalChunk && instructionType == "arrive" -> "Continuando ruta planificada"
    else -> null
}

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
