import 'package:flutter/services.dart';

import '../models/recording.dart';

/// Android: kayıt ve zamanlama native (AlarmManager + Foreground Service) çalışır.
class NativeRecorder {
  static const _ch = MethodChannel('playvue/recorder');

  static Future<void> schedule(RecTask t) => _ch.invokeMethod('schedule', {
        'id': t.id,
        'name': t.channel,
        'url': t.url,
        'ua': t.userAgent ?? '',
        'startMs': t.startMs,
        'durationSec': t.durationSec,
      });

  static Future<void> stop(String id) => _ch.invokeMethod('stop', {'id': id});
  static Future<void> remove(String id) => _ch.invokeMethod('remove', {'id': id});

  static Future<String> dir() async => (await _ch.invokeMethod<String>('dir')) ?? '';

  static Future<Map<String, Map<String, dynamic>>> states() async {
    final raw = await _ch.invokeMethod<Map>('states');
    final out = <String, Map<String, dynamic>>{};
    raw?.forEach((k, v) => out['$k'] = Map<String, dynamic>.from(v as Map));
    return out;
  }

  static Future<void> requestNotifications() => _ch.invokeMethod('requestNotifications');
  static Future<bool> canExact() async => (await _ch.invokeMethod<bool>('canExact')) ?? true;
  static Future<void> requestExact() => _ch.invokeMethod('requestExact');
  static Future<bool> ignoringBattery() async =>
      (await _ch.invokeMethod<bool>('ignoringBattery')) ?? false;
  static Future<void> requestBattery() => _ch.invokeMethod('requestBattery');
}
