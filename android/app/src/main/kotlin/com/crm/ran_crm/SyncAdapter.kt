package com.crm.ran_crm

import android.accounts.Account
import android.content.AbstractThreadedSyncAdapter
import android.content.ContentProviderClient
import android.content.Context
import android.content.SyncResult
import android.os.Bundle
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class SyncAdapter(
    context: Context,
    autoInitialize: Boolean
) : AbstractThreadedSyncAdapter(context, autoInitialize) {

    companion object {
        private const val TAG = "CRMSyncAdapter"
        private const val SYNC_CHANNEL = "com.crm.ran_crm/sync"
    }

    override fun onPerformSync(
        account: Account?,
        extras: Bundle?,
        authority: String?,
        provider: ContentProviderClient?,
        syncResult: SyncResult?
    ) {
        Log.d(TAG, "📱 Starting Android sync for account: ${account?.name}")

        try {
            // Create Flutter engine for background sync
            val flutterLoader = FlutterInjector.instance().flutterLoader()
            flutterLoader.startInitialization(context)
            flutterLoader.ensureInitializationComplete(context, null)

            val flutterEngine = FlutterEngine(context)
            val dartEntrypoint = DartExecutor.DartEntrypoint(
                flutterLoader.findAppBundlePath(),
                "syncCallback" // This function should be defined in Dart
            )

            // For simplicity, just trigger a broadcast that the Flutter app can listen to
            // when it's in foreground
            val intent = android.content.Intent("com.crm.ran_crm.SYNC_REQUESTED")
            intent.putExtra("account_name", account?.name)
            intent.putExtra("sync_type", "auto")
            context.sendBroadcast(intent)

            Log.d(TAG, "✅ Sync broadcast sent successfully")

            // You can also use a WorkManager task here to ensure sync happens
            // even if the app isn't running

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error during sync", e)
            syncResult?.stats?.numIoExceptions = 1
        }
    }
}
