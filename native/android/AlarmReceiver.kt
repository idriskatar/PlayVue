package com.playvue.playvue

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        val id = i.getStringExtra("id") ?: return
        try {
            RecStore.startService(c, id)
        } catch (e: Exception) {
            RecStore.update(c, id) {
                it.put("state", "failed")
                it.put("error", "Servis başlatılamadı: ${e.message}")
            }
        }
    }
}
