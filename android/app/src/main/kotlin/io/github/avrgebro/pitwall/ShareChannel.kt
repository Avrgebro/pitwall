package io.github.avrgebro.pitwall

import android.app.Activity
import android.content.Intent

/** Android's share sheet, for Dart's [ShareApi], from the screen showing. */
class ShareChannel(private val activity: Activity) : ShareApi {
    override fun shareText(subject: String, text: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, text)
        }
        activity.startActivity(Intent.createChooser(send, subject))
    }
}
