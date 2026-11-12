import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/native_recorder.dart';
import '../state/app_state.dart';
import '../state/recordings_state.dart';
import 'playlists_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _battery;
  bool? _exact;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!Platform.isAndroid) return;
    try {
      final b = await NativeRecorder.ignoringBattery();
      final e = await NativeRecorder.canExact();
      if (mounted) setState(() {
        _battery = b;
        _exact = e;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final rec = context.watch<RecordingsState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.playlist_play),
          title: const Text('Playlistler'),
          subtitle: Text('${s.playlists.length} liste'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const PlaylistsScreen())),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('KAYIT', style: TextStyle(color: PV.accent, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Kayıt klasörü'),
          subtitle: Text(rec.recDir.isEmpty ? '-' : rec.recDir),
        ),
        if (Platform.isAndroid) ...[
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Bildirim izni'),
            subtitle: const Text('Kayıt bildirimini göstermek için gerekli'),
            onTap: () async {
              await NativeRecorder.requestNotifications();
            },
          ),
          ListTile(
            leading: Icon(Icons.alarm,
                color: _exact == false ? Colors.orange : null),
            title: const Text('Tam zamanlı alarm izni'),
            subtitle: Text(_exact == false
                ? 'Verilmedi: zamanlı kayıtlar gecikebilir. Dokunup izin ver.'
                : 'Zamanlı kayıtların tam saatinde başlaması için'),
            onTap: () async {
              await NativeRecorder.requestExact();
              await Future.delayed(const Duration(seconds: 1));
              _check();
            },
          ),
          ListTile(
            leading: Icon(Icons.battery_saver,
                color: _battery == false ? Colors.orange : null),
            title: const Text('Pil optimizasyonunu kapat'),
            subtitle: Text(_battery == false
                ? 'Önerilir: arka plan kaydı sistem tarafından öldürülmesin'
                : 'Muaf tutuldu'),
            onTap: () async {
              await NativeRecorder.requestBattery();
              await Future.delayed(const Duration(seconds: 1));
              _check();
            },
          ),
        ] else
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.amber),
            title: Text('iOS notu'),
            subtitle: Text(
                'iOS arka planda uzun süreli ağ kaydına izin vermez. Zamanlı kayıtlar için uygulama açık kalmalıdır.'),
          ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('PlayVue'),
          subtitle: Text(
              'Sürüm 1.0.0\nUygulama içerik sağlamaz; yalnızca senin eklediğin M3U kaynaklarını oynatır.'),
          isThreeLine: true,
        ),
      ]),
    );
  }
}
