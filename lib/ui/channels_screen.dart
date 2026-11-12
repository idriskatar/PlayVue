import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/m3u_parser.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'add_playlist_screen.dart';
import 'player_screen.dart';
import 'preview_pane.dart';
import 'widgets.dart';

class ChannelsScreen extends StatefulWidget {
  final bool favoritesOnly;
  const ChannelsScreen({super.key, this.favoritesOnly = false});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String _q = '';
  String? _group;
  Channel? _preview;

  List<Channel> _filter(AppState s) {
    final q = _q.toLowerCase();
    return s.channels.where((c) {
      if (widget.favoritesOnly && !s.favorites.contains(c.key)) return false;
      if (_group != null && c.group != _group) return false;
      return q.isEmpty || c.name.toLowerCase().contains(q);
    }).toList();
  }

  void _openPlaylistSwitcher(AppState s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PV.surface,
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Playlist seç',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          for (final p in s.playlists)
            ListTile(
              leading: Icon(p.id == s.activeId
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(p.name),
              subtitle: Text('${p.channelCount} kanal'),
              onTap: () {
                s.setActive(p.id);
                setState(() => _group = null);
                Navigator.pop(sheetCtx);
              },
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Yeni playlist ekle'),
            onTap: () {
              Navigator.pop(sheetCtx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddPlaylistScreen()));
            },
          ),
        ]),
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.playlist_add, size: 72, color: PV.accent),
            const SizedBox(height: 16),
            const Text('Henüz playlist yok',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'M3U adresi, dosya veya Xtream Codes bilgilerinle kendi listeni ekle.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PV.textDim),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Playlist ekle'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddPlaylistScreen())),
            ),
          ]),
        ),
      );

  Widget _search() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Kanal ara',
            isDense: true,
            filled: true,
            fillColor: PV.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
      );

  Widget _chips(AppState s) => SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Tümü'),
                selected: _group == null,
                onSelected: (_) => setState(() => _group = null),
              ),
            ),
            for (final g in s.groups)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(g),
                  selected: _group == g,
                  onSelected: (_) => setState(() => _group = g),
                ),
              ),
          ],
        ),
      );

  Widget _groupList(AppState s) => ListView(
        children: [
          ListTile(
            dense: true,
            selected: _group == null,
            title: const Text('Tümü'),
            onTap: () => setState(() => _group = null),
          ),
          for (final g in s.groups)
            ListTile(
              dense: true,
              selected: _group == g,
              title: Text(g, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => setState(() => _group = g),
            ),
        ],
      );

  Widget _list(AppState s, List<Channel> list, bool wide) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          widget.favoritesOnly ? 'Henüz favori kanal yok' : 'Kanal bulunamadı',
          style: const TextStyle(color: PV.textDim),
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemExtent: 62,
      itemBuilder: (_, i) {
        final c = list[i];
        return ChannelTile(
          channel: c,
          selected: wide && _preview?.key == c.key,
          onTap: () {
            if (wide) {
              setState(() => _preview = c);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PlayerScreen(list: list, index: i)),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= 900;
    final title = widget.favoritesOnly ? 'Favoriler' : (s.active?.name ?? 'PlayVue');

    Widget body;
    if (s.playlists.isEmpty) {
      body = _empty();
    } else if (s.loading && s.channels.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (s.channels.isEmpty && s.error != null) {
      body = Center(child: Text(s.error!, textAlign: TextAlign.center));
    } else {
      final list = _filter(s);
      if (wide) {
        body = Row(children: [
          SizedBox(width: 200, child: _groupList(s)),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 380,
            child: Column(children: [_search(), Expanded(child: _list(s, list, true))]),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: PreviewPane(
              channel: _preview,
              onFullscreen: () {
                final i = list.indexWhere((c) => c.key == _preview?.key);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(list: list, index: i < 0 ? 0 : i),
                  ),
                );
              },
            ),
          ),
        ]);
      } else {
        body = Column(children: [
          _search(),
          if (!widget.favoritesOnly) _chips(s),
          if (s.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _list(s, list, false)),
        ]);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: widget.favoritesOnly || s.playlists.isEmpty
            ? Text(title)
            : InkWell(
                onTap: () => _openPlaylistSwitcher(s),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.arrow_drop_down),
                ]),
              ),
        actions: [
          if (!widget.favoritesOnly && s.active != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Listeyi güncelle',
              onPressed: () => s.refreshPlaylist(s.active!),
            ),
        ],
      ),
      body: body,
    );
  }
}
