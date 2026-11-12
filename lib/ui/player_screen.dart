import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/m3u_parser.dart';
import '../state/app_state.dart';
import 'record_sheet.dart';

class PlayerScreen extends StatefulWidget {
  final List<Channel> list;
  final int index;
  const PlayerScreen({super.key, required this.list, required this.index});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player = Player();
  late final VideoController _vc = VideoController(_player);
  late int _i = widget.index;
  bool _show = true;
  bool _buffering = true;
  String? _err;
  BoxFit _fit = BoxFit.contain;
  Timer? _hide;
  final List<StreamSubscription> _subs = [];

  Channel get _ch => widget.list[_i];
  bool get _isFile => _ch.url.startsWith('file:');

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _subs.add(_player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    }));
    _subs.add(_player.stream.error.listen((e) {
      if (mounted) setState(() => _err = e);
    }));
    _open();
    _autoHide();
  }

  void _open() {
    _err = null;
    _buffering = true;
    _player.open(Media(_ch.url,
        httpHeaders: _ch.headers.isEmpty ? null : _ch.headers));
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _show = false);
    });
  }

  void _toggle() {
    setState(() => _show = !_show);
    if (_show) _autoHide();
  }

  void _go(int d) {
    final n = _i + d;
    if (n < 0 || n >= widget.list.length) return;
    setState(() => _i = n);
    _open();
    _autoHide();
  }

  void _cycleFit() {
    setState(() {
      _fit = _fit == BoxFit.contain
          ? BoxFit.cover
          : (_fit == BoxFit.cover ? BoxFit.fill : BoxFit.contain);
    });
    _autoHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = _isFile ? null : s.nowOf(_ch);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -300) _go(1);
          if (v > 300) _go(-1);
        },
        child: Stack(fit: StackFit.expand, children: [
          Video(controller: _vc, controls: NoVideoControls, fit: _fit, fill: Colors.black),
          if (_buffering && _err == null)
            const Center(child: CircularProgressIndicator()),
          if (_err != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 8),
                  Text(_err!, textAlign: TextAlign.center, maxLines: 4),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _open, child: const Text('Tekrar dene')),
                ]),
              ),
            ),
          AnimatedOpacity(
            opacity: _show ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_show,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
                    stops: [0, 0.25, 0.7, 1],
                  ),
                ),
                child: SafeArea(
                  child: Column(children: [
                    Row(children: [
                      const BackButton(color: Colors.white),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_ch.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          if (now != null)
                            Text(now.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ]),
                      ),
                      if (!_isFile)
                        IconButton(
                          icon: Icon(s.isFav(_ch) ? Icons.star : Icons.star_border,
                              color: s.isFav(_ch) ? Colors.amber : Colors.white),
                          onPressed: () => s.toggleFav(_ch),
                        ),
                      IconButton(
                        icon: const Icon(Icons.aspect_ratio),
                        onPressed: _cycleFit,
                      ),
                    ]),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (!_isFile) ...[
                          IconButton(
                            iconSize: 34,
                            icon: const Icon(Icons.skip_previous),
                            onPressed: _i > 0 ? () => _go(-1) : null,
                          ),
                        ],
                        StreamBuilder<bool>(
                          stream: _player.stream.playing,
                          initialData: _player.state.playing,
                          builder: (_, snap) => IconButton.filled(
                            iconSize: 38,
                            icon: Icon((snap.data ?? false) ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              _player.playOrPause();
                              _autoHide();
                            },
                          ),
                        ),
                        if (!_isFile) ...[
                          IconButton(
                            iconSize: 34,
                            icon: const Icon(Icons.skip_next),
                            onPressed: _i < widget.list.length - 1 ? () => _go(1) : null,
                          ),
                        ],
                        if (!_isFile) ...[
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 30,
                            tooltip: 'Kaydet',
                            icon: const Icon(Icons.fiber_manual_record, color: Colors.redAccent),
                            onPressed: () => showRecordSheet(context, channel: _ch),
                          ),
                          IconButton(
                            iconSize: 28,
                            tooltip: "Multiview'a ekle",
                            icon: const Icon(Icons.grid_view),
                            onPressed: () {
                              final idx = s.addToMultiview(_ch);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Multiview yuva ${idx + 1} içine eklendi'),
                                duration: const Duration(seconds: 2),
                              ));
                            },
                          ),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
