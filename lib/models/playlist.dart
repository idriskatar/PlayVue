enum PlaylistType { url, file, xtream }

class PlaylistInfo {
  PlaylistInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.source,
    this.username,
    this.password,
    this.epgUrl,
    this.updateHours = 24,
    this.lastUpdated = 0,
    this.channelCount = 0,
  });

  final String id;
  String name;
  final PlaylistType type;
  final String source; // url / dosya adı / xtream sunucu adresi
  final String? username;
  final String? password;
  String? epgUrl;
  int updateHours; // 0 = elle
  int lastUpdated;
  int channelCount;

  String get _base => source.replaceAll(RegExp(r'/+$'), '');

  String get m3uUrl {
    if (type == PlaylistType.xtream) {
      return '$_base/get.php?username=${Uri.encodeComponent(username ?? '')}'
          '&password=${Uri.encodeComponent(password ?? '')}&type=m3u_plus&output=ts';
    }
    return source;
  }

  String? get xtreamEpgUrl => type == PlaylistType.xtream
      ? '$_base/xmltv.php?username=${Uri.encodeComponent(username ?? '')}'
          '&password=${Uri.encodeComponent(password ?? '')}'
      : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'source': source,
        'username': username,
        'password': password,
        'epgUrl': epgUrl,
        'updateHours': updateHours,
        'lastUpdated': lastUpdated,
        'channelCount': channelCount,
      };

  factory PlaylistInfo.fromJson(Map<String, dynamic> j) => PlaylistInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        type: PlaylistType.values.byName(j['type'] as String),
        source: j['source'] as String,
        username: j['username'] as String?,
        password: j['password'] as String?,
        epgUrl: j['epgUrl'] as String?,
        updateHours: (j['updateHours'] as num?)?.toInt() ?? 24,
        lastUpdated: (j['lastUpdated'] as num?)?.toInt() ?? 0,
        channelCount: (j['channelCount'] as num?)?.toInt() ?? 0,
      );
}
