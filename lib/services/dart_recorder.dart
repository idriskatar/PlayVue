import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// iOS (ve masaüstü) için Dart tabanlı kaydedici. Uygulama çalışırken kayıt yapar.
/// Ham TS akışı ve şifresiz HLS (TS segment) desteklenir.
class DartRecorder {
  DartRecorder({
    required this.url,
    this.ua,
    required this.file,
    required this.endMs,
    required this.onBytes,
  });

  final String url;
  final String? ua;
  final File file;
  final int endMs;
  final void Function(int bytes) onBytes;

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);
  bool _stop = false;
  bool _finished = false;
  bool stoppedByUser = false;
  int bytes = 0;
  String? error;
  Uri _final = Uri();

  bool get _done => _stop || DateTime.now().millisecondsSinceEpoch >= endMs;

  void stop() {
    stoppedByUser = true;
    _stop = true;
  }

  Future<HttpClientResponse> _open(String u) async {
    var uri = Uri.parse(u);
    for (var i = 0; i < 6; i++) {
      final req = await _client.getUrl(uri);
      req.headers.set('User-Agent', ua ?? 'Mozilla/5.0 PlayVue');
      req.followRedirects = false;
      final res = await req.close();
      if (res.isRedirect) {
        final loc = res.headers.value('location');
        await res.drain<void>();
        if (loc == null) break;
        uri = uri.resolve(loc);
        continue;
      }
      if (res.statusCode >= 400) {
        await res.drain<void>();
        throw Exception('HTTP ${res.statusCode}');
      }
      _final = uri;
      return res;
    }
    throw Exception('Yönlendirme hatası');
  }

  bool _isM3u(List<int> chunk) =>
      chunk.length >= 7 &&
      utf8.decode(chunk.sublist(0, 7), allowMalformed: true) == '#EXTM3U';

  Future<void> run() async {
    final sink = file.openWrite(mode: FileMode.append);
    try {
      while (!_done && !_finished) {
        try {
          final res = await _open(url);
          var first = true;
          var hls = false;
          final textBuf = <int>[];
          await for (final chunk in res.timeout(const Duration(seconds: 20))) {
            if (first) {
              first = false;
              hls = _isM3u(chunk);
            }
            if (hls) {
              textBuf.addAll(chunk);
              continue;
            }
            if (_done) break;
            sink.add(chunk);
            bytes += chunk.length;
            onBytes(bytes);
          }
          if (hls) {
            await _hls(_final.toString(), utf8.decode(textBuf, allowMalformed: true), sink);
          } else if (res.contentLength > 0) {
            _finished = true; // sonlu dosya (VOD)
          }
        } catch (e) {
          if (_done) break;
          error = '$e';
        }
        if (!_done && !_finished) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      await sink.close();
      _client.close(force: true);
    }
  }

  Future<String> _text(String u) async {
    final res = await _open(u);
    return utf8.decodeStream(res);
  }

  Future<void> _hls(String start, String? firstText, IOSink sink) async {
    var plUrl = start;
    var text = firstText;
    final seen = <String>[];
    while (!_done) {
      final body = text ?? await _text(plUrl);
      text = null;
      final lines = body
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (lines.any((l) => l.startsWith('#EXT-X-STREAM-INF'))) {
        var best = -1;
        String? bestUri;
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].startsWith('#EXT-X-STREAM-INF')) continue;
          final bw = int.tryParse(
                  RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i])?.group(1) ?? '') ??
              0;
          String? uri;
          for (var j = i + 1; j < lines.length; j++) {
            if (!lines[j].startsWith('#')) {
              uri = lines[j];
              break;
            }
          }
          if (uri != null && bw >= best) {
            best = bw;
            bestUri = uri;
          }
        }
        if (bestUri == null) throw Exception('HLS varyantı bulunamadı');
        plUrl = Uri.parse(plUrl).resolve(bestUri).toString();
        continue;
      }
      if (lines.any((l) => l.startsWith('#EXT-X-KEY') && !l.contains('METHOD=NONE'))) {
        throw Exception('Şifreli HLS desteklenmiyor');
      }
      if (lines.any((l) => l.startsWith('#EXT-X-MAP'))) {
        throw Exception('fMP4 HLS desteklenmiyor');
      }

      var target = 4.0;
      for (final l in lines) {
        if (l.startsWith('#EXT-X-TARGETDURATION')) {
          target = double.tryParse(l.split(':').last.trim()) ?? 4.0;
        }
      }
      for (final l in lines) {
        if (l.startsWith('#')) continue;
        final seg = Uri.parse(plUrl).resolve(l).toString();
        if (seen.contains(seg)) continue;
        if (_done) break;
        await _seg(seg, sink);
        seen.add(seg);
        if (seen.length > 500) seen.removeAt(0);
      }
      if (lines.contains('#EXT-X-ENDLIST')) {
        _finished = true;
        return;
      }
      final waitMs = max(1000, (target * 500).round());
      var w = 0;
      while (w < waitMs && !_done) {
        await Future.delayed(const Duration(milliseconds: 200));
        w += 200;
      }
    }
  }

  Future<void> _seg(String u, IOSink sink) async {
    try {
      final res = await _open(u);
      await for (final c in res.timeout(const Duration(seconds: 20))) {
        if (_done) break;
        sink.add(c);
        bytes += c.length;
        onBytes(bytes);
      }
    } catch (e) {
      error = '$e';
    }
  }
}
