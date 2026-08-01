package et.shagiz.tele_vault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class TeleVaultSyncWorkNamesTest {
    @Test
    fun productionAndReviewWorkNeverShareUniqueNames() {
        val production = "et.shagiz.tele_vault.production"
        val review = "et.shagiz.tele_vault.play_review"

        assertEquals(
            "et.shagiz.tele_vault.production.periodic_backup",
            TeleVaultSyncWorkNames.periodic(production),
        )
        assertEquals(
            "et.shagiz.tele_vault.play_review.immediate_backup",
            TeleVaultSyncWorkNames.immediate(review),
        )
        assertNotEquals(
            TeleVaultSyncWorkNames.periodic(production),
            TeleVaultSyncWorkNames.periodic(review),
        )
        assertNotEquals(
            TeleVaultSyncWorkNames.immediate(production),
            TeleVaultSyncWorkNames.immediate(review),
        )
    }
}
