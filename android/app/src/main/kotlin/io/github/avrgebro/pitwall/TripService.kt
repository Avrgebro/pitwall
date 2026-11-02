package io.github.avrgebro.pitwall

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import android.os.PowerManager

/**
 * Keeps Pitwall running during a trip, with the notification Android
 * requires. The trip itself runs in Dart, in the shared engine, and
 * decides when it's over; this service starts it and keeps the CPU awake
 * for it.
 */
class TripService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Every start must reach the foreground, even one that's ignored.
        startForeground(
            NOTIFICATION_ID,
            notification(this, getString(R.string.trip_starting)),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
        )
        // One trip at a time: a head unit connecting mid-trip, say after
        // the stereo was handed to someone else and back, changes nothing.
        if (!tripActive) {
            tripActive = true
            acquireWakeLock()
            EngineHolder.get(this)
            ServiceBridge.requestTripStart(intent?.getStringExtra(EXTRA_HEAD_UNIT))
        }
        // Without a trip request there's nothing to resume after a restart.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        tripActive = false
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(PowerManager::class.java)
        // Readings are timed in Dart; the CPU must stay awake with the
        // screen off. Released when the trip ends, or after a long cap.
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "pitwall:trip").apply {
            acquire(MAX_TRIP_MS)
        }
    }

    companion object {
        const val ACTION_START = "io.github.avrgebro.pitwall.TRIP_START"
        private const val EXTRA_HEAD_UNIT = "head_unit"
        private const val CHANNEL_ID = "trip"
        private const val NOTIFICATION_ID = 1
        private const val MAX_TRIP_MS = 12 * 60 * 60 * 1000L

        // Whether a trip runs: set when the service starts one, cleared when
        // Android destroys the service, so it can't outlive the service.
        @Volatile
        private var tripActive = false

        /** Starts a trip; [headUnit] is the car's head unit that connected, or null from the app. */
        fun start(context: Context, headUnit: String? = null) {
            context.startForegroundService(
                Intent(context, TripService::class.java)
                    .setAction(ACTION_START)
                    .putExtra(EXTRA_HEAD_UNIT, headUnit),
            )
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TripService::class.java))
        }

        fun updateNotification(context: Context, text: String) {
            if (!tripActive) return
            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, notification(context, text))
        }

        private fun notification(context: Context, text: String): Notification {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    context.getString(R.string.trip_channel),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { description = context.getString(R.string.trip_channel_description) },
            )
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            return Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_pitwall)
                .setContentTitle(context.getString(R.string.app_name))
                .setContentText(text)
                .setContentIntent(open)
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_SERVICE)
                .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
                .build()
        }
    }
}
