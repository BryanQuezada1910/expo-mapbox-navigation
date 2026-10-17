package expo.modules.mapboxnavigation

import com.google.gson.JsonParser
import com.mapbox.geojson.Point
import java.io.File
import kotlin.math.*

fun main(args: Array<String>) {
    val path = args.firstOrNull() ?: "tests/plannedRouteGeometryCases.json"
    val fixtures = JsonParser.parseString(File(path).readText()).asJsonArray
    var count = 0
    for (fixture in fixtures) {
        val item = fixture.asJsonObject
        fun points(key: String): List<Point> = item[key].asJsonArray.map {
            val xy = it.asJsonArray
            Point.fromLngLat(-99 + xy[0].asDouble / (cos(19 * PI / 180) * 111195.08), 19 + xy[1].asDouble / 111195.08)
        }
        val result = PlannedRouteGeometry.validate(points("original"), points("matched"), item["tolerance"].asDouble)
        check(result.matches == item["expected"].asBoolean) { item["name"].asString + ": " + result }
        if (item.has("reason")) check(result.reason == item["reason"].asString) { item["name"].asString + ": " + result.reason }
        count++
    }
    println("$count Android geometry regression checks passed")
}
