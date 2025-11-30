package com.solocrew.expense_managment

import android.Manifest
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sms_receiver"
    private val SMS_PERMISSION_CODE = 100

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRecentSms" -> {
                    val limit = call.argument<Int>("limit") ?: 50
                    val daysBack = call.argument<Int>("daysBack") ?: 7
                    val smsList = getRecentSms(limit, daysBack)
                    result.success(smsList)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getRecentSms(limit: Int, daysBack: Int): List<Map<String, Any>> {
        val smsList = mutableListOf<Map<String, Any>>()
        
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) 
            != PackageManager.PERMISSION_GRANTED) {
            return smsList
        }

        val uri = Uri.parse("content://sms/inbox")
        val cursor: Cursor? = contentResolver.query(
            uri,
            arrayOf("_id", "address", "body", "date"),
            null,
            null,
            "date DESC LIMIT $limit"
        )

        cursor?.use {
            val addressIndex = it.getColumnIndex("address")
            val bodyIndex = it.getColumnIndex("body")
            val dateIndex = it.getColumnIndex("date")

            val cutoffDate = System.currentTimeMillis() - (daysBack * 24 * 60 * 60 * 1000L)

            while (it.moveToNext() && smsList.size < limit) {
                val date = it.getLong(dateIndex)
                if (date >= cutoffDate) {
                    val sms = mapOf(
                        "sender" to (it.getString(addressIndex) ?: ""),
                        "body" to (it.getString(bodyIndex) ?: ""),
                        "timestamp" to date
                    )
                    smsList.add(sms)
                }
            }
        }

        return smsList
    }
}
