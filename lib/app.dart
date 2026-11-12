import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'ui/home_shell.dart';

class PlayVueApp extends StatelessWidget {
  const PlayVueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayVue',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}
