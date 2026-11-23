import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/sounds.dart';

/// Dropdown of every file in a sound folder, with a preview button.
class SoundPicker extends StatefulWidget {
  const SoundPicker({
    super.key,
    required this.label,
    required this.category,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final SoundCategory category;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends State<SoundPicker> {
  final _player = AudioPlayer();
  late final StreamSubscription<void> _completion;
  List<String> _files = const [];
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _completion = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    Sounds.list(widget.category).then((files) {
      if (mounted) setState(() => _files = files);
    });
  }

  @override
  void dispose() {
    _completion.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    if (_playing) {
      await _player.stop();
    } else {
      // AssetSource paths are relative to the assets/ folder.
      await _player.play(AssetSource(widget.value.replaceFirst('assets/', '')));
    }
    if (mounted) setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
          DropdownButton<String>(
            isExpanded: true,
            value: _files.contains(widget.value) ? widget.value : null,
            style: Theme.of(context).textTheme.bodyLarge,
            items: [
              for (final f in _files)
                DropdownMenuItem(
                    value: f, child: Text(Sounds.label(f), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v == null) return;
              _player.stop();
              setState(() => _playing = false);
              widget.onChanged(v);
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: _togglePreview,
              icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
              label: Text(_playing ? 'إيقاف' : 'تجربة الصوت'),
            ),
          ),
        ],
      ),
    );
  }
}
