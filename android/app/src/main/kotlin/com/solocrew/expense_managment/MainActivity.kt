package com.solocrew.expense_managment

import android.Manifest
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "ExpenseSMS"
    }
    
    private val CHANNEL = "sms_receiver"
    private val SMS_PERMISSION_CODE = 100
    private var smsReceiver: SmsReceiver? = null
    private var smsContentObserver: SmsContentObserver? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "MainActivity onCreate - Checking SMS permission")
        
        // Register SMS receiver programmatically as backup
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) 
            == PackageManager.PERMISSION_GRANTED) {
            try {
                smsReceiver = SmsReceiver()
                val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION).apply {
                    priority = 1000
                }
                registerReceiver(smsReceiver, filter, Manifest.permission.BROADCAST_SMS, null)
                Log.d(TAG, "✓ SMS Receiver registered programmatically")
            } catch (e: Exception) {
                Log.e(TAG, "✗ Error registering SMS receiver: ${e.message}", e)
            }
        } else {
            Log.w(TAG, "✗ SMS permission not granted, cannot register receiver")
        }
        
        // Register ContentObserver for SMS (works on Android 10+)
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) 
            == PackageManager.PERMISSION_GRANTED) {
            try {
                smsContentObserver = SmsContentObserver(android.os.Handler(android.os.Looper.getMainLooper()), this)
                
                // Monitor both inbox and sent folders
                val uris = listOf(
                    Uri.parse("content://sms/inbox"),
                    Uri.parse("content://sms/sent"),
                    Uri.parse("content://sms"),
                    Uri.parse("content://mms-sms") // Also monitor MMS-SMS combined
                )
                
                for (uri in uris) {
                    try {
                        contentResolver.registerContentObserver(uri, true, smsContentObserver!!)
                        Log.d("message", "[MainActivity] ContentObserver registered for: $uri")
                        Log.d(TAG, "✓ ContentObserver registered for: $uri")
                    } catch (e: Exception) {
                        Log.e("message", "[MainActivity] Failed to register observer for $uri: ${e.message}")
                        Log.e(TAG, "✗ Failed to register observer for $uri: ${e.message}", e)
                    }
                }
                
                Log.d("message", "[MainActivity] ✓ SMS ContentObserver registration complete")
                Log.d(TAG, "✓ SMS ContentObserver registered for inbox, sent, and all SMS")
            } catch (e: Exception) {
                Log.e("message", "[MainActivity] ✗ Error registering ContentObserver: ${e.message}")
                Log.e(TAG, "✗ Error registering ContentObserver: ${e.message}", e)
            }
        } else {
            Log.w("message", "[MainActivity] ✗ READ_SMS permission not granted")
            Log.w(TAG, "✗ READ_SMS permission not granted, cannot register ContentObserver")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            smsReceiver?.let {
                unregisterReceiver(it)
                Log.d(TAG, "SMS Receiver unregistered")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering SMS receiver: ${e.message}")
        }
        
        try {
            smsContentObserver?.let {
                contentResolver.unregisterContentObserver(it)
                Log.d(TAG, "SMS ContentObserver unregistered")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering ContentObserver: ${e.message}")
        }
    }

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
                "logAllSms" -> {
                    logAllSms()
                    result.success(true)
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
    
    private fun logAllSms() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) 
            != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "READ_SMS permission not granted, cannot log SMS")
            return
        }
        
        try {
            val uris = listOf(
                Uri.parse("content://sms/inbox"),
                Uri.parse("content://sms/sent"),
                Uri.parse("content://sms/draft")
            )
            
            var totalCount = 0
            
            for (uri in uris) {
                val cursor: Cursor? = contentResolver.query(
                    uri,
                    arrayOf("_id", "address", "body", "date", "type"),
                    null,
                    null,
                    "date DESC"
                )
                
                cursor?.use {
                    val addressIndex = it.getColumnIndex("address")
                    val bodyIndex = it.getColumnIndex("body")
                    val dateIndex = it.getColumnIndex("date")
                    val typeIndex = it.getColumnIndex("type")
                    
                    val folderName = when (uri.toString()) {
                        "content://sms/inbox" -> "INBOX"
                        "content://sms/sent" -> "SENT"
                        "content://sms/draft" -> "DRAFT"
                        else -> "UNKNOWN"
                    }
                    
                    Log.d("message", "========== $folderName MESSAGES ==========")
                    
                    var folderCount = 0
                    while (it.moveToNext()) {
                        val address = it.getString(addressIndex) ?: "Unknown"
                        val body = it.getString(bodyIndex) ?: ""
                        val date = it.getLong(dateIndex)
                        val type = it.getInt(typeIndex)
                        
                        val dateStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
                            .format(java.util.Date(date))
                        
                        Log.d("message", "[$folderName] From: $address | Date: $dateStr | Type: $type")
                        Log.d("message", "[$folderName] Body: $body")
                        Log.d("message", "[$folderName] ---")
                        
                        folderCount++
                        totalCount++
                    }
                    
                    Log.d("message", "[$folderName] Total: $folderCount messages")
                    Log.d("message", "==========================================")
                }
            }
            
            Log.d("message", "TOTAL SMS COUNT: $totalCount messages across all folders")
        } catch (e: Exception) {
            Log.e(TAG, "Error logging SMS: ${e.message}", e)
        }
    }
}
