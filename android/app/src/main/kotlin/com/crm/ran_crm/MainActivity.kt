package com.crm.ran_crm

import android.accounts.Account
import android.accounts.AccountManager
import android.content.ContentResolver
import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ACCOUNT_CHANNEL = "com.crm.ran_crm/account"
    private val BATTERY_CHANNEL = "com.crm.ran_crm/battery"
    private val ACCOUNT_TYPE = "com.crm.ran_crm"
    private val AUTHORITY = "com.crm.ran_crm.provider"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Account sync channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCOUNT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "addAccount" -> {
                    val email = call.argument<String>("email")
                    val token = call.argument<String>("token")

                    if (email != null && token != null) {
                        val success = addAccount(email, token)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Email and token are required", null)
                    }
                }
                "removeAccount" -> {
                    val email = call.argument<String>("email")

                    if (email != null) {
                        val success = removeAccount(email)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Email is required", null)
                    }
                }
                "hasAccount" -> {
                    val hasAccount = hasAccount()
                    result.success(hasAccount)
                }
                "getAccounts" -> {
                    val accounts = getAccounts()
                    result.success(accounts)
                }
                "requestSync" -> {
                    val email = call.argument<String>("email")

                    if (email != null) {
                        val success = requestSync(email)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Email is required", null)
                    }
                }
                "enableAutoSync" -> {
                    val email = call.argument<String>("email")
                    val enable = call.argument<Boolean>("enable") ?: true

                    if (email != null) {
                        val success = enableAutoSync(email, enable)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Email is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestIgnoreBatteryOptimizations" -> {
                    val success = requestIgnoreBatteryOptimizations()
                    result.success(success)
                }
                "isBatteryOptimizationIgnored" -> {
                    val isIgnored = isBatteryOptimizationIgnored()
                    result.success(isIgnored)
                }
                "openBatteryOptimizationSettings" -> {
                    val success = openBatteryOptimizationSettings()
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun addAccount(email: String, token: String): Boolean {
        return try {
            val accountManager = AccountManager.get(this)
            val account = Account(email, ACCOUNT_TYPE)

            // Add account
            val added = accountManager.addAccountExplicitly(account, token, null)

            if (added) {
                // Enable auto-sync
                ContentResolver.setSyncAutomatically(account, AUTHORITY, true)
                ContentResolver.setIsSyncable(account, AUTHORITY, 1)

                // Set periodic sync every hour (in seconds)
                ContentResolver.addPeriodicSync(account, AUTHORITY, Bundle.EMPTY, 3600L)

                // Request immediate sync
                val bundle = Bundle()
                bundle.putBoolean(ContentResolver.SYNC_EXTRAS_MANUAL, true)
                bundle.putBoolean(ContentResolver.SYNC_EXTRAS_EXPEDITED, true)
                ContentResolver.requestSync(account, AUTHORITY, bundle)
            }

            added
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun removeAccount(email: String): Boolean {
        return try {
            val accountManager = AccountManager.get(this)
            val account = Account(email, ACCOUNT_TYPE)

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                accountManager.removeAccountExplicitly(account)
            } else {
                @Suppress("DEPRECATION")
                accountManager.removeAccount(account, null, null)
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun hasAccount(): Boolean {
        val accountManager = AccountManager.get(this)
        val accounts = accountManager.getAccountsByType(ACCOUNT_TYPE)
        return accounts.isNotEmpty()
    }

    private fun getAccounts(): List<String> {
        val accountManager = AccountManager.get(this)
        val accounts = accountManager.getAccountsByType(ACCOUNT_TYPE)
        return accounts.map { it.name }
    }

    private fun requestSync(email: String): Boolean {
        return try {
            val account = Account(email, ACCOUNT_TYPE)
            val bundle = Bundle()
            bundle.putBoolean(ContentResolver.SYNC_EXTRAS_MANUAL, true)
            bundle.putBoolean(ContentResolver.SYNC_EXTRAS_EXPEDITED, true)
            ContentResolver.requestSync(account, AUTHORITY, bundle)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun enableAutoSync(email: String, enable: Boolean): Boolean {
        return try {
            val account = Account(email, ACCOUNT_TYPE)
            ContentResolver.setSyncAutomatically(account, AUTHORITY, enable)
            ContentResolver.setIsSyncable(account, AUTHORITY, if (enable) 1 else 0)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        return try {
            val intent = android.content.Intent(
                android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            )
            intent.data = android.net.Uri.parse("package:$packageName")
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isBatteryOptimizationIgnored(): Boolean {
        return try {
            val powerManager = getSystemService(POWER_SERVICE) as android.os.PowerManager
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                return powerManager.isIgnoringBatteryOptimizations(packageName)
            }
            true // Assume ignored on older versions
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val intent = android.content.Intent(
                android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
            )
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
