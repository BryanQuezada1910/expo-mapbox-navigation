package expo.modules.mapboxnavigation

import com.google.gson.JsonParser
import java.io.File

fun main(args: Array<String>) {
    val cases = JsonParser.parseString(File(args[0]).readText()).asJsonObject
    for (entry in cases.getAsJsonArray("guidance")) {
        val item = entry.asJsonObject
        val visible = canPresentNativeManeuver(
            item["planned"].asBoolean, item["enabled"].asBoolean, item["revisionMatches"].asBoolean,
            item.get("onRoute")?.takeUnless { it.isJsonNull }?.asBoolean,
            item["finalChunk"].asBoolean, item["instructionType"].takeUnless { it.isJsonNull }?.asString,
            item["hasInstruction"].asBoolean
        )
        check(visible == item["showNative"].asBoolean) { item["name"].asString }
        check(isArtificialArrival(item["finalChunk"].asBoolean, item["instructionType"].takeUnless { it.isJsonNull }?.asString) == item["artificialArrival"].asBoolean) { item["name"].asString }
    }
    for (entry in cases.getAsJsonArray("speedLimits")) {
        val item = entry.asJsonObject
        val presentation = SpeedLimitPresentation.from(
            item["speed"].takeUnless { it.isJsonNull }?.asDouble, item["unit"].asString, item["failed"].asBoolean
        )
        check(presentation.text == item["text"].asString && presentation.available == item["available"].asBoolean) { item["name"].asString }
        check(presentation.description.isNotBlank())
    }
    check(!SpeedLimitPresentation.from(Double.NaN, "km/h").available)
    check(!SpeedLimitPresentation.from(Double.POSITIVE_INFINITY, "km/h").available)
    check(plannedContinuationInstruction("MEX 190D", java.util.Locale("es")) == "Continúa por MEX 190D")
    check(plannedContinuationInstruction("   ", java.util.Locale("es")) == "Continúa por la ruta marcada")
    check(plannedContinuationInstruction("MEX 190D", java.util.Locale("en")) == "Continue on MEX 190D")
    check(plannedContinuationInstruction(null, java.util.Locale("en")) == "Continue along the marked route")
    check(shouldPresentPlannedBanner(planned = true, hasNativeManeuver = false, hasPlannedRoute = true))
    check(!shouldPresentPlannedBanner(planned = true, hasNativeManeuver = false, hasPlannedRoute = false))
    check(resolveEffectiveSpeedLimit(liveSpeed = null, routeAnnotatedSpeed = 80.0, lastValidSpeed = 60.0) == 80.0)
    check(resolveEffectiveSpeedLimit(liveSpeed = null, routeAnnotatedSpeed = null, lastValidSpeed = 80.0) == 80.0)
    check(resolveEffectiveSpeedLimit(liveSpeed = 90.0, routeAnnotatedSpeed = 80.0, lastValidSpeed = 60.0) == 90.0)
    println("25 navigation presentation cases and nonfinite speed values passed")
}
