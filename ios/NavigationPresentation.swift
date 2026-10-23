import Foundation

func plannedGuidanceMessage(status: String, enabled: Bool, finalChunk: Bool, instructionType: String?) -> String? {
    if status == "unavailable" { return "Indicaciones no disponibles" }
    if status == "off-route" { return "Fuera de la ruta planificada" }
    if !enabled { return "Preparando indicaciones" }
    if !finalChunk && instructionType == "arrive" { return "Continuando ruta planificada" }
    return nil
}

struct SpeedLimitPresentation {
    let text: String
    let description: String
    let available: Bool

    static func from(speed: Double?, unit: String, failed: Bool = false) -> SpeedLimitPresentation {
        if failed {
            return .init(text: "Error de\ndatos", description: "No se pudo obtener el límite de velocidad", available: false)
        }
        if let speed = speed, speed.isFinite, speed > 0, speed < Double(Int.max) {
            let value = Int(speed.rounded())
            return .init(text: "\(value)\n\(unit)", description: "Límite de velocidad: \(value) \(unit)", available: true)
        }
        return .init(text: "Sin\ndatos", description: "Límite de velocidad: sin datos para esta carretera", available: false)
    }
}
