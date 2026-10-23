import Foundation

func plannedGuidanceMessage(status: String, enabled: Bool, onRoute: Bool? = nil) -> String? {
    if onRoute == false || status == "off-route" { return "Fuera de la ruta planificada" }
    if onRoute == true { return nil }
    if status == "unavailable" { return "Indicaciones no disponibles" }
    if !enabled { return "Preparando indicaciones" }
    return nil
}

func isArtificialArrival(finalChunk: Bool, instructionType: String?) -> Bool {
    !finalChunk && instructionType == "arrive"
}

func plannedContinuationInstruction(roadName: String?) -> String {
    guard let name = roadName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
        return "Continúa por la ruta marcada"
    }
    return "Continúa por \(name)"
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
