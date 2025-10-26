package com.crm.ran_crm

import android.accounts.Account
import android.content.AbstractThreadedSyncAdapter
import android.content.ContentProviderClient
import android.content.Context
import android.content.SyncResult
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.concurrent.CountDownLatch

class SyncAdapter(
    context: Context,
    autoInitialize: Boolean
) : AbstractThreadedSyncAdapter(context, autoInitialize) {

    companion object {
        private const val TAG = "CRMSyncAdapter"
    }

    override fun onPerformSync(
        account: Account?,
        extras: Bundle?,
        authority: String?,
        provider: ContentProviderClient?,
        syncResult: SyncResult?
    ) {
        Log.i(TAG, "[Final Fix] Starting Android sync for account: ${account?.name} on thread: ${Thread.currentThread().name}")

        val latch = CountDownLatch(1)
        var flutterEngine: FlutterEngine? = null
        var engineCreationError: Throwable? = null

        // FlutterEngine must be created on the Main thread.
        Handler(Looper.getMainLooper()).post {
            Log.i(TAG, "[Final Fix] Creating FlutterEngine on thread: ${Thread.currentThread().name}.")
            try {
                val appContext = context.applicationContext
                val loader = FlutterInjector.instance().flutterLoader()
                if (!loader.initialized()) {
                    loader.startInitialization(appContext)
                    loader.ensureInitializationComplete(appContext, null)
                }

                flutterEngine = FlutterEngine(appContext, null, false)

                val dartEntrypoint = DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "syncCallback"
                )
                flutterEngine!!.dartExecutor.executeDartEntrypoint(dartEntrypoint)
                Log.i(TAG, "[Final Fix] FlutterEngine created successfully.")
            } catch (t: Throwable) {
                Log.e(TAG, "[Final Fix] CRITICAL: FlutterEngine creation failed.", t)
                engineCreationError = t
            } finally {
                latch.countDown()
            }
        }

        try {
            Log.d(TAG, "[Final Fix] Waiting for FlutterEngine creation...")
            latch.await()
            Log.d(TAG, "[Final Fix] Resuming sync process.")

            engineCreationError?.let {
                throw RuntimeException("FlutterEngine creation failed on main thread", it)
            }

            if (flutterEngine == null) {
                throw IllegalStateException("FlutterEngine is null after creation attempt.")
            }

            Log.i(TAG, "[Final Fix] Simulating sync work and sending broadcast.")
            context.sendBroadcast(android.content.Intent("com.crm.ran_crm.SYNC_REQUESTED"))
            Log.i(TAG, "[Final Fix] Sync broadcast sent.")

        } catch (e: Exception) {
            Log.e(TAG, "[Final Fix] ❌ Error during sync execution", e)
            syncResult?.stats?.numIoExceptions = (syncResult?.stats?.numIoExceptions ?: 0) + 1
        } finally {
            flutterEngine?.let { engine ->
                Handler(Looper.getMainLooper()).post {
                    Log.i(TAG, "[Final Fix] Destroying FlutterEngine.")
                    engine.destroy()
                }
            }
        }
    }
}
