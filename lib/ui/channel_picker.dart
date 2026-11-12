import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/m3u_parser.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'widgets.dart';

Future<Channel?> pickChannel(BuildContext context) {
  return showModalBottomSheet<Channel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PV.surface,
    builder: (_) => const _Picker(),
  );
}

class _Picker extends StatefulWidget {
  const _Picker();

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = _q.toLowerCase();
    final list = q.isEmpty
        ? s.channels
        : s.channels.where((c) => c.name.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            autofocus: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Kanal ara',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemExtent: 60,
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                leading: Logo(url: c.logo, size: 40),
                title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(c.group, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, c),
              );
            },
          ),
        ),
      ]),
    );
  }
}
