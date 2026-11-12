package com.playvue.playvue

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Cihaz yeniden başlayınca bekleyen kayıt alarmlarını yeniden kurar. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        val now = System.currentTimeMillis()
        for (t in RecStore.all(c)) {
            val id = t.getString("id")
            val st = t.optString("state")
            val end = t.getLong("startMs") + t.getLong("durationSec") * 1000
            if (st == "scheduled") {
                if (end <= now) {
                    RecStore.update(c, id) { it.put("state", "missed") }
                } else {
                    try {
                        RecStore.schedule(c, id)
                    } catch (e: Exception) {
                    }
                }
            } else if (st == "recording") {
                RecStore.update(c, id) { it.put("state", "stopped") }
            }
        }
    }
}
