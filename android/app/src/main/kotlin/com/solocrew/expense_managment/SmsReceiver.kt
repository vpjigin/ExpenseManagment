package com.solocrew.expense_managment

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
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
                
                // Extract amount from SMS
                val extractedAmount = extractAmountFromSms(messageBody)
                
                // Check if it's an expense-related SMS
                if (extractedAmount > 0 && isExpenseSms(messageBody)) {
                    // Launch overlay activity with extracted amount
                    launchQuickAddActivity(context, extractedAmount, messageBody)
                }
            }
        }
    }
    
    private fun extractAmountFromSms(body: String?): Double {
        if (body == null) return 0.0
        
        val bodyLower = body.toLowerCase()
        
        // Pattern 1: Rs.500, ₹500, INR 500, etc.
        val pattern1 = Pattern.compile(
            "(?:rs\\.?|inr|₹|rupees?)\\s*:?\\s*(\\d+(?:\\.\\d{2})?)",
            Pattern.CASE_INSENSITIVE
        )
        val matcher1 = pattern1.matcher(bodyLower)
        if (matcher1.find()) {
            try {
                return matcher1.group(1)?.toDouble() ?: 0.0
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
                return matcher2.group(1)?.toDouble() ?: 0.0
            } catch (e: Exception) {
                Log.e("SmsReceiver", "Error parsing amount: ${e.message}")
            }
        }
        
        return 0.0
    }
    
    private fun isExpenseSms(body: String?): Boolean {
        if (body == null) return false
        
        val bodyLower = body.toLowerCase()
        val expenseKeywords = listOf(
            "debited", "spent", "paid", "purchase", 
            "withdrawal", "deducted", "transaction"
        )
        
        return expenseKeywords.any { keyword ->
            bodyLower.contains(keyword)
        }
    }
    
    private fun launchQuickAddActivity(
        context: Context,
        amount: Double,
        smsBody: String?
    ) {
        try {
            val intent = Intent(context, QuickAddExpenseActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("amount", amount)
                putExtra("sms_body", smsBody)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Error launching QuickAddActivity: ${e.message}")
        }
    }
}
