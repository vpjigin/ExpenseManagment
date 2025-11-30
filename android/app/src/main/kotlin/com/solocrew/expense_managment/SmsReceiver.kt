package com.solocrew.expense_managment

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ExpenseSMS"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "BroadcastReceiver triggered with action: ${intent.action}")
        
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION == intent.action) {
            Log.d(TAG, "SMS_RECEIVED_ACTION detected")
            val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            Log.d(TAG, "Found ${smsMessages.size} SMS message(s)")
            
            for (smsMessage in smsMessages) {
                val messageBody = smsMessage.messageBody
                val sender = smsMessage.originatingAddress
                val timestamp = smsMessage.timestampMillis
                
                // Log with "message" tag for easy filtering
                val dateStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
                    .format(java.util.Date(timestamp))
                Log.d("message", "[RECEIVED] From: $sender | Date: $dateStr")
                Log.d("message", "[RECEIVED] Body: $messageBody")
                Log.d("message", "[RECEIVED] ---")
                
                Log.d(TAG, "=== SMS DETAILS ===")
                Log.d(TAG, "Sender: $sender")
                Log.d(TAG, "Body: $messageBody")
                Log.d(TAG, "Timestamp: $timestamp")
                
                // Extract amount from SMS
                val extractedAmount = extractAmountFromSms(messageBody)
                
                // Check if it's an expense-related SMS
                val isExpense = isExpenseSms(messageBody)
                
                Log.d(TAG, "Extracted Amount: $extractedAmount")
                Log.d(TAG, "Is Expense SMS: $isExpense")
                
                // Show popup if amount is found (even without keywords, as amount detection is reliable)
                // But still check keywords to avoid false positives
                if (extractedAmount > 0) {
                    if (isExpense || extractedAmount >= 1.0) { // Show if expense keyword found OR amount >= 1
                        // Launch overlay activity with extracted amount
                        Log.d(TAG, "✓ Conditions met! Launching QuickAddActivity with amount: $extractedAmount")
                        launchQuickAddActivity(context, extractedAmount, messageBody)
                    } else {
                        Log.d(TAG, "✗ Skipping SMS - amount too small or no expense keywords: $extractedAmount")
                    }
                } else {
                    Log.d(TAG, "✗ Skipping SMS - no amount found, isExpense: $isExpense")
                }
            }
        } else {
            Log.d(TAG, "Unknown action: ${intent.action}")
        }
    }
    
    private fun extractAmountFromSms(body: String?): Double {
        if (body == null) return 0.0
        
        val bodyLower = body.lowercase()
        
        // Pattern 1: Rs.500, ₹500, INR 500, Debit:Rs. 65.00, etc.
        // Handles colon before or after currency symbol
        val pattern1 = Pattern.compile(
            "(?:rs\\.?|inr|₹|rupees?)\\s*:?\\s*(\\d+(?:\\.\\d{2})?)",
            Pattern.CASE_INSENSITIVE
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
        val pattern2 = Pattern.compile(
            "(\\d+(?:\\.\\d{2})?)\\s*(?:rs|inr|₹)",
            Pattern.CASE_INSENSITIVE
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
        val pattern3 = Pattern.compile(
            ":\\s*(?:rs\\.?|inr|₹)\\s*(\\d+(?:\\.\\d{2})?)",
            Pattern.CASE_INSENSITIVE
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
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "ExpenseManager::SmsWakeLock"
            )
            wakeLock.acquire(5000) // Hold for 5 seconds
            
            val intent = Intent(context, QuickAddExpenseActivity::class.java).apply {
                // FLAG_ACTIVITY_NEW_TASK is required to start activity from BroadcastReceiver
                // FLAG_ACTIVITY_CLEAR_TOP ensures only one instance
                // FLAG_ACTIVITY_SINGLE_TOP prevents multiple instances
                // FLAG_ACTIVITY_BROUGHT_TO_FRONT brings activity to front if already exists
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                putExtra("amount", amount)
                putExtra("sms_body", smsBody)
            }
            
            // Try to launch activity directly (works for SMS_RECEIVED broadcasts)
            try {
                context.startActivity(intent)
                Log.d(TAG, "Activity launched successfully")
            } catch (e: SecurityException) {
                // If direct launch fails, show notification instead
                Log.w(TAG, "Direct activity launch failed, showing notification: ${e.message}")
                showNotification(context, amount, smsBody)
            } catch (e: Exception) {
                // Other errors - show notification as fallback
                Log.e(TAG, "Error launching activity: ${e.message}", e)
                showNotification(context, amount, smsBody)
            }
            
            // Release wake lock after activity starts
            wakeLock.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error in launchQuickAddActivity: ${e.message}", e)
            // Fallback to notification
            showNotification(context, amount, smsBody)
        }
    }
    
    private fun showNotification(
        context: Context,
        amount: Double,
        smsBody: String?
    ) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Create notification channel for Android 8.0+
            val channelId = "expense_quick_add"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "Quick Add Expense",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications for quick expense entry"
                    enableVibration(true)
                    enableLights(true)
                }
                notificationManager.createNotificationChannel(channel)
            }
            
            // Create intent for notification tap
            val intent = Intent(context, QuickAddExpenseActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("amount", amount)
                putExtra("sms_body", smsBody)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Expense Detected: ₹${String.format("%.2f", amount)}")
                .setContentText("Tap to add expense")
                .setStyle(NotificationCompat.BigTextStyle().bigText(smsBody ?: "Expense detected from SMS"))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
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
