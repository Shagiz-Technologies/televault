package et.shagiz.tele_vault

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object BackgroundSyncChannel : MethodChannel.MethodCallHandler {
    private const val CHANNEL_NAME = "et.shagiz.tele_vault/background_sync"
    private const val NOTIFICATION_PERMISSION_REQUEST = 7301

    private lateinit var applicationContext: Context
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var requestPermissionWhenAttached = false
    private var permissionRequestInFlight = false

    fun register(context: Context, messenger: BinaryMessenger) {
        applicationContext = context.applicationContext
        channel = MethodChannel(messenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    fun requestDartSync() {
        Handler(Looper.getMainLooper()).post {
            channel?.invokeMethod("wakeSync", null)
        }
    }

    fun attachActivity(value: Activity) {
        activity = value
        if (requestPermissionWhenAttached) {
            requestPermissionWhenAttached = false
            requestNotificationPermission(null)
        }
    }

    fun detachActivity(value: Activity) {
        if (activity === value) {
            activity = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "start" -> {
                startService(TeleVaultSyncService.ACTION_START, call.arguments)
                result.success(null)
            }
            "update" -> {
                startService(TeleVaultSyncService.ACTION_UPDATE, call.arguments)
                result.success(null)
            }
            "isRunning" -> result.success(TeleVaultSyncService.isRunning)
            "stop" -> {
                applicationContext.stopService(
                    Intent(applicationContext, TeleVaultSyncService::class.java),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result?.success(true)
            return
        }
        if (
            applicationContext.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result?.success(true)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            requestPermissionWhenAttached = true
            result?.success(false)
            return
        }
        if (permissionRequestInFlight) {
            result?.error(
                "permission_in_progress",
                "Notification permission is already being requested.",
                null,
            )
            return
        }

        pendingPermissionResult = result
        permissionRequestInFlight = true
        currentActivity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return false

        val granted =
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        permissionRequestInFlight = false
        return true
    }

    private fun startService(action: String, rawArguments: Any?) {
        val intent = Intent(applicationContext, TeleVaultSyncService::class.java)
            .setAction(action)
        @Suppress("UNCHECKED_CAST")
        val arguments = rawArguments as? Map<String, Any?>
        arguments?.forEach { (key, value) ->
            when (value) {
                is Int -> intent.putExtra(key, value)
                is Long -> intent.putExtra(key, value)
                is Double -> intent.putExtra(key, value)
                is Boolean -> intent.putExtra(key, value)
                is String -> intent.putExtra(key, value)
            }
        }

        if (
            action == TeleVaultSyncService.ACTION_START &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        ) {
            applicationContext.startForegroundService(intent)
        } else {
            applicationContext.startService(intent)
        }
    }
}
