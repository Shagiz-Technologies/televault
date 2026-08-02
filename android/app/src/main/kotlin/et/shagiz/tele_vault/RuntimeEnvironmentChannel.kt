package et.shagiz.tele_vault

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object RuntimeEnvironmentChannel : MethodChannel.MethodCallHandler {
    private const val CHANNEL_NAME = "et.shagiz.tele_vault/runtime_environment"
    private const val PREFERENCES_NAME = "televault_runtime_environment"
    private const val SELECTED_MODE_KEY = "selected_mode"
    private val allowedModes = setOf("production", "reviewer_demo")

    private lateinit var applicationContext: Context

    fun register(context: Context, messenger: BinaryMessenger) {
        applicationContext = context.applicationContext
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(this)
    }

    fun selectedMode(context: Context): String? = normalizeMode(
        context
            .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .getString(SELECTED_MODE_KEY, null),
    )

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val preferences = applicationContext.getSharedPreferences(
            PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
        when (call.method) {
            "getSelectedMode" -> result.success(
                normalizeMode(preferences.getString(SELECTED_MODE_KEY, null)),
            )
            "setSelectedMode" -> {
                val mode = call.arguments as? String
                if (mode !in allowedModes) {
                    result.error("invalid_mode", "Unknown runtime environment.", null)
                    return
                }
                val saved = preferences.edit().putString(SELECTED_MODE_KEY, mode).commit()
                if (saved) {
                    result.success(null)
                } else {
                    result.error("write_failed", "Runtime environment was not saved.", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun normalizeMode(value: String?): String? = when (value) {
        // Migrate the retired Test DC runtime without initializing Telegram.
        "play_review" -> "reviewer_demo"
        else -> value
    }
}
