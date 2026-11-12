import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/playlist.dart';
import '../state/app_state.dart';

class AddPlaylistScreen extends StatefulWidget {
  const AddPlaylistScreen({super.key});

  @override
  State<AddPlaylistScreen> createState() => _AddPlaylistScreenState();
}

class _AddPlaylistScreenState extends State<AddPlaylistScreen> {
  PlaylistType _type = PlaylistType.url;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _epg = TextEditingController();
  int _hours = 24;
  String? _filePath;
  String? _fileName;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _url, _user, _pass, _epg]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r != null && r.files.single.path != null) {
      setState(() {
        _filePath = r.files.single.path;
        _fileName = r.files.single.name;
        if (_name.text.isEmpty) {
          _name.text = _fileName!.replaceAll(RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), '');
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
    });
    final name = _name.text.trim().isEmpty ? 'Playlist' : _name.text.trim();
    String source;
    switch (_type) {
      case PlaylistType.url:
        source = _url.text.trim();
        if (!source.startsWith('http')) {
          setState(() => _error = 'Geçerli bir http(s) adresi gir');
          return;
        }
        break;
      case PlaylistType.file:
        if (_filePath == null) {
          setState(() => _error = 'Bir dosya seç');
          return;
        }
        source = _fileName ?? 'dosya';
        break;
      case PlaylistType.xtream:
        source = _url.text.trim();
        if (!source.startsWith('http') || _user.text.trim().isEmpty) {
          setState(() => _error = 'Sunucu adresi (http://...) ve kullanıcı adı gerekli');
          return;
        }
        break;
    }
    final p = PlaylistInfo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      type: _type,
      source: source,
      username: _type == PlaylistType.xtream ? _user.text.trim() : null,
      password: _type == PlaylistType.xtream ? _pass.text : null,
      epgUrl: _epg.text.trim().isEmpty ? null : _epg.text.trim(),
      updateHours: _type == PlaylistType.file ? 0 : _hours,
    );
    setState(() => _busy = true);
    try {
      await context.read<AppState>().addPlaylist(p, filePath: _filePath);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist ekle')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<PlaylistType>(
          segments: const [
            ButtonSegment(value: PlaylistType.url, label: Text('URL'), icon: Icon(Icons.link)),
            ButtonSegment(value: PlaylistType.file, label: Text('Dosya'), icon: Icon(Icons.folder_open)),
            ButtonSegment(value: PlaylistType.xtream, label: Text('Xtream'), icon: Icon(Icons.dns)),
          ],
          selected: {_type},
          onSelectionChanged: (v) => setState(() => _type = v.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Liste adı', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        if (_type == PlaylistType.url)
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: 'M3U adresi', hintText: 'http://...', border: OutlineInputBorder()),
          ),
        if (_type == PlaylistType.file)
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(_fileName ?? 'M3U dosyası seç'),
            onPressed: _pickFile,
          ),
        if (_type == PlaylistType.xtream) ...[
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: 'Sunucu adresi', hintText: 'http://sunucu:port', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'Kullanıcı adı', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder()),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _epg,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'EPG (XMLTV) adresi - isteğe bağlı',
            border: OutlineInputBorder(),
          ),
        ),
        if (_type != PlaylistType.file) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _hours,
            decoration: const InputDecoration(
                labelText: 'Otomatik güncelleme', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Elle')),
              DropdownMenuItem(value: 6, child: Text('6 saatte bir')),
              DropdownMenuItem(value: 12, child: Text('12 saatte bir')),
              DropdownMenuItem(value: 24, child: Text('Günde bir')),
              DropdownMenuItem(value: 72, child: Text('3 günde bir')),
            ],
            onChanged: (v) => setState(() => _hours = v ?? 24),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ekle ve yükle'),
        ),
        const SizedBox(height: 12),
        const Text(
          'PlayVue içerik sağlamaz. Yalnızca kullanım hakkına sahip olduğun kaynakları ekle.',
          style: TextStyle(color: PV.textDim, fontSize: 12),
        ),
      ]),
    );
  }
}
