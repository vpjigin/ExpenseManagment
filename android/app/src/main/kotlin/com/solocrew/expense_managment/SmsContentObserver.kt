package com.solocrew.expense_managment

import android.content.Context
import android.database.ContentObserver
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.provider.Telephony
import android.util.Log
import java.util.concurrent.atomic.AtomicLong

class SmsContentObserver(
    handler: Handler,
    private val context: Context
) : ContentObserver(handler) {
    
    companion object {
        private const val TAG = "ExpenseSMS"
        private val lastProcessedTimestamp = AtomicLong(0)
    }
    
    override fun onChange(selfChange: Boolean, uri: Uri?) {
        super.onChange(selfChange, uri)
        
        // Log immediately with both tags
        android.util.Log.d("message", "========================================")
        android.util.Log.d("message", "[ContentObserver] onChange TRIGGERED!")
        android.util.Log.d("message", "[ContentObserver] URI: $uri")
        android.util.Log.d("message", "[ContentObserver] selfChange: $selfChange")
        android.util.Log.d("message", "========================================")
        
        Log.d(TAG, "SMS ContentObserver onChange triggered - uri: $uri, selfChange: $selfChange")
        
        // Small delay to ensure SMS is fully written to database (increased delay for RCS)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            Log.d("message", "[ContentObserver] Processing after delay...")
            processNewSms()
        }, 1000) // Increased to 1 second for RCS messages
    }
    
    private fun processNewSms() {
        try {
            Log.d("message", "[ContentObserver] ========== PROCESSING NEW SMS ==========")
            Log.d("message", "[ContentObserver] Starting to process new SMS...")
            Log.d("message", "[ContentObserver] lastProcessedTimestamp: ${lastProcessedTimestamp.get()}")
            Log.d(TAG, "Processing new SMS, lastProcessedTimestamp: ${lastProcessedTimestamp.get()}")
            
            // Check inbox, sent, and also query all SMS (for RCS compatibility)
            val uris = listOf(
                Uri.parse("content://sms/inbox"),
                Uri.parse("content://sms/sent"),
                Uri.parse("content://sms") // General SMS URI (includes RCS)
            )
            
            for (uri in uris) {
                val folderName = when (uri.toString()) {
                    "content://sms/inbox" -> "INBOX"
                    "content://sms/sent" -> "SENT"
                    else -> "UNKNOWN"
                }
                
                Log.d("message", "[ContentObserver] Checking $folderName folder: $uri")
                Log.d(TAG, "Checking SMS folder: $uri")
                
                // Query with type column to identify RCS messages
                val cursor: Cursor? = context.contentResolver.query(
                    uri,
                    arrayOf("_id", "address", "body", "date", "type", "service_center"),
                    null,
                    null,
                    "date DESC LIMIT 10"
                )
                
                if (cursor == null) {
                    Log.d("message", "[ContentObserver] $folderName: Cursor is null!")
                    Log.w(TAG, "$folderName: Cursor is null")
                    continue
                }
            
            cursor.use {
                val addressIndex = it.getColumnIndex("address")
                val bodyIndex = it.getColumnIndex("body")
                val dateIndex = it.getColumnIndex("date")
                val typeIndex = try { it.getColumnIndex("type") } catch (e: Exception) { -1 }
                
                val lastTimestamp = lastProcessedTimestamp.get()
                var checkedCount = 0
                var newCount = 0
                
                Log.d("message", "[ContentObserver] $folderName: Found ${it.count} messages in cursor")
                
                while (it.moveToNext()) {
                    checkedCount++
                    val timestamp = it.getLong(dateIndex)
                    val messageBody = it.getString(bodyIndex) ?: ""
                    val sender = it.getString(addressIndex) ?: ""
                    
                    // Log ALL messages found (even if skipped) with "message" tag
                    val dateStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
                        .format(java.util.Date(timestamp))
                    
                    val messageType = if (typeIndex >= 0) {
                        try { it.getInt(typeIndex).toString() } catch (e: Exception) { "unknown" }
                    } else {
                        "unknown"
                    }
                    
                    // Only process SMS newer than last processed
                    if (timestamp > lastTimestamp) {
                        newCount++
                        Log.d("message", "[$folderName] NEW From: $sender | Date: $dateStr | Timestamp: $timestamp | Type: $messageType")
                        Log.d("message", "[$folderName] NEW Body: $messageBody")
                        Log.d("message", "[$folderName] NEW ---")
                        
                        Log.d(TAG, "=== NEW SMS DETECTED ===")
                        Log.d(TAG, "Sender: $sender")
                        Log.d(TAG, "Body: $messageBody")
                        Log.d(TAG, "Timestamp: $timestamp (lastProcessed: $lastTimestamp)")
                        
                        // Extract amount from SMS
                        val extractedAmount = extractAmountFromSms(messageBody)
                        
                        // Check if it's an expense-related SMS
                        val isExpense = isExpenseSms(messageBody)
                        
                        Log.d(TAG, "Extracted Amount: $extractedAmount")
                        Log.d(TAG, "Is Expense SMS: $isExpense")
                        
                        // Show popup if amount is found
                        if (extractedAmount > 0) {
                            if (isExpense || extractedAmount >= 1.0) {
                                Log.d("message", "[$folderName] ✓ Launching popup for amount: $extractedAmount")
                                Log.d(TAG, "✓ Conditions met! Launching QuickAddActivity with amount: $extractedAmount")
                                launchQuickAddActivity(context, extractedAmount, messageBody)
                                
                                // Update last processed timestamp
                                lastProcessedTimestamp.set(timestamp)
                                break // Process only the most recent SMS
                            } else {
                                Log.d("message", "[$folderName] ✗ Skipped - amount too small: $extractedAmount")
                                Log.d(TAG, "✗ Skipping SMS - amount too small or no expense keywords: $extractedAmount")
                            }
                        } else {
                            Log.d("message", "[$folderName] ✗ Skipped - no amount found")
                            Log.d(TAG, "✗ Skipping SMS - no amount found, isExpense: $isExpense")
                        }
                    } else {
                        // Log old messages too (for debugging) - but only first few to avoid spam
                        if (checkedCount <= 3) {
                            Log.d("message", "[$folderName] OLD From: $sender | Date: $dateStr | Timestamp: $timestamp (already processed, lastProcessed: $lastTimestamp)")
                        }
                    }
                }
                
                Log.d("message", "[ContentObserver] $folderName: Checked $checkedCount messages, found $newCount new")
                Log.d(TAG, "$folderName: Checked $checkedCount messages, found $newCount new")
            }
            }
            
            Log.d("message", "[ContentObserver] ========== FINISHED PROCESSING ==========")
        } catch (e: Exception) {
            Log.e("message", "[ContentObserver] Error: ${e.message}")
            Log.e(TAG, "Error processing SMS: ${e.message}", e)
        }
    }
    
    private fun extractAmountFromSms(body: String?): Double {
        if (body == null) return 0.0
        
        val bodyLower = body.lowercase()
        
        // Pattern 1: Rs.500, ₹500, INR 500, Debit:Rs. 65.00, etc.
        val pattern1 = java.util.regex.Pattern.compile(
            "(?:rs\\.?|inr|₹|rupees?)\\s*:?\\s*(\\d+(?:\\.\\d{2})?)",
            java.util.regex.Pattern.CASE_INSENSITIVE
        )
        val matcher1 = pattern1.matcher(bodyLower)
        if (matcher1.find()) {
            try {
                val amount = matcher1.group(1)?.toDouble() ?: 0.0
                if (amount > 0) {
                    Log.d(TAG, "Extracted amount: $amount from pattern1")
                    return amount
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing amount: ${e.message}")
            }
        }
        
        // Pattern 2: 500 rs, 500 inr, etc.
        val pattern2 = java.util.regex.Pattern.compile(
            "(\\d+(?:\\.\\d{2})?)\\s*(?:rs|inr|₹)",
            java.util.regex.Pattern.CASE_INSENSITIVE
        )
        val matcher2 = pattern2.matcher(bodyLower)
        if (matcher2.find()) {
            try {
                val amount = matcher2.group(1)?.toDouble() ?: 0.0
                if (amount > 0) {
                    Log.d(TAG, "Extracted amount: $amount from pattern2")
                    return amount
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing amount: ${e.message}")
            }
        }
        
        // Pattern 3: Handle cases like "Debit:Rs. 65.00" where colon comes before
        val pattern3 = java.util.regex.Pattern.compile(
            ":\\s*(?:rs\\.?|inr|₹)\\s*(\\d+(?:\\.\\d{2})?)",
            java.util.regex.Pattern.CASE_INSENSITIVE
        )
        val matcher3 = pattern3.matcher(bodyLower)
        if (matcher3.find()) {
            try {
                val amount = matcher3.group(1)?.toDouble() ?: 0.0
                if (amount > 0) {
                    Log.d(TAG, "Extracted amount: $amount from pattern3")
                    return amount
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing amount: ${e.message}")
            }
        }
        
        Log.d(TAG, "No amount found in SMS: $body")
        return 0.0
    }
    
    private fun isExpenseSms(body: String?): Boolean {
        if (body == null) return false
        
        val bodyLower = body.lowercase()
        val expenseKeywords = listOf(
            "debit", "debited", "spent", "paid", "purchase", 
            "withdrawal", "withdrawn", "deducted", "transaction",
            "payment", "purchased", "charged", "sent", "transfer",
            "credited", "credit", "withdraw", "cash", "upi", "neft",
            "imps", "rtgs", "bank", "account", "a/c", "ac"
        )
        
        val isExpense = expenseKeywords.any { keyword ->
            bodyLower.contains(keyword)
        }
        
        Log.d(TAG, "isExpenseSms check: $isExpense for message: $body")
        return isExpense
    }
    
    private fun launchQuickAddActivity(
        context: Context,
        amount: Double,
        smsBody: String?
    ) {
        try {
            // Wake up device if screen is off
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            val wakeLock = powerManager.newWakeLock(
                android.os.PowerManager.SCREEN_BRIGHT_WAKE_LOCK or android.os.PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "ExpenseManager::SmsWakeLock"
            )
            wakeLock.acquire(5000) // Hold for 5 seconds
            
            val intent = android.content.Intent(context, QuickAddExpenseActivity::class.java).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or 
                        android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        android.content.Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT or
                        android.content.Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                putExtra("amount", amount)
                putExtra("sms_body", smsBody)
            }
            
            // Try to launch activity directly
            try {
                context.startActivity(intent)
                Log.d(TAG, "Activity launched successfully")
            } catch (e: SecurityException) {
                Log.w(TAG, "Direct activity launch failed, showing notification: ${e.message}")
                showNotification(context, amount, smsBody)
            } catch (e: Exception) {
                Log.e(TAG, "Error launching activity: ${e.message}", e)
                showNotification(context, amount, smsBody)
            }
            
            // Release wake lock after activity starts
            wakeLock.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error in launchQuickAddActivity: ${e.message}", e)
            showNotification(context, amount, smsBody)
        }
    }
    
    private fun showNotification(
        context: Context,
        amount: Double,
        smsBody: String?
    ) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            
            // Create notification channel for Android 8.0+
            val channelId = "expense_quick_add"
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    channelId,
                    "Quick Add Expense",
                    android.app.NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications for quick expense entry"
                    enableVibration(true)
                    enableLights(true)
                }
                notificationManager.createNotificationChannel(channel)
            }
            
            // Create intent for notification tap
            val intent = android.content.Intent(context, QuickAddExpenseActivity::class.java).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or 
                        android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("amount", amount)
                putExtra("sms_body", smsBody)
            }
            
            val pendingIntent = android.app.PendingIntent.getActivity(
                context,
                0,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = androidx.core.app.NotificationCompat.Builder(context, channelId)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Expense Detected: ₹${String.format("%.2f", amount)}")
                .setContentText("Tap to add expense")
                .setStyle(androidx.core.app.NotificationCompat.BigTextStyle().bigText(smsBody ?: "Expense detected from SMS"))
                .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                .setDefaults(androidx.core.app.NotificationCompat.DEFAULT_ALL)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()
            
            notificationManager.notify(System.currentTimeMillis().toInt(), notification)
            Log.d(TAG, "Notification shown successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error showing notification: ${e.message}", e)
        }
    }
}
