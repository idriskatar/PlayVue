enum RecStatus { scheduled, recording, done, failed, stopped, missed }

RecStatus recStatusFrom(String? s) {
  for (final v in RecStatus.values) {
    if (v.name == s) return v;
  }
  return RecStatus.failed;
}

class RecTask {
  RecTask({
    required this.id,
    required this.channel,
    required this.url,
    this.userAgent,
    required this.startMs,
    required this.durationSec,
    this.status = RecStatus.scheduled,
    this.path,
    this.bytes = 0,
    this.error,
  });

  final String id;
  final String channel;
  final String url;
  final String? userAgent;
  final int startMs;
  final int durationSec;
  RecStatus status;
  String? path;
  int bytes;
  String? error;

  int get endMs => startMs + durationSec * 1000;

  Map<String, dynamic> toJson() => {
        'id': id,
        'channel': channel,
        'url': url,
        'userAgent': userAgent,
        'startMs': startMs,
        'durationSec': durationSec,
        'status': status.name,
        'path': path,
        'bytes': bytes,
        'error': error,
      };

  factory RecTask.fromJson(Map<String, dynamic> j) => RecTask(
        id: j['id'] as String,
        channel: j['channel'] as String,
        url: j['url'] as String,
        userAgent: j['userAgent'] as String?,
        startMs: (j['startMs'] as num).toInt(),
        durationSec: (j['durationSec'] as num).toInt(),
        status: recStatusFrom(j['status'] as String?),
        path: j['path'] as String?,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        error: j['error'] as String?,
      );
}
