package expo.modules.mapboxnavigation

import java.util.Locale

internal fun navigationLocale(identifier: String?, systemLocale: Locale = Locale.getDefault()): Locale {
    val value = identifier?.trim()
    if (value.isNullOrEmpty() || value.equals("default", ignoreCase = true)) return systemLocale
    val locale = Locale.forLanguageTag(value.replace('_', '-'))
    return if (locale.language.isEmpty()) Locale("es") else locale
}
