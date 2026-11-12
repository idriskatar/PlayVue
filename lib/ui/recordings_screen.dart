import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/m3u_parser.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../models/recording.dart';
import '../state/recordings_state.dart';
import 'player_screen.dart';
import 'record_sheet.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) context.read<RecordingsState>().refresh();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  static String _label(RecStatus s) => switch (s) {
        RecStatus.scheduled => 'Planlandı',
        RecStatus.recording => 'Kaydediliyor',
        RecStatus.done => 'Tamamlandı',
        RecStatus.failed => 'Başarısız',
        RecStatus.stopped => 'Durduruldu',
        RecStatus.missed => 'Kaçırıldı',
      };

  static Color _color(RecStatus s) => switch (s) {
        RecStatus.scheduled => PV.accent,
        RecStatus.recording => PV.live,
        RecStatus.done => Colors.greenAccent,
        RecStatus.failed => Colors.orange,
        RecStatus.stopped => PV.textDim,
        RecStatus.missed => Colors.orange,
      };

  int _order(RecTask t) {
    switch (t.status) {
      case RecStatus.recording:
        return 0;
      case RecStatus.scheduled:
        return 1;
      default:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecordingsState>();
    final list = List<RecTask>.of(rec.tasks)
      ..sort((a, b) {
        final o = _order(a).compareTo(_order(b));
        if (o != 0) return o;
        return a.status == RecStatus.scheduled
            ? a.startMs.compareTo(b.startMs)
            : b.startMs.compareTo(a.startMs);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıtlar')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.fiber_manual_record),
        label: const Text('Yeni kayıt'),
        onPressed: () => showRecordSheet(context),
      ),
      body: list.isEmpty
          ? const Center(
              child: Text('Henüz kayıt yok', style: TextStyle(color: PV.textDim)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
              itemCount: list.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Klasör: ${rec.recDir}',
                      style: const TextStyle(fontSize: 11, color: PV.textDim),
                    ),
                  );
                }
                final t = list[i - 1];
                return _tile(context, rec, t);
              },
            ),
    );
  }

  Widget _tile(BuildContext context, RecordingsState rec, RecTask t) {
    final c = _color(t.status);
    return Card(
      color: PV.card,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(t.channel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.withAlpha(35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_label(t.status),
                  style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            '${fmtDateTime(t.startMs)}  •  ${fmtDuration(t.durationSec)}'
            '${t.bytes > 0 ? '  •  ${fmtSize(t.bytes)}' : ''}',
            style: const TextStyle(color: PV.textDim, fontSize: 13),
          ),
          if (t.error != null && t.status == RecStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t.error!, style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (t.path != null && t.bytes > 0)
              TextButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Oynat'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      list: [Channel(name: t.channel, url: Uri.file(t.path!).toString())],
                      index: 0,
                    ),
                  ),
                ),
              ),
            if (t.status == RecStatus.recording || t.status == RecStatus.scheduled)
              TextButton.icon(
                icon: const Icon(Icons.stop),
                label: Text(t.status == RecStatus.recording ? 'Durdur' : 'İptal'),
                onPressed: () => rec.stop(t),
              ),
            if (t.status != RecStatus.recording)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, rec, t),
              ),
          ]),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, RecordingsState rec, RecTask t) {
    final hasFile = t.path != null && t.bytes > 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: Text(hasFile
            ? 'Kayıt dosyası da silinsin mi?'
            : 'Bu kayıt görevi silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          if (hasFile)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                rec.delete(t, deleteFile: false);
              },
              child: const Text('Listeden kaldır'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              rec.delete(t, deleteFile: true);
            },
            child: Text(hasFile ? 'Dosyayla sil' : 'Sil'),
          ),
        ],
      ),
    );
  }
}
