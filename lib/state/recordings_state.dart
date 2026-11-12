import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording.dart';
import '../services/dart_recorder.dart';
import '../services/native_recorder.dart';

class RecordingsState extends ChangeNotifier {
  late SharedPreferences _prefs;
  final List<RecTask> tasks = [];
  String recDir = '';
  final Map<String, DartRecorder> _active = {};
  Timer? _timer;

  bool get native => Platform.isAndroid;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('rec_tasks');
    if (raw != null) {
      try {
        tasks.addAll((jsonDecode(raw) as List)
            .map((e) => RecTask.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {}
    }
    if (native) {
      try {
        recDir = await NativeRecorder.dir();
      } catch (_) {}
      await refresh();
    } else {
      final d = await getApplicationDocumentsDirectory();
      final dir = Directory('${d.path}/Recordings');
      await dir.create(recursive: true);
      recDir = dir.path;
      for (final t in tasks) {
        if (t.status == RecStatus.recording) t.status = RecStatus.stopped;
      }
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
      _tick();
    }
  }

  Future<void> _persist() => _prefs.setString(
      'rec_tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));

  Future<void> ensurePermissions() async {
    if (!native) return;
    try {
      await NativeRecorder.requestNotifications();
      if (!await NativeRecorder.canExact()) await NativeRecorder.requestExact();
    } catch (_) {}
  }

  Future<void> add({
    required String channel,
    required String url,
    String? userAgent,
    required DateTime start,
    required int minutes,
  }) async {
    final t = RecTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      channel: channel,
      url: url,
      userAgent: userAgent,
      startMs: start.millisecondsSinceEpoch,
      durationSec: minutes * 60,
    );
    tasks.add(t);
    await _persist();
    if (native) {
      await NativeRecorder.schedule(t);
      await refresh();
    } else {
      _tick();
    }
    notifyListeners();
  }

  Future<void> stop(RecTask t) async {
    if (native) {
      await NativeRecorder.stop(t.id);
      await Future.delayed(const Duration(milliseconds: 400));
      await refresh();
    } else {
      if (t.status == RecStatus.scheduled) {
        t.status = RecStatus.stopped;
      }
      _active[t.id]?.stop();
      await _persist();
      notifyListeners();
    }
  }

  Future<void> delete(RecTask t, {bool deleteFile = false}) async {
    await stop(t);
    if (native) {
      try {
        await NativeRecorder.remove(t.id);
      } catch (_) {}
    }
    if (deleteFile && t.path != null) {
      try {
        await File(t.path!).delete();
      } catch (_) {}
    }
    tasks.removeWhere((e) => e.id == t.id);
    await _persist();
    notifyListeners();
  }

  /// Android: native durumları çeker. iOS: sadece arayüzü tazeler.
  Future<void> refresh() async {
    var changed = false;
    if (native) {
      try {
        final st = await NativeRecorder.states();
        for (final t in tasks) {
          final s = st[t.id];
          if (s == null) continue;
          final ns = recStatusFrom(s['state'] as String?);
          final np = (s['path'] as String?) ?? t.path;
          final nb = (s['bytes'] as num?)?.toInt() ?? t.bytes;
          final ne = s['error'] as String?;
          if (ns != t.status || np != t.path || nb != t.bytes) {
            t.status = ns;
            t.path = (np != null && np.isNotEmpty) ? np : t.path;
            t.bytes = nb;
            t.error = (ne != null && ne.isNotEmpty) ? ne : null;
            changed = true;
          }
        }
      } catch (_) {}
    } else {
      changed = _active.isNotEmpty;
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ iOS zamanlama

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final t in tasks) {
      if (t.status != RecStatus.scheduled || t.startMs > now) continue;
      if (now >= t.endMs) {
        t.status = RecStatus.missed;
        changed = true;
      } else {
        _startDart(t);
        changed = true;
      }
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  void _startDart(RecTask t) {
    final safe = t.channel.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    final d = DateTime.fromMillisecondsSinceEpoch(t.startMs);
    final stamp =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}_${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';
    final file = File('$recDir/${safe}_$stamp.ts');
    t.path = file.path;
    t.status = RecStatus.recording;
    final r = DartRecorder(
      url: t.url,
      ua: t.userAgent,
      file: file,
      endMs: t.endMs,
      onBytes: (b) => t.bytes = b,
    );
    _active[t.id] = r;
    r.run().then((_) {
      if (r.stoppedByUser) {
        t.status = RecStatus.stopped;
      } else if (r.bytes == 0) {
        t.status = RecStatus.failed;
        t.error = r.error ?? 'Veri alınamadı';
      } else {
        t.status = RecStatus.done;
      }
    }).catchError((Object e) {
      t.status = RecStatus.failed;
      t.error = '$e';
    }).whenComplete(() {
      _active.remove(t.id);
      _persist();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
