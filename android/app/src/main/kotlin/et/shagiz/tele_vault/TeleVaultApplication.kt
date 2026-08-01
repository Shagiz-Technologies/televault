package et.shagiz.tele_vault

import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class TeleVaultApplication : FlutterApplication() {
    companion object {
        const val ENGINE_ID = "televault_main_engine"
    }

    override fun onCreate() {
        super.onCreate()

        val engine = FlutterEngine(this)
        BackgroundSyncChannel.register(this, engine.dartExecutor.binaryMessenger)
        engine.dartExecutor.executeDartEntrypoint(
            io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
                .createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }
}
