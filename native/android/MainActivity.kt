package com.playvue.playvue

import android.Manifest
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "playvue/recorder")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "schedule" -> {
                            val id = call.argument<String>("id")!!
                            val t = JSONObject()
                            t.put("id", id)
                            t.put("name", call.argument<String>("name") ?: "kanal")
                            t.put("url", call.argument<String>("url"))
                            t.put("ua", call.argument<String>("ua") ?: "")
                            t.put("startMs", call.argument<Number>("startMs")!!.toLong())
                            t.put("durationSec", call.argument<Number>("durationSec")!!.toLong())
                            t.put("state", "scheduled")
                            t.put("bytes", 0)
                            RecStore.put(this, t)
                            RecStore.schedule(this, id)
                            result.success(null)
                        }
                        "stop" -> {
                            val id = call.argument<String>("id")!!
                            RecStore.cancel(this, id)
                            val st = RecStore.get(this, id)?.optString("state")
                            if (st == "scheduled") {
                                RecStore.update(this, id) { it.put("state", "stopped") }
                            } else if (RecordingService.active.contains(id)) {
                                startService(
                                    Intent(this, RecordingService::class.java)
                                        .setAction(RecordingService.ACTION_STOP)
                                        .putExtra("id", id)
                                )
                            }
                            result.success(null)
                        }
                        "remove" -> {
                            val id = call.argument<String>("id")!!
                            RecStore.cancel(this, id)
                            RecStore.remove(this, id)
                            result.success(null)
                        }
                        "states" -> {
                            val out = HashMap<String, Any>()
                            for (t in RecStore.all(this)) {
                                val id = t.getString("id")
                                var st = t.optString("state")
                                if (st == "recording" && !RecordingService.active.contains(id)) {
                                    st = "stopped"
                                    RecStore.update(this, id) { it.put("state", "stopped") }
                                }
                                out[id] = hashMapOf(
                                    "state" to st,
                                    "path" to t.optString("path"),
                                    "bytes" to t.optLong("bytes"),
                                    "error" to t.optString("error")
                                )
                            }
                            result.success(out)
                        }
                        "dir" -> result.success(RecStore.dir(this).absolutePath)
                        "requestNotifications" -> {
                            if (Build.VERSION.SDK_INT >= 33 &&
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                                != PackageManager.PERMISSION_GRANTED
                            ) {
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 77)
                            }
                            result.success(null)
                        }
                        "canExact" -> {
                            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            result.success(Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms())
                        }
                        "requestExact" -> {
                            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                                startActivity(
                                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                        Uri.parse("package:$packageName"))
                                )
                            }
                            result.success(null)
                        }
                        "ignoringBattery" -> {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        }
                        "requestBattery" -> {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                startActivity(
                                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                        Uri.parse("package:$packageName"))
                                )
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ERR", e.message, null)
                }
            }
    }
}
