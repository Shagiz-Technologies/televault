package et.shagiz.tele_vault

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal enum class MediaPermissionScope(val wireName: String) {
    FULL_ACCESS("fullAccess"),
    LIMITED_ACCESS("limitedAccess"),
    DENIED("denied"),
    PERMANENTLY_DENIED("permanentlyDenied"),
    NOT_DETERMINED("notDetermined"),
    UNSUPPORTED("unsupported"),
}

internal enum class MediaTypePermission(val wireName: String) {
    FULL("full"),
    SELECTED("selected"),
    DENIED("denied"),
    NOT_REQUESTED("notRequested"),
}

internal data class MediaPermissionSnapshot(
    val sdkInt: Int,
    val includeImages: Boolean,
    val includeVideos: Boolean,
    val imagesGranted: Boolean,
    val videosGranted: Boolean,
    val selectedGranted: Boolean,
    val requestAttempted: Boolean,
    val shouldShowRationale: Boolean,
)

internal object MediaPermissionScopeClassifier {
    fun classify(snapshot: MediaPermissionSnapshot): MediaPermissionScope {
        if (snapshot.sdkInt < Build.VERSION_CODES.M) {
            return MediaPermissionScope.UNSUPPORTED
        }

        val required = buildList {
            if (snapshot.includeImages) add(snapshot.imagesGranted)
            if (snapshot.includeVideos) add(snapshot.videosGranted)
        }
        if (required.isEmpty() || required.all { it }) {
            return MediaPermissionScope.FULL_ACCESS
        }
        if (snapshot.selectedGranted || required.any { it }) {
            return MediaPermissionScope.LIMITED_ACCESS
        }
        if (!snapshot.requestAttempted) {
            return MediaPermissionScope.NOT_DETERMINED
        }
        return if (snapshot.shouldShowRationale) {
            MediaPermissionScope.DENIED
        } else {
            MediaPermissionScope.PERMANENTLY_DENIED
        }
    }
}

