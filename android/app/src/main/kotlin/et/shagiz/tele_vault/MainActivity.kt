package et.shagiz.tele_vault

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    private lateinit var mediaPermissionChannel: MediaPermissionChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaPermissionChannel = MediaPermissionChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::mediaPermissionChannel.isInitialized) {
            mediaPermissionChannel.onRequestPermissionsResult(requestCode)
        }
    }
}
