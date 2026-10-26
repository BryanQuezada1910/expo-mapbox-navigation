package expo.modules.mapboxnavigation

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer

internal class NavigationAlertSound {
    private var player: MediaPlayer? = null

    fun play(context: Context, soundName: String) {
        val resourceName = soundName.substringBeforeLast('.').replace('-', '_')
        require(resourceName.matches(Regex("[a-z0-9_]+"))) { "Invalid alert sound name" }
        val resourceId = context.resources.getIdentifier(resourceName, "raw", context.packageName)
        require(resourceId != 0) { "Bundled alert sound not found" }
        stop()
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        val next = MediaPlayer.create(context, resourceId, attributes, 0)
            ?: error("Could not load alert sound")
        player = next
        next.setOnCompletionListener { if (player === it) player = null; it.release() }
        next.setOnErrorListener { media, _, _ -> if (player === media) player = null; media.release(); true }
        next.start()
    }

    fun stop() { player?.release(); player = null }
}
