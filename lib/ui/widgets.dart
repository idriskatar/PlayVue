import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/m3u_parser.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'record_sheet.dart';

class Logo extends StatelessWidget {
  final String? url;
  final double size;
  const Logo({super.key, this.url, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PV.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.tv, color: PV.textDim, size: 22),
    );
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: PV.card,
        padding: const EdgeInsets.all(4),
        child: CachedNetworkImage(
          imageUrl: url!,
          fit: BoxFit.contain,
          memCacheWidth: 128,
          errorWidget: (_, __, ___) => const Icon(Icons.tv, color: PV.textDim, size: 22),
          placeholder: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  final Channel channel;
  final bool selected;
  final VoidCallback onTap;
  const ChannelTile({
    super.key,
    required this.channel,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = s.nowOf(channel);
    final fav = s.isFav(channel);
    return InkWell(
      onTap: onTap,
      onLongPress: () => showChannelMenu(context, channel),
      child: Container(
        color: selected ? PV.accent.withAlpha(25) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Logo(url: channel.logo, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  now != null ? now.title : channel.group,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: now != null ? PV.accent : PV.textDim,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(fav ? Icons.star : Icons.star_border,
                color: fav ? Colors.amber : PV.textDim),
            onPressed: () => s.toggleFav(channel),
          ),
        ]),
      ),
    );
  }
}

Future<void> showChannelMenu(BuildContext context, Channel ch) {
  final s = context.read<AppState>();
  return showModalBottomSheet(
    context: context,
    backgroundColor: PV.surface,
    builder: (sheetCtx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: Text(ch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(ch.group),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(s.isFav(ch) ? Icons.star : Icons.star_border),
          title: Text(s.isFav(ch) ? 'Favorilerden çıkar' : 'Favorilere ekle'),
          onTap: () {
            s.toggleFav(ch);
            Navigator.pop(sheetCtx);
          },
        ),
        ListTile(
          leading: const Icon(Icons.grid_view),
          title: const Text("Multiview'a ekle"),
          onTap: () {
            final idx = s.addToMultiview(ch);
            Navigator.pop(sheetCtx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Multiview yuva ${idx + 1} içine eklendi')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.fiber_manual_record, color: PV.live),
          title: const Text('Kayıt / Kayıt planla'),
          onTap: () {
            Navigator.pop(sheetCtx);
            showRecordSheet(context, channel: ch);
          },
        ),
      ]),
    ),
  );
}
