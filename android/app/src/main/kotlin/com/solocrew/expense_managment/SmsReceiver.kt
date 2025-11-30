package com.solocrew.expense_managment

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import android.content.SharedPreferences

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION == intent.action) {
            val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            
            for (smsMessage in smsMessages) {
                val messageBody = smsMessage.messageBody
                val sender = smsMessage.originatingAddress
                val timestamp = smsMessage.timestampMillis
                
                // Store SMS in SharedPreferences for processing when app opens
                // This is a simple approach - you can use a database instead
                saveSmsForProcessing(context, messageBody, sender, timestamp)
            }
        }
    }
    
    private fun saveSmsForProcessing(
        context: Context,
        body: String?,
        sender: String?,
        timestamp: Long
    ) {
        val prefs: SharedPreferences = context.getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        // Store SMS data (you can improve this with a proper queue/database)
        val key = "sms_$timestamp"
        val smsData = "$sender|$body|$timestamp"
        editor.putString(key, smsData)
        editor.apply()
    }
}