internal class MediaPermissionChannel(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val channelName = "et.shagiz.tele_vault/media_permissions"
        private const val requestCode = 4816
        private const val preferencesName = "televault_media_permissions"
        private const val requestedImagesKey = "requested_images"
        private const val requestedVideosKey = "requested_videos"
        private const val requestedLegacyKey = "requested_legacy"
    }

    private val channel = MethodChannel(messenger, channelName)
    private val preferences = activity.getSharedPreferences(
        preferencesName,
        Context.MODE_PRIVATE,
    )
    private var pendingResult: MethodChannel.Result? = null
    private var pendingImages = true
    private var pendingVideos = true

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val includeImages = call.argument<Boolean>("includeImages") ?: true
        val includeVideos = call.argument<Boolean>("includeVideos") ?: true
        when (call.method) {
            "getStatus" -> result.success(statusMap(includeImages, includeVideos))
            "requestAccess" -> requestAccess(includeImages, includeVideos, result)
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(code: Int): Boolean {
        if (code != requestCode) return false
        val result = pendingResult ?: return false
        pendingResult = null
        result.success(statusMap(pendingImages, pendingVideos))
        return true
    }

    private fun requestAccess(
        includeImages: Boolean,
        includeVideos: Boolean,
        result: MethodChannel.Result,
    ) {
        if (pendingResult != null) {
            result.error("request_in_progress", "A media permission request is already active.", null)
            return
        }
        val permissions = requestedPermissions(includeImages, includeVideos)
        if (permissions.isEmpty()) {
            result.success(statusMap(includeImages, includeVideos))
            return
        }

        markRequested(includeImages, includeVideos)
        pendingImages = includeImages
        pendingVideos = includeVideos
        pendingResult = result
        activity.requestPermissions(permissions.toTypedArray(), requestCode)
    }

    private fun requestedPermissions(
        includeImages: Boolean,
        includeVideos: Boolean,
    ): List<String> = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> buildList {
            if (includeImages) add(Manifest.permission.READ_MEDIA_IMAGES)
            if (includeVideos) add(Manifest.permission.READ_MEDIA_VIDEO)
            if (includeImages || includeVideos) {
                add(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
            }
        }
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> buildList {
            if (includeImages) add(Manifest.permission.READ_MEDIA_IMAGES)
            if (includeVideos) add(Manifest.permission.READ_MEDIA_VIDEO)
        }
        else -> listOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    private fun markRequested(includeImages: Boolean, includeVideos: Boolean) {
        preferences.edit().apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (includeImages) putBoolean(requestedImagesKey, true)
                if (includeVideos) putBoolean(requestedVideosKey, true)
            } else {
                putBoolean(requestedLegacyKey, true)
            }
        }.apply()
    }

    private fun statusMap(
        includeImages: Boolean,
        includeVideos: Boolean,
    ): Map<String, Any> {
        val sdk = Build.VERSION.SDK_INT
        val legacyGranted = sdk < Build.VERSION_CODES.TIRAMISU &&
            isGranted(Manifest.permission.READ_EXTERNAL_STORAGE)
        val imagesGranted = if (sdk >= Build.VERSION_CODES.TIRAMISU) {
            isGranted(Manifest.permission.READ_MEDIA_IMAGES)
        } else {
            legacyGranted
        }
        val videosGranted = if (sdk >= Build.VERSION_CODES.TIRAMISU) {
            isGranted(Manifest.permission.READ_MEDIA_VIDEO)
        } else {
            legacyGranted
        }
        val selectedGranted = sdk >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            isGranted(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
        val requestAttempted = when {
            sdk >= Build.VERSION_CODES.TIRAMISU ->
                (!includeImages || preferences.getBoolean(requestedImagesKey, false)) &&
                    (!includeVideos || preferences.getBoolean(requestedVideosKey, false))
            else -> preferences.getBoolean(requestedLegacyKey, false)
        }
        val rationale = when {
            sdk >= Build.VERSION_CODES.TIRAMISU ->
                (includeImages && !imagesGranted &&
                    activity.shouldShowRequestPermissionRationale(
                        Manifest.permission.READ_MEDIA_IMAGES,
                    )) ||
                    (includeVideos && !videosGranted &&
                        activity.shouldShowRequestPermissionRationale(
                            Manifest.permission.READ_MEDIA_VIDEO,
                        ))
            else -> !legacyGranted && activity.shouldShowRequestPermissionRationale(
                Manifest.permission.READ_EXTERNAL_STORAGE,
            )
        }
        val snapshot = MediaPermissionSnapshot(
            sdkInt = sdk,
            includeImages = includeImages,
            includeVideos = includeVideos,
            imagesGranted = imagesGranted,
            videosGranted = videosGranted,
            selectedGranted = selectedGranted,
            requestAttempted = requestAttempted,
            shouldShowRationale = rationale,
        )
        val scope = MediaPermissionScopeClassifier.classify(snapshot)
        val missingRequestedAccess =
            (includeImages && !imagesGranted) || (includeVideos && !videosGranted)
        val canRequestAgain =
            selectedGranted || !requestAttempted || rationale || !missingRequestedAccess
        return mapOf(
            "androidSdkInt" to sdk,
            "scope" to scope.wireName,
            "imageAccess" to mediaTypePermission(
                requested = includeImages,
                fullyGranted = imagesGranted,
                selectedGranted = selectedGranted,
            ).wireName,
            "videoAccess" to mediaTypePermission(
                requested = includeVideos,
                fullyGranted = videosGranted,
                selectedGranted = selectedGranted,
            ).wireName,
            "supportsSelectedAccess" to
                (sdk >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE),
            "canRequestAgain" to canRequestAgain,
        )
    }

    private fun mediaTypePermission(
        requested: Boolean,
        fullyGranted: Boolean,
        selectedGranted: Boolean,
    ): MediaTypePermission = when {
        !requested -> MediaTypePermission.NOT_REQUESTED
        fullyGranted -> MediaTypePermission.FULL
        selectedGranted -> MediaTypePermission.SELECTED
        else -> MediaTypePermission.DENIED
    }

    private fun isGranted(permission: String): Boolean =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
}
