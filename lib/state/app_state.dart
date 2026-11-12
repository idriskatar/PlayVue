import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/epg.dart';
import '../core/m3u_parser.dart';
import '../models/playlist.dart';

class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;
  late Directory _dir;

  List<PlaylistInfo> playlists = [];
  String? activeId;
  List<Channel> channels = const [];
  List<String> groups = const [];
  Set<String> favorites = {};
  bool loading = false;
  String? error;
  Map<String, List<Programme>> _epg = {};

  // Multiview
  final List<Channel?> mvSlots = List<Channel?>.filled(4, null);
  int mvCount = 4;

  PlaylistInfo? get active {
    for (final p in playlists) {
      if (p.id == activeId) return p;
    }
    return null;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _dir = await getApplicationDocumentsDirectory();
    final raw = _prefs.getString('playlists');
    if (raw != null) {
      try {
        playlists = (jsonDecode(raw) as List)
            .map((e) => PlaylistInfo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    activeId = _prefs.getString('activeId');
    if (active == null && playlists.isNotEmpty) activeId = playlists.first.id;
    favorites = (_prefs.getStringList('favs') ?? const []).toSet();
    mvCount = _prefs.getInt('mvCount') ?? 4;
    await _loadActive();
    _autoUpdate();
  }

  File _file(String id) => File('${_dir.path}/pl_$id.m3u');

  Future<void> _save() async {
    await _prefs.setString(
        'playlists', jsonEncode(playlists.map((e) => e.toJson()).toList()));
    if (activeId != null) await _prefs.setString('activeId', activeId!);
  }

  // ---------------------------------------------------------------- playlist

  Future<void> addPlaylist(PlaylistInfo p, {String? filePath}) async {
    loading = true;
    error = null;
    notifyListeners();
    final tmp = File('${_file(p.id).path}.tmp');
    try {
      if (p.type == PlaylistType.file) {
        await File(filePath!).copy(tmp.path);
      } else {
        await _downloadTo(p, tmp);
      }
      final r = await compute(parseM3uFile, tmp.path);
      if (r.channels.isEmpty) {
        await tmp.delete();
        throw Exception('Listede kanal bulunamadı. Geçerli bir M3U listesi mi?');
      }
      await tmp.rename(_file(p.id).path);
      p.lastUpdated = DateTime.now().millisecondsSinceEpoch;
      p.channelCount = r.channels.length;
      playlists.add(p);
      activeId = p.id;
      await _save();
      _apply(r, p);
    } catch (e) {
      loading = false;
      error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshPlaylist(PlaylistInfo p) async {
    if (p.type == PlaylistType.file) return;
    final isActive = p.id == activeId;
    if (isActive) {
      loading = true;
      notifyListeners();
    }
    final tmp = File('${_file(p.id).path}.tmp');
    try {
      await _downloadTo(p, tmp);
      final r = await compute(parseM3uFile, tmp.path);
      if (r.channels.isEmpty) {
        await tmp.delete();
        throw Exception('Liste boş döndü');
      }
      await tmp.rename(_file(p.id).path);
      p.lastUpdated = DateTime.now().millisecondsSinceEpoch;
      p.channelCount = r.channels.length;
      await _save();
      if (isActive) {
        _apply(r, p);
      } else {
        notifyListeners();
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      loading = false;
      notifyListeners();
    }
  }

  Future<void> renamePlaylist(PlaylistInfo p, String name) async {
    p.name = name;
    await _save();
    notifyListeners();
  }

  Future<void> removePlaylist(PlaylistInfo p) async {
    playlists.removeWhere((e) => e.id == p.id);
    try {
      await _file(p.id).delete();
    } catch (_) {}
    if (activeId == p.id) {
      activeId = playlists.isEmpty ? null : playlists.first.id;
    }
    await _save();
    await _loadActive();
  }

  Future<void> setActive(String id) async {
    if (activeId == id) return;
    activeId = id;
    await _save();
    await _loadActive();
  }

  Future<void> _downloadTo(PlaylistInfo p, File target) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(p.m3uUrl))
        ..headers['User-Agent'] = 'Mozilla/5.0 PlayVue';
      final res = await client.send(req).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw Exception('Sunucu hatası: ${res.statusCode}');
      }
      final sink = target.openWrite();
      await res.stream.pipe(sink);
    } finally {
      client.close();
    }
  }

  Future<void> _loadActive() async {
    final p = active;
    if (p == null) {
      channels = const [];
      groups = const [];
      _epg = {};
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    final f = _file(p.id);
    if (!f.existsSync()) {
      await refreshPlaylist(p);
      return;
    }
    try {
      final r = await compute(parseM3uFile, f.path);
      _apply(r, p);
    } catch (e) {
      loading = false;
      error = 'Liste okunamadı: $e';
      notifyListeners();
    }
  }

  void _apply(ParsedPlaylist r, PlaylistInfo p) {
    channels = r.channels;
    final g = <String>{};
    for (final c in r.channels) {
      g.add(c.group);
    }
    groups = g.toList();
    _epg = {};
    loading = false;
    notifyListeners();
    _loadEpg(p, r.epgUrl);
  }

  void _autoUpdate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in List.of(playlists)) {
      if (p.type == PlaylistType.file || p.updateHours <= 0) continue;
      if (now - p.lastUpdated > p.updateHours * 3600 * 1000) {
        unawaited(refreshPlaylist(p));
      }
    }
  }

  // --------------------------------------------------------------------- EPG

  Future<void> _loadEpg(PlaylistInfo p, String? headerUrl) async {
    final url = (p.epgUrl != null && p.epgUrl!.isNotEmpty)
        ? p.epgUrl
        : (p.xtreamEpgUrl ?? headerUrl);
    if (url == null) return;
    try {
      final f = File('${_dir.path}/epg_${p.id}.bin');
      final stale = !f.existsSync() ||
          DateTime.now().difference(f.lastModifiedSync()) >
              const Duration(hours: 12);
      if (stale) {
        final res = await http
            .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0 PlayVue'})
            .timeout(const Duration(seconds: 120));
        if (res.statusCode == 200) await f.writeAsBytes(res.bodyBytes);
      }
      if (f.existsSync() && p.id == activeId) {
        _epg = await compute(parseXmltvFile, f.path);
        notifyListeners();
      }
    } catch (_) {
      // EPG isteğe bağlı; sessizce geç.
    }
  }

  List<Programme>? _epgOf(Channel c) =>
      _epg[(c.tvgId ?? c.name).toLowerCase()] ?? _epg[c.name.toLowerCase()];

  Programme? nowOf(Channel c) {
    final l = _epgOf(c);
    if (l == null) return null;
    final n = DateTime.now();
    for (final p in l) {
      if (!p.start.isAfter(n) && p.stop.isAfter(n)) return p;
    }
    return null;
  }

  Programme? nextOf(Channel c) {
    final l = _epgOf(c);
    if (l == null) return null;
    final n = DateTime.now();
    for (final p in l) {
      if (p.start.isAfter(n)) return p;
    }
    return null;
  }

  // --------------------------------------------------------------- favorites

  bool isFav(Channel c) => favorites.contains(c.key);

  Future<void> toggleFav(Channel c) async {
    if (!favorites.remove(c.key)) favorites.add(c.key);
    await _prefs.setStringList('favs', favorites.toList());
    notifyListeners();
  }

  // --------------------------------------------------------------- multiview

  Future<void> setMvCount(int n) async {
    mvCount = n;
    await _prefs.setInt('mvCount', n);
    notifyListeners();
  }

  void setMvSlot(int i, Channel? c) {
    mvSlots[i] = c;
    notifyListeners();
  }

  /// Boş ilk yuvaya ekler; hepsi doluysa son yuvanın yerine koyar.
  int addToMultiview(Channel c) {
    var idx = -1;
    for (var i = 0; i < mvCount; i++) {
      if (mvSlots[i] == null) {
        idx = i;
        break;
      }
    }
    if (idx < 0) idx = mvCount - 1;
    mvSlots[idx] = c;
    notifyListeners();
    return idx;
  }

  void clearMultiview() {
    for (var i = 0; i < mvSlots.length; i++) {
      mvSlots[i] = null;
    }
    notifyListeners();
  }
}
