import 'dart:convert';
import 'dart:io';

class Channel {
  final String name;
  final String url;
  final String? tvgId;
  final String? tvgName;
  final String? logo;
  final String group;
  final Map<String, String> headers;

  const Channel({
    required this.name,
    required this.url,
    this.tvgId,
    this.tvgName,
    this.logo,
    this.group = 'Diğer',
    this.headers = const {},
  });

  String get key => url;
}

class ParsedPlaylist {
  final List<Channel> channels;
  final String? epgUrl;
  const ParsedPlaylist(this.channels, this.epgUrl);
}

final _attrRe = RegExp(r'([\w-]+)="([^"]*)"');

/// Isolate içinde çalıştırmak için (compute ile): dosyadan okuyup ayrıştırır.
ParsedPlaylist parseM3uFile(String path) {
  final bytes = File(path).readAsBytesSync();
  return parseM3u(utf8.decode(bytes, allowMalformed: true));
}

ParsedPlaylist parseM3u(String content) {
  final channels = <Channel>[];
  String? epgUrl;

  Map<String, String>? attrs;
  String? name;
  String? groupOverride;
  final headers = <String, String>{};

  for (final raw in content.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTM3U')) {
      final a = _parseAttrs(line);
      final e = a['url-tvg'] ?? a['x-tvg-url'];
      if (e != null && e.isNotEmpty) epgUrl = e.split(',').first.trim();
    } else if (line.startsWith('#EXTINF:')) {
      attrs = _parseAttrs(line);
      final commaIdx = line.lastIndexOf(',');
      name = commaIdx >= 0 ? line.substring(commaIdx + 1).trim() : null;
    } else if (line.startsWith('#EXTGRP:')) {
      groupOverride = line.substring(8).trim();
    } else if (line.startsWith('#EXTVLCOPT:')) {
      final kv = line.substring(11);
      final eq = kv.indexOf('=');
      if (eq > 0) {
        final key = kv.substring(0, eq).toLowerCase();
        final val = kv.substring(eq + 1);
        if (key == 'http-user-agent') headers['User-Agent'] = val;
        if (key == 'http-referrer') headers['Referer'] = val;
      }
    } else if (!line.startsWith('#')) {
      if (attrs != null) {
        final a = attrs;
        channels.add(Channel(
          name: (name != null && name.isNotEmpty) ? name : (a['tvg-name'] ?? line),
          url: line,
          tvgId: _nonEmpty(a['tvg-id']),
          tvgName: _nonEmpty(a['tvg-name']),
          logo: _nonEmpty(a['tvg-logo']),
          group: _nonEmpty(a['group-title']) ?? groupOverride ?? 'Diğer',
          headers: Map.of(headers),
        ));
      }
      attrs = null;
      name = null;
      groupOverride = null;
      headers.clear();
    }
  }
  return ParsedPlaylist(channels, epgUrl);
}

Map<String, String> _parseAttrs(String line) => {
      for (final m in _attrRe.allMatches(line)) m.group(1)!: m.group(2)!,
    };

String? _nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
