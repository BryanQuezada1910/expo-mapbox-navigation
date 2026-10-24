package expo.modules.mapboxnavigation

import com.google.gson.JsonParser
import java.io.File

fun main(args: Array<String>) {
    val fixtures = JsonParser.parseString(File(args[0]).readText()).asJsonArray
    val catalog = JsonParser.parseString(File(args[1]).readText()).asJsonObject
    for (entry in fixtures) {
        val item = entry.asJsonObject
        val locale = navigationLocale(item["locale"].takeUnless { it.isJsonNull }?.asString, navigationLocale(item["systemLocale"].asString))
        val expected = catalog[item["language"].asString].asJsonObject
        val strings = NavigationStrings(locale)
        check(plannedGuidanceMessage("preparing", false, locale = locale) == expected["preparingInstructions"].asString)
        check(plannedGuidanceMessage("off-route", false, false, locale) == expected["offPlannedRoute"].asString)
        check(plannedContinuationInstruction("N Interstate 35", locale) == expected["continueOnRoad"].asString.replace("{roadName}", "N Interstate 35"))
        check(plannedContinuationInstruction(null, locale) == expected["continueOnRoute"].asString)
        check(SpeedLimitPresentation.from(null, "mph", locale = locale).text == expected["speedNoData"].asString)
        check(SpeedLimitPresentation.from(null, "mph", true, locale).text == expected["speedDataError"].asString)
        check(SpeedLimitPresentation.from(70.0, "mph", locale = locale).description == expected["speedLimitDescription"].asString.replace("{speed}", "70").replace("{unit}", "mph"))
        check(strings.overviewRoute == expected["overviewRoute"].asString)
        check(strings.followLocation == expected["followLocation"].asString)
        check(strings.muteVoice == expected["muteVoice"].asString)
        check(strings.unmuteVoice == expected["unmuteVoice"].asString)
        check(strings.cancelNavigation == expected["cancelNavigation"].asString)
        check(strings.defaultMarkerLetter == expected["defaultMarkerLetter"].asString)
        check(strings.invalidRouteGeometry == expected["invalidRouteGeometry"].asString)
    }
    println("12 Kotlin locale variants and localized navigation states passed")
}
