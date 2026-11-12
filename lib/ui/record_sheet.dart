import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/m3u_parser.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/recordings_state.dart';
import 'channel_picker.dart';

Future<void> showRecordSheet(BuildContext context, {Channel? channel}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: PV.surface,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _RecordSheet(channel: channel),
    ),
  );
}

class _RecordSheet extends StatefulWidget {
  final Channel? channel;
  const _RecordSheet({this.channel});

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  Channel? _ch;
  bool _now = true;
  late DateTime _start;
  int _min = 60;
  final _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ch = widget.channel;
    final n = DateTime.now().add(const Duration(minutes: 10));
    _start = DateTime(n.year, n.month, n.day, n.hour, n.minute);
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
    );
    if (t != null) {
      setState(() => _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute));
    }
  }

  Future<void> _save() async {
    final msg = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final rec = context.read<RecordingsState>();
    if (_ch == null) {
      msg.showSnackBar(const SnackBar(content: Text('Önce bir kanal seç')));
      return;
    }
    var minutes = _min;
    if (_custom.text.trim().isNotEmpty) {
      minutes = int.tryParse(_custom.text.trim()) ?? _min;
    }
    if (minutes < 1 || minutes > 720) {
      msg.showSnackBar(const SnackBar(content: Text('Süre 1 - 720 dakika olmalı')));
      return;
    }
    final start = _now ? DateTime.now() : _start;
    if (!_now && !start.isAfter(DateTime.now())) {
      msg.showSnackBar(const SnackBar(content: Text('Başlangıç zamanı gelecekte olmalı')));
      return;
    }
    if (!_now) await rec.ensurePermissions();
    if (_now && Platform.isAndroid) await rec.ensurePermissions();
    await rec.add(
      channel: _ch!.name,
      url: _ch!.url,
      userAgent: _ch!.headers['User-Agent'],
      start: start,
      minutes: minutes,
    );
    nav.pop();
    msg.showSnackBar(SnackBar(
      content: Text(_now
          ? 'Kayıt başladı (${fmtDuration(minutes * 60)})'
          : 'Kayıt planlandı: ${fmtDateTime(start.millisecondsSinceEpoch)}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Kayıt', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tv),
          title: Text(_ch?.name ?? 'Kanal seç'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final c = await pickChannel(context);
            if (c != null) setState(() => _ch = c);
          },
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Şimdi başlat'), icon: Icon(Icons.play_arrow)),
            ButtonSegment(value: false, label: Text('Zamanla'), icon: Icon(Icons.schedule)),
          ],
          selected: {_now},
          onSelectionChanged: (v) => setState(() => _now = v.first),
        ),
        if (!_now) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('${two(_start.day)}.${two(_start.month)}.${_start.year}'),
                onPressed: _pickDate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 18),
                label: Text(fmtHm(_start)),
                onPressed: _pickTime,
              ),
            ),
          ]),
        ],
        const SizedBox(height: 16),
        const Text('Süre', style: TextStyle(color: PV.textDim)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final m in [15, 30, 60, 90, 120, 180])
            ChoiceChip(
              label: Text(fmtDuration(m * 60)),
              selected: _custom.text.isEmpty && _min == m,
              onSelected: (_) => setState(() {
                _min = m;
                _custom.clear();
              }),
            ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _custom,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Özel süre (dakika)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(height: 10),
          const Text(
            'iOS: Zamanlı kayıt için uygulamanın açık (arka planda canlı) olması gerekir.',
            style: TextStyle(color: Colors.amber, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: Icon(_now ? Icons.fiber_manual_record : Icons.schedule),
            label: Text(_now ? 'Kaydı başlat' : 'Kaydı planla'),
            onPressed: _save,
          ),
        ),
      ]),
    );
  }
}
