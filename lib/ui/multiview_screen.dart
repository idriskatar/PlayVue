import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../core/m3u_parser.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'channel_picker.dart';

class MultiviewScreen extends StatefulWidget {
  const MultiviewScreen({super.key});

  @override
  State<MultiviewScreen> createState() => _MultiviewScreenState();
}

class _MultiviewScreenState extends State<MultiviewScreen> {
  int _audio = 0;

  List<Rect> _rects(Size s, int n) {
    final w = s.width, h = s.height;
    const g = 2.0;
    final landscape = w > h;
    if (n == 2) {
      return landscape
          ? [Rect.fromLTWH(0, 0, w / 2 - g, h), Rect.fromLTWH(w / 2 + g, 0, w / 2 - g, h)]
          : [Rect.fromLTWH(0, 0, w, h / 2 - g), Rect.fromLTWH(0, h / 2 + g, w, h / 2 - g)];
    }
    if (n == 3) {
      if (landscape) {
        final lw = w * 0.6;
        return [
          Rect.fromLTWH(0, 0, lw - g, h),
          Rect.fromLTWH(lw + g, 0, w - lw - g, h / 2 - g),
          Rect.fromLTWH(lw + g, h / 2 + g, w - lw - g, h / 2 - g),
        ];
      }
      final th = h * 0.5;
      return [
        Rect.fromLTWH(0, 0, w, th - g),
        Rect.fromLTWH(0, th + g, w / 2 - g, h - th - g),
        Rect.fromLTWH(w / 2 + g, th + g, w / 2 - g, h - th - g),
      ];
    }
    return [
      Rect.fromLTWH(0, 0, w / 2 - g, h / 2 - g),
      Rect.fromLTWH(w / 2 + g, 0, w / 2 - g, h / 2 - g),
      Rect.fromLTWH(0, h / 2 + g, w / 2 - g, h / 2 - g),
      Rect.fromLTWH(w / 2 + g, h / 2 + g, w / 2 - g, h / 2 - g),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiview'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.grid_view),
            tooltip: 'Yerleşim',
            onSelected: s.setMvCount,
            itemBuilder: (_) => [
              for (final n in [2, 3, 4])
                PopupMenuItem(value: n, child: Text('$n kanal${n == s.mvCount ? '  ✓' : ''}')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Hepsini temizle',
            onPressed: s.clearMultiview,
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, cons) {
        final rects = _rects(Size(cons.maxWidth, cons.maxHeight), s.mvCount);
        return Stack(children: [
          for (var i = 0; i < s.mvCount; i++)
            Positioned.fromRect(
              rect: rects[i],
              child: MvSlot(
                key: ValueKey('mv$i'),
                index: i,
                channel: s.mvSlots[i],
                active: _audio == i,
                lowQuality: s.mvCount > 2,
                onActivate: () => setState(() => _audio = i),
              ),
            ),
        ]);
      }),
    );
  }
}

class MvSlot extends StatefulWidget {
  final int index;
  final Channel? channel;
  final bool active;
  final bool lowQuality;
  final VoidCallback onActivate;
  const MvSlot({
    super.key,
    required this.index,
    required this.channel,
    required this.active,
    required this.lowQuality,
    required this.onActivate,
  });

  @override
  State<MvSlot> createState() => _MvSlotState();
}

class _MvSlotState extends State<MvSlot> {
  Player? _p;
  VideoController? _vc;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final ch = widget.channel;
    if (ch == null) return;
    _p ??= Player(configuration: const PlayerConfiguration(bufferSize: 16 * 1024 * 1024));
    _vc ??= VideoController(_p!);
    if (widget.lowQuality) {
      try {
        (_p!.platform as dynamic).setProperty('hls-bitrate', 'min');
      } catch (_) {}
    }
    _p!.open(Media(ch.url, httpHeaders: ch.headers.isEmpty ? null : ch.headers));
    _applyVolume();
  }

  void _applyVolume() => _p?.setVolume(widget.active ? 100 : 0);

  @override
  void didUpdateWidget(MvSlot old) {
    super.didUpdateWidget(old);
    if (old.channel?.key != widget.channel?.key) {
      if (widget.channel == null) {
        _p?.stop();
      } else {
        _setup();
      }
    }
    if (old.active != widget.active) _applyVolume();
  }

  @override
  void dispose() {
    _p?.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final c = await pickChannel(context);
    if (c != null && mounted) context.read<AppState>().setMvSlot(widget.index, c);
  }

  void _menu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PV.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Kanalı değiştir'),
            onTap: () {
              Navigator.pop(ctx);
              _choose();
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Kaldır'),
            onTap: () {
              Navigator.pop(ctx);
              context.read<AppState>().setMvSlot(widget.index, null);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    if (ch == null || _vc == null) {
      return InkWell(
        onTap: _choose,
        child: Container(
          color: PV.card,
          child: const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_circle_outline, size: 40, color: PV.accent),
              SizedBox(height: 6),
              Text('Kanal ekle', style: TextStyle(color: PV.textDim)),
            ]),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: widget.onActivate,
      onLongPress: _menu,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.active ? PV.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(fit: StackFit.expand, children: [
          Video(controller: _vc!, controls: NoVideoControls, fill: Colors.black),
          Positioned(
            left: 6,
            top: 6,
            right: 6,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(ch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
              ),
              const Spacer(),
              Icon(widget.active ? Icons.volume_up : Icons.volume_off,
                  size: 16, color: widget.active ? PV.accent : Colors.white54),
            ]),
          ),
        ]),
      ),
    );
  }
}
