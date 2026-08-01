package et.shagiz.tele_vault

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    private lateinit var mediaPermissionChannel: MediaPermissionChannel

    override fun getCachedEngineId(): String = TeleVaultApplication.ENGINE_ID

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaPermissionChannel = MediaPermissionChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onStart() {
        super.onStart()
        BackgroundSyncChannel.attachActivity(this)
    }

    override fun onStop() {
        BackgroundSyncChannel.detachActivity(this)
        super.onStop()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (BackgroundSyncChannel.onRequestPermissionsResult(requestCode, grantResults)) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::mediaPermissionChannel.isInitialized) {
            mediaPermissionChannel.onRequestPermissionsResult(requestCode)
        }
    }
}
