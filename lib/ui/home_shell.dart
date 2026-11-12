import 'package:flutter/material.dart';

import 'channels_screen.dart';
import 'multiview_screen.dart';
import 'recordings_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  static const _icons = [
    Icons.live_tv_outlined,
    Icons.star_border,
    Icons.grid_view_outlined,
    Icons.fiber_manual_record_outlined,
    Icons.settings_outlined,
  ];
  static const _iconsSel = [
    Icons.live_tv,
    Icons.star,
    Icons.grid_view,
    Icons.fiber_manual_record,
    Icons.settings,
  ];
  static const _labels = ['Canlı', 'Favoriler', 'Multiview', 'Kayıtlar', 'Ayarlar'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ChannelsScreen(),
      const ChannelsScreen(favoritesOnly: true),
      _i == 2 ? const MultiviewScreen() : const SizedBox.shrink(),
      const RecordingsScreen(),
      const SettingsScreen(),
    ];
    final body = IndexedStack(index: _i, children: pages);
    final wide = MediaQuery.of(context).size.width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _i,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (v) => setState(() => _i = v),
            destinations: [
              for (var k = 0; k < _labels.length; k++)
                NavigationRailDestination(
                  icon: Icon(_icons[k]),
                  selectedIcon: Icon(_iconsSel[k]),
                  label: Text(_labels[k]),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          for (var k = 0; k < _labels.length; k++)
            NavigationDestination(
              icon: Icon(_icons[k]),
              selectedIcon: Icon(_iconsSel[k]),
              label: _labels[k],
            ),
        ],
      ),
    );
  }
}
