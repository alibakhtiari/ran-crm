package com.crm.ran_crm

import android.accounts.*
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.TextUtils

class AccountAuthenticator(private val context: Context) : AbstractAccountAuthenticator(context) {

    companion object {
        const val ACCOUNT_TYPE = "com.crm.ran_crm"
        const val AUTH_TOKEN_TYPE = "com.crm.ran_crm.auth"
    }

    override fun addAccount(
        response: AccountAuthenticatorResponse?,
        accountType: String?,
        authTokenType: String?,
        requiredFeatures: Array<out String>?,
        options: Bundle?
    ): Bundle {
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra(AccountManager.KEY_ACCOUNT_AUTHENTICATOR_RESPONSE, response)
            putExtra("ACTION", "ADD_ACCOUNT")
        }

        return Bundle().apply {
            putParcelable(AccountManager.KEY_INTENT, intent)
        }
    }

    override fun getAuthToken(
        response: AccountAuthenticatorResponse?,
        account: Account?,
        authTokenType: String?,
        options: Bundle?
    ): Bundle {
        val accountManager = AccountManager.get(context)
        var authToken = accountManager.peekAuthToken(account, authTokenType)

        if (TextUtils.isEmpty(authToken)) {
            authToken = accountManager.getPassword(account)
        }

        return if (!TextUtils.isEmpty(authToken)) {
            Bundle().apply {
                putString(AccountManager.KEY_ACCOUNT_NAME, account?.name)
                putString(AccountManager.KEY_ACCOUNT_TYPE, account?.type)
                putString(AccountManager.KEY_AUTHTOKEN, authToken)
            }
        } else {
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra(AccountManager.KEY_ACCOUNT_AUTHENTICATOR_RESPONSE, response)
                putExtra("ACTION", "GET_AUTH_TOKEN")
                putExtra(AccountManager.KEY_ACCOUNT_NAME, account?.name)
            }

            Bundle().apply {
                putParcelable(AccountManager.KEY_INTENT, intent)
            }
        }
    }

    override fun getAuthTokenLabel(authTokenType: String?): String {
        return "CRM Access Token"
    }

    override fun confirmCredentials(
        response: AccountAuthenticatorResponse?,
        account: Account?,
        options: Bundle?
    ): Bundle? {
        return null
    }

    override fun updateCredentials(
        response: AccountAuthenticatorResponse?,
        account: Account?,
        authTokenType: String?,
        options: Bundle?
    ): Bundle? {
        return null
    }

    override fun hasFeatures(
        response: AccountAuthenticatorResponse?,
        account: Account?,
        features: Array<out String>?
    ): Bundle {
        return Bundle().apply {
            putBoolean(AccountManager.KEY_BOOLEAN_RESULT, false)
        }
    }

    override fun editProperties(
        response: AccountAuthenticatorResponse?,
        accountType: String?
    ): Bundle? {
        return null
    }
}
