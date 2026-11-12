import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../core/m3u_parser.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';

/// Geniş ekranlarda (tablet / Android TV) sağ taraftaki önizleme paneli.
class PreviewPane extends StatefulWidget {
  final Channel? channel;
  final VoidCallback onFullscreen;
  const PreviewPane({super.key, required this.channel, required this.onFullscreen});

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
  late final Player _player = Player();
  late final VideoController _vc = VideoController(_player);

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    final c = widget.channel;
    if (c == null) return;
    _player.open(Media(c.url, httpHeaders: c.headers.isEmpty ? null : c.headers));
  }

  @override
  void didUpdateWidget(PreviewPane old) {
    super.didUpdateWidget(old);
    if (old.channel?.key != widget.channel?.key) {
      if (widget.channel == null) {
        _player.stop();
      } else {
        _open();
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    final s = context.watch<AppState>();
    if (c == null) {
      return const Center(
        child: Text('Önizlemek için bir kanal seç', style: TextStyle(color: PV.textDim)),
      );
    }
    final now = s.nowOf(c);
    final next = s.nextOf(c);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(children: [
              Video(controller: _vc, controls: NoVideoControls, fill: Colors.black),
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: widget.onFullscreen,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Text(c.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(c.group, style: const TextStyle(color: PV.textDim)),
        const SizedBox(height: 14),
        if (now != null) ...[
          const Text('ŞİMDİ',
              style: TextStyle(color: PV.accent, fontSize: 11, fontWeight: FontWeight.bold)),
          Text('${fmtHm(now.start.toLocal())} - ${fmtHm(now.stop.toLocal())}  ${now.title}'),
        ],
        if (next != null) ...[
          const SizedBox(height: 10),
          const Text('SIRADAKİ',
              style: TextStyle(color: PV.textDim, fontSize: 11, fontWeight: FontWeight.bold)),
          Text('${fmtHm(next.start.toLocal())}  ${next.title}'),
        ],
      ]),
    );
  }
}
