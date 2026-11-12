import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/util.dart';
import '../core/theme.dart';
import '../models/playlist.dart';
import '../state/app_state.dart';
import 'add_playlist_screen.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  IconData _icon(PlaylistType t) => switch (t) {
        PlaylistType.url => Icons.link,
        PlaylistType.file => Icons.insert_drive_file_outlined,
        PlaylistType.xtream => Icons.dns_outlined,
      };

  Future<void> _rename(BuildContext context, AppState s, PlaylistInfo p) async {
    final ctrl = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeniden adlandır'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await s.renamePlaylist(p, name);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Playlistler')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ekle'),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddPlaylistScreen())),
      ),
      body: s.playlists.isEmpty
          ? const Center(child: Text('Playlist yok', style: TextStyle(color: PV.textDim)))
          : ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                for (final p in s.playlists)
                  ListTile(
                    leading: Icon(_icon(p.type)),
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.channelCount} kanal'
                      '${p.lastUpdated > 0 ? '  •  ${fmtDateTime(p.lastUpdated)}' : ''}'
                      '${p.id == s.activeId ? '  •  Aktif' : ''}',
                    ),
                    onTap: () => s.setActive(p.id),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'refresh') s.refreshPlaylist(p);
                        if (v == 'rename') _rename(context, s, p);
                        if (v == 'delete') s.removePlaylist(p);
                      },
                      itemBuilder: (_) => [
                        if (p.type != PlaylistType.file)
                          const PopupMenuItem(value: 'refresh', child: Text('Şimdi güncelle')),
                        const PopupMenuItem(value: 'rename', child: Text('Yeniden adlandır')),
                        const PopupMenuItem(value: 'delete', child: Text('Sil')),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
