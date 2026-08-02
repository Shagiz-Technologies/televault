package et.shagiz.tele_vault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class TeleVaultSyncWorkNamesTest {
    @Test
    fun productionAndReviewerDemoWorkNeverShareUniqueNames() {
        val production = "et.shagiz.tele_vault.production"
        val demo = "et.shagiz.tele_vault.reviewer_demo"

        assertEquals(
            "et.shagiz.tele_vault.production.periodic_backup",
            TeleVaultSyncWorkNames.periodic(production),
        )
        assertEquals(
            "et.shagiz.tele_vault.reviewer_demo.immediate_backup",
            TeleVaultSyncWorkNames.immediate(demo),
        )
        assertNotEquals(
            TeleVaultSyncWorkNames.periodic(production),
            TeleVaultSyncWorkNames.periodic(demo),
        )
        assertNotEquals(
            TeleVaultSyncWorkNames.immediate(production),
            TeleVaultSyncWorkNames.immediate(demo),
        )
    }
}
