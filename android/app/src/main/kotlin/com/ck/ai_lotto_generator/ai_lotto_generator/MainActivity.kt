package com.ck.ai_lotto_generator.ai_lotto_generator

import android.os.Bundle
import android.util.Log
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var consentInformation: ConsentInformation
    private val CHANNEL = "consent_channel"   // ⭐ Flutter → Android bridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ⭐ Flutter calls this channel to re-open consent form
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "showConsentForm") {
                loadConsentForm()    // ⭐ reopen consent form on demand
                result.success(null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ------------------------------------------
        // ⭐ 1. Build Consent Request Parameters
        // ------------------------------------------
        val params = ConsentRequestParameters
            .Builder()
            .setTagForUnderAgeOfConsent(false)
            .build()

        consentInformation = UserMessagingPlatform.getConsentInformation(this)

        // ------------------------------------------
        // ⭐ 2. Request Consent Update
        // ------------------------------------------
        consentInformation.requestConsentInfoUpdate(
            this,
            params,
            {

                // ⭐ FIXED:
                // Only show the form again if REQUIRED
                if (consentInformation.consentStatus ==
                    ConsentInformation.ConsentStatus.REQUIRED &&
                    consentInformation.isConsentFormAvailable) {

                    loadConsentForm()
                }
            },
            { error ->
                Log.e("UMP", "Consent Update Error: ${error.message}")
            }
        )
    }

    // ----------------------------------------------------------
    // ⭐ LOAD CONSENT FORM (startup + manual)
    // ----------------------------------------------------------
    private fun loadConsentForm() {
        UserMessagingPlatform.loadConsentForm(
            this,
            { form ->

                // ⭐ Only auto-show if consent REQUIRED
                if (consentInformation.consentStatus ==
                    ConsentInformation.ConsentStatus.REQUIRED) {

                    form.show(this) {
                        // After dismissal → check again
                        if (consentInformation.consentStatus ==
                            ConsentInformation.ConsentStatus.REQUIRED) {
                            loadConsentForm()
                        }
                    }

                } else {
                    // ⭐ Manual call (Manage Consent)
                    form.show(this, null)
                }
            },
            { error ->
                Log.e("UMP", "Form Load Error: ${error.message}")
            }
        )
    }
}
