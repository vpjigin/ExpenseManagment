package com.solocrew.expense_managment

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION == intent.action) {
            val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            
            for (smsMessage in smsMessages) {
                val messageBody = smsMessage.messageBody
                val sender = smsMessage.originatingAddress
                val timestamp = smsMessage.timestampMillis
                
                Log.d("SmsReceiver", "SMS received from $sender: $messageBody")
                
                // Extract amount from SMS
                val extractedAmount = extractAmountFromSms(messageBody)
                
                // Check if it's an expense-related SMS
                val isExpense = isExpenseSms(messageBody)
                
                Log.d("SmsReceiver", "Amount: $extractedAmount, IsExpense: $isExpense")
                
                if (extractedAmount > 0 && isExpense) {
                    // Launch overlay activity with extracted amount
                    Log.d("SmsReceiver", "Launching QuickAddActivity with amount: $extractedAmount")
                    launchQuickAddActivity(context, extractedAmount, messageBody)
                } else {
                    Log.d("SmsReceiver", "Skipping SMS - amount: $extractedAmount, isExpense: $isExpense")
                }
            }
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
                    Log.d("SmsReceiver", "Extracted amount: $amount from pattern1")
                    return amount
                }
            } catch (e: Exception) {
                Log.e("SmsReceiver", "Error parsing amount: ${e.message}")
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
                    Log.d("SmsReceiver", "Extracted amount: $amount from pattern2")
                    return amount
                }
            } catch (e: Exception) {
                Log.e("SmsReceiver", "Error parsing amount: ${e.message}")
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
                    Log.d("SmsReceiver", "Extracted amount: $amount from pattern3")
                    return amount
                }
            } catch (e: Exception) {
                Log.e("SmsReceiver", "Error parsing amount: ${e.message}")
            }
        }
        
        Log.d("SmsReceiver", "No amount found in SMS: $body")
        return 0.0
    }
    
    private fun isExpenseSms(body: String?): Boolean {
        if (body == null) return false
        
        val bodyLower = body.lowercase()
        val expenseKeywords = listOf(
            "debit", "debited", "spent", "paid", "purchase", 
            "withdrawal", "withdrawn", "deducted", "transaction",
            "payment", "purchased", "charged"
        )
        
        val isExpense = expenseKeywords.any { keyword ->
            bodyLower.contains(keyword)
        }
        
        Log.d("SmsReceiver", "isExpenseSms check: $isExpense for message: $body")
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
            // This works even when app is closed or in background
            context.startActivity(intent)
            
            // Release wake lock after activity starts
            wakeLock.release()
            
            Log.d("SmsReceiver", "Activity launched successfully")
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Error launching QuickAddActivity: ${e.message}", e)
        }
    }
}
