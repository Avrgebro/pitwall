package io.github.avrgebro.pitwall

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

/**
 * Keeps Pitwall running during a trip, with the notification Android
 * requires. The trip itself runs in Dart, in the shared engine; this
 * service starts it, keeps the CPU awake for it, and asks it to end.
 */
class TripService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private val main = Handler(Looper.getMainLooper())

    // If Dart doesn't finish within this after being asked to stop (it
    // sends a last reading first), the service stops anyway.
    private val forceStop = Runnable { stopSelf() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                ServiceBridge.requestTripStop()
                main.postDelayed(forceStop, STOP_GRACE_MS)
            }
            else -> {
                main.removeCallbacks(forceStop)
                startForeground(
                    NOTIFICATION_ID,
                    notification(this, getString(R.string.trip_starting)),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
                )
                acquireWakeLock()
                EngineHolder.get(this)
                ServiceBridge.requestTripStart()
            }
        }
        // Without a trip request there's nothing to resume after a restart.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        main.removeCallbacks(forceStop)
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
        const val ACTION_STOP = "io.github.avrgebro.pitwall.TRIP_STOP"
        private const val CHANNEL_ID = "trip"
        private const val NOTIFICATION_ID = 1
        private const val STOP_GRACE_MS = 30_000L
        private const val MAX_TRIP_MS = 12 * 60 * 60 * 1000L

        @Volatile
        var isRunning = false
            private set

        fun start(context: Context) {
            isRunning = true
            context.startForegroundService(
                Intent(context, TripService::class.java).setAction(ACTION_START),
            )
        }

        /** Asks the running trip to end; it stops the service when done. */
        fun requestStop(context: Context) {
            if (!isRunning) return
            context.startService(Intent(context, TripService::class.java).setAction(ACTION_STOP))
        }

        fun stop(context: Context) {
            isRunning = false
            context.stopService(Intent(context, TripService::class.java))
        }

        fun updateNotification(context: Context, text: String) {
            if (!isRunning) return
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
