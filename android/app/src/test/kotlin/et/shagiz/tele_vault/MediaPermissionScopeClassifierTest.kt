package et.shagiz.tele_vault

import org.junit.Assert.assertEquals
import org.junit.Test

class MediaPermissionScopeClassifierTest {
    @Test
    fun `Android 13 full access requires each requested media type`() {
        assertEquals(
            MediaPermissionScope.FULL_ACCESS,
            classify(sdk = 33, images = true, videos = true),
        )
        assertEquals(
            MediaPermissionScope.LIMITED_ACCESS,
            classify(sdk = 33, images = true, videos = false),
        )
    }

    @Test
    fun `Android 14 selected access is limited`() {
        assertEquals(
            MediaPermissionScope.LIMITED_ACCESS,
            classify(sdk = 34, selected = true),
        )
    }

    @Test
    fun `Android 14 full access is complete`() {
        assertEquals(
            MediaPermissionScope.FULL_ACCESS,
            classify(sdk = 34, images = true, videos = true),
        )
    }

    @Test
    fun `denial state distinguishes first use retry and permanent denial`() {
        assertEquals(
            MediaPermissionScope.NOT_DETERMINED,
            classify(sdk = 34, attempted = false),
        )
        assertEquals(
            MediaPermissionScope.DENIED,
            classify(sdk = 34, rationale = true),
        )
        assertEquals(
            MediaPermissionScope.PERMANENTLY_DENIED,
            classify(sdk = 34),
        )
    }

    @Test
    fun `image-only request can be fully granted without video permission`() {
        assertEquals(
            MediaPermissionScope.FULL_ACCESS,
            classify(
                sdk = 34,
                includeVideos = false,
                images = true,
                videos = false,
            ),
        )
    }

    private fun classify(
        sdk: Int,
        includeImages: Boolean = true,
        includeVideos: Boolean = true,
        images: Boolean = false,
        videos: Boolean = false,
        selected: Boolean = false,
        attempted: Boolean = true,
        rationale: Boolean = false,
    ): MediaPermissionScope = MediaPermissionScopeClassifier.classify(
        MediaPermissionSnapshot(
            sdkInt = sdk,
            includeImages = includeImages,
            includeVideos = includeVideos,
            imagesGranted = images,
            videosGranted = videos,
            selectedGranted = selected,
            requestAttempted = attempted,
            shouldShowRationale = rationale,
        ),
    )
}
