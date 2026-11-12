package com.playvue.playvue

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

class RecordingService : Service() {
    companion object {
        const val ACTION_START = "com.playvue.rec.START"
        const val ACTION_STOP = "com.playvue.rec.STOP"
        const val CHANNEL = "playvue_rec"
        const val NOTIF_ID = 4101
        val active: MutableSet<String> = ConcurrentHashMap.newKeySet<String>()
    }

    private val workers = ConcurrentHashMap<String, Recorder>()
    private val main = Handler(Looper.getMainLooper())
    private var wl: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Kayıtlar", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "playvue:recording")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        promote()
        val id = intent?.getStringExtra("id")
        when (intent?.action) {
            ACTION_START -> if (id != null) begin(id)
            ACTION_STOP -> {
                if (id != null) workers[id]?.stop() else workers.values.forEach { it.stop() }
            }
        }
        if (workers.isEmpty()) finishIfIdle()
        return START_NOT_STICKY
    }

    private fun notif(): Notification {
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
        else Notification.Builder(this)
        val n = workers.size
        b.setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("PlayVue")
            .setContentText(if (n > 0) "$n kayıt sürüyor" else "Kayıt hazırlanıyor")
            .setOngoing(true)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            b.setContentIntent(
                PendingIntent.getActivity(
                    this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
        }
        val stop = Intent(this, RecordingService::class.java).setAction(ACTION_STOP)
        b.addAction(
            android.R.drawable.ic_media_pause, "Tümünü durdur",
            PendingIntent.getService(
                this, 1, stop, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        )
        return b.build()
    }

    private fun promote() {
        val n = notif()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun begin(id: String) {
        if (workers.containsKey(id)) return
        val t = RecStore.get(this, id) ?: return
        val end = t.getLong("startMs") + t.getLong("durationSec") * 1000
        if (System.currentTimeMillis() >= end) {
            RecStore.update(this, id) { it.put("state", "missed") }
            return
        }
        val name = t.optString("name", "kanal").replace(Regex("[\\\\/:*?\"<>|\\s]+"), "_")
        val stamp = SimpleDateFormat("yyyyMMdd_HHmm", Locale.US).format(Date(t.getLong("startMs")))
        val file = File(RecStore.dir(this), "${name}_$stamp.ts")
        val ua = t.optString("ua").ifEmpty { null }

        RecStore.update(this, id) {
            it.put("state", "recording")
            it.put("path", file.absolutePath)
            it.put("bytes", 0)
            it.put("error", "")
        }

        var lastWrite = 0L
        val rec = Recorder(t.getString("url"), ua, file, end) { b ->
            val now = System.currentTimeMillis()
            if (now - lastWrite > 2000) {
                lastWrite = now
                RecStore.update(this, id) { it.put("bytes", b) }
            }
        }
        workers[id] = rec
        active.add(id)
        if (wl?.isHeld == false) wl?.acquire(6 * 60 * 60 * 1000L)
        updateNotif()

        Thread {
            var state = "done"
            var err = ""
            try {
                rec.run()
                if (rec.stoppedByUser) state = "stopped"
                if (rec.bytes == 0L && !rec.stoppedByUser) {
                    state = "failed"
                    err = rec.error ?: "Veri alınamadı"
                }
            } catch (e: Exception) {
                state = "failed"
                err = e.message ?: "Bilinmeyen hata"
            }
            RecStore.update(this@RecordingService, id) {
                it.put("state", state)
                it.put("bytes", rec.bytes)
                it.put("error", err)
            }
            workers.remove(id)
            active.remove(id)
            main.post {
                if (workers.isEmpty()) finishIfIdle() else updateNotif()
            }
        }.start()
    }

    private fun updateNotif() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, notif())
    }

    @Suppress("DEPRECATION")
    private fun finishIfIdle() {
        if (wl?.isHeld == true) wl?.release()
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        workers.values.forEach { it.stop() }
        if (wl?.isHeld == true) wl?.release()
        super.onDestroy()
    }
}
