import 'dart:convert';
import 'dart:io';

class Programme {
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? desc;
  const Programme(this.start, this.stop, this.title, this.desc);
}

/// XMLTV (.xml / .xml.gz) dosyasını Isolate içinde ayrıştırır.
/// Anahtar: kanal id'si (küçük harf).
Map<String, List<Programme>> parseXmltvFile(String path) {
  List<int> bytes = File(path).readAsBytesSync();
  if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    bytes = gzip.decode(bytes);
  }
  final text = utf8.decode(bytes, allowMalformed: true);
  final now = DateTime.now().toUtc();
  final from = now.subtract(const Duration(hours: 2));
  final to = now.add(const Duration(hours: 36));

  final out = <String, List<Programme>>{};
  final re = RegExp(r'<programme\s([^>]*)>(.*?)</programme>', dotAll: true);
  final attr = RegExp(r'(\w+)="([^"]*)"');
  final titleRe = RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true);
  final descRe = RegExp(r'<desc[^>]*>(.*?)</desc>', dotAll: true);

  for (final m in re.allMatches(text)) {
    final a = {
      for (final x in attr.allMatches(m.group(1)!)) x.group(1)!: x.group(2)!,
    };
    final s = _parseTime(a['start']);
    final e = _parseTime(a['stop']);
    final ch = a['channel'];
    if (s == null || e == null || ch == null) continue;
    if (e.isBefore(from) || s.isAfter(to)) continue;
    final body = m.group(2)!;
    final title = _unescape(titleRe.firstMatch(body)?.group(1) ?? '');
    final desc = descRe.firstMatch(body)?.group(1);
    (out[ch.toLowerCase()] ??= []).add(
      Programme(s, e, title, desc == null ? null : _unescape(desc)),
    );
  }
  for (final l in out.values) {
    l.sort((a, b) => a.start.compareTo(b.start));
  }
  return out;
}

DateTime? _parseTime(String? raw) {
  if (raw == null) return null;
  final s = raw.replaceAll(' ', '');
  if (s.length < 14) return null;
  try {
    var dt = DateTime.utc(
      int.parse(s.substring(0, 4)),
      int.parse(s.substring(4, 6)),
      int.parse(s.substring(6, 8)),
      int.parse(s.substring(8, 10)),
      int.parse(s.substring(10, 12)),
      int.parse(s.substring(12, 14)),
    );
    if (s.length >= 19) {
      final sign = s[14] == '-' ? -1 : 1;
      final oh = int.parse(s.substring(15, 17));
      final om = int.parse(s.substring(17, 19));
      dt = dt.subtract(Duration(minutes: sign * (oh * 60 + om)));
    }
    return dt;
  } catch (_) {
    return null;
  }
}

String _unescape(String s) => s
    .replaceAll('<![CDATA[', '')
    .replaceAll(']]>', '')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .trim();
