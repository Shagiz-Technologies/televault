package et.shagiz.tele_vault

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class TeleVaultSyncWorker(
    context: Context,
    parameters: WorkerParameters,
) : Worker(context, parameters) {
    override fun doWork(): Result {
        val namespace = inputData.getString(TeleVaultSyncWorkNames.NAMESPACE_KEY)
            ?: return Result.failure()
        val completion = CountDownLatch(1)
        var delivered = false
        BackgroundSyncChannel.requestDartSync(namespace) { success ->
            delivered = success
            completion.countDown()
        }
        if (!completion.await(30, TimeUnit.SECONDS)) return Result.retry()
        return if (delivered) Result.success() else Result.retry()
    }
}

object TeleVaultSyncWorkScheduler {
    fun configure(
        context: Context,
        namespace: String,
        wifiOnly: Boolean,
    ) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(
                if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED,
            )
            .build()
        val periodic = PeriodicWorkRequestBuilder<TeleVaultSyncWorker>(
            15,
            TimeUnit.MINUTES,
        )
            .setConstraints(constraints)
            .setInputData(workDataOf(TeleVaultSyncWorkNames.NAMESPACE_KEY to namespace))
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .addTag(namespace)
            .build()
        val immediate = OneTimeWorkRequestBuilder<TeleVaultSyncWorker>()
            .setConstraints(constraints)
            .setInputData(workDataOf(TeleVaultSyncWorkNames.NAMESPACE_KEY to namespace))
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .addTag(namespace)
            .build()
        val manager = WorkManager.getInstance(context)
        manager.enqueueUniquePeriodicWork(
            TeleVaultSyncWorkNames.periodic(namespace),
            ExistingPeriodicWorkPolicy.UPDATE,
            periodic,
        )
        manager.enqueueUniqueWork(
            TeleVaultSyncWorkNames.immediate(namespace),
            ExistingWorkPolicy.KEEP,
            immediate,
        )
    }

    fun cancel(context: Context, namespace: String) {
        val manager = WorkManager.getInstance(context)
        manager.cancelUniqueWork(TeleVaultSyncWorkNames.periodic(namespace))
        manager.cancelUniqueWork(TeleVaultSyncWorkNames.immediate(namespace))
        manager.cancelAllWorkByTag(namespace)
    }
}

internal object TeleVaultSyncWorkNames {
    const val NAMESPACE_KEY = "runtime_namespace"

    fun periodic(namespace: String) = "$namespace.periodic_backup"

    fun immediate(namespace: String) = "$namespace.immediate_backup"
}
