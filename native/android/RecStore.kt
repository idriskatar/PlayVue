package com.playvue.playvue

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import org.json.JSONObject
import java.io.File

/** Kayıt görevlerini SharedPreferences'ta tutar ve AlarmManager ile zamanlar. */
object RecStore {
    private const val PREFS = "playvue_rec"
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun put(c: Context, t: JSONObject) {
        prefs(c).edit().putString("t_" + t.getString("id"), t.toString()).apply()
    }

    @Synchronized
    fun get(c: Context, id: String): JSONObject? =
        prefs(c).getString("t_$id", null)?.let { JSONObject(it) }

    @Synchronized
    fun all(c: Context): List<JSONObject> =
        prefs(c).all.filterKeys { it.startsWith("t_") }.values
            .mapNotNull { (it as? String)?.let { s -> JSONObject(s) } }

    @Synchronized
    fun remove(c: Context, id: String) {
        prefs(c).edit().remove("t_$id").apply()
    }

    @Synchronized
    fun update(c: Context, id: String, block: (JSONObject) -> Unit) {
        get(c, id)?.let { block(it); put(c, it) }
    }

    fun dir(c: Context): File {
        val base = c.getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: c.filesDir
        val d = File(base, "PlayVue")
        d.mkdirs()
        return d
    }

    private fun pending(c: Context, id: String): PendingIntent {
        val i = Intent(c, AlarmReceiver::class.java)
            .setAction("com.playvue.START_REC")
            .putExtra("id", id)
        return PendingIntent.getBroadcast(
            c, id.hashCode(), i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun schedule(c: Context, id: String) {
        val t = get(c, id) ?: return
        val start = t.getLong("startMs")
        if (start <= System.currentTimeMillis() + 1500) {
            startService(c, id)
            return
        }
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(c, id)
        try {
            if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, start, pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, start, pi)
            }
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, start, pi)
        }
    }

    fun cancel(c: Context, id: String) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(c, id))
    }

    fun startService(c: Context, id: String) {
        val i = Intent(c, RecordingService::class.java)
            .setAction(RecordingService.ACTION_START)
            .putExtra("id", id)
        if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i) else c.startService(i)
    }
}
