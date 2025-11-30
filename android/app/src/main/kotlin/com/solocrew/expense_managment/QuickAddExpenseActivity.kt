package com.solocrew.expense_managment

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class QuickAddExpenseActivity : FlutterActivity() {
    private val CHANNEL = "quick_add_expense"
    private var amount: Double = 0.0
    private var smsBody: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Get amount and SMS body from intent
        amount = intent.getDoubleExtra("amount", 0.0)
        smsBody = intent.getStringExtra("sms_body")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Send data to Flutter via method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPrefilledData" -> {
                    val data = mapOf(
                        "amount" to amount,
                        "smsBody" to (smsBody ?: "")
                    )
                    result.success(data)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun getInitialRoute(): String? {
        // Navigate to quick-add route when activity starts
        return "/quick-add?amount=$amount&smsBody=${smsBody?.let { android.net.Uri.encode(it) } ?: ""}"
    }
}
