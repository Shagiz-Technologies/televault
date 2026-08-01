package et.shagiz.tele_vault

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class TeleVaultSyncService : Service() {
    companion object {
        const val ACTION_START = "et.shagiz.tele_vault.sync.START"
        const val ACTION_UPDATE = "et.shagiz.tele_vault.sync.UPDATE"
        const val ACTION_STOP = "et.shagiz.tele_vault.sync.STOP"

        private const val CHANNEL_ID = "televault_background_sync"
        private const val NOTIFICATION_ID = 1207
        private const val INITIAL_SYNC_WAKE_DELAY_MS = 2_500L
        private const val SYNC_WAKE_INTERVAL_MS = 30_000L

        @Volatile
        var isRunning = false
            private set
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var runtimeNamespace: String? = null
    private val syncWake = object : Runnable {
        override fun run() {
            runtimeNamespace?.let { namespace ->
                BackgroundSyncChannel.requestDartSync(namespace)
            }
            mainHandler.postDelayed(this, SYNC_WAKE_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        runtimeNamespace = RuntimeEnvironmentChannel.selectedMode(this)?.let {
            "et.shagiz.tele_vault.$it"
        }
        createNotificationChannel()
        mainHandler.postDelayed(syncWake, INITIAL_SYNC_WAKE_DELAY_MS)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra("namespace")
            ?.takeIf(String::isNotBlank)
            ?.let { runtimeNamespace = it }
        when (intent?.action) {
            ACTION_STOP -> {
                removeForegroundNotification()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> startForeground(
                NOTIFICATION_ID,
                buildNotification(intent),
            )
            ACTION_UPDATE -> {
                notificationManager().notify(
                    NOTIFICATION_ID,
                    buildNotification(intent),
                )
            }
            else -> startForeground(
                NOTIFICATION_ID,
                buildNotification(intent),
            )
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        runtimeNamespace = null
        mainHandler.removeCallbacks(syncWake)
        removeForegroundNotification()
        super.onDestroy()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        isRunning = false
        removeForegroundNotification()
        stopSelf(startId)
    }

    private fun buildNotification(intent: Intent?): Notification {
        val title = intent?.getStringExtra("title") ?: "TeleVault backup is active"
        val text = intent?.getStringExtra("text") ?: "Watching for new media"
        val detail = intent?.getStringExtra("detail") ?: text
        val progress = intent?.getIntExtra("progress", 0) ?: 0
        val progressMax = intent?.getIntExtra("progressMax", 1000) ?: 1000
        val total = intent?.getIntExtra("total", 0) ?: 0

        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        openAppIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_televault)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$text\n$detail"))
            .setContentIntent(contentIntent)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .apply {
                if (total > 0 && progress < progressMax) {
                    setProgress(progressMax, progress.coerceIn(0, progressMax), false)
                }
            }
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Background backup",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows TeleVault backup progress while auto-sync runs."
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun notificationManager(): NotificationManager {
        return getSystemService(NotificationManager::class.java)
    }

    @Suppress("DEPRECATION")
    private fun removeForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }
}
