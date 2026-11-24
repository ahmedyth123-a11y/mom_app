import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../services/sounds.dart';

/// Every sound of a category (bundled + added from the phone), each with a
/// preview button; added ones can be deleted. With [onChanged] she picks one;
/// without it (tasbeeh) the list is just the recordings to rotate.
class SoundPicker extends StatefulWidget {
  const SoundPicker({
    super.key,
    required this.label,
    required this.category,
    this.value,
    this.onChanged,
  });

  final String label;
  final SoundCategory category;

  /// Her choice (null = the category default).
  final String? value;

  /// Called with the new choice, or null to follow the default.
  final ValueChanged<String?>? onChanged;

  @override
  State<SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends State<SoundPicker> {
  final _player = AudioPlayer();
  late final StreamSubscription<void> _completion;
  List<String> _files = const [];
  String? _default;
  String? _selected;
  String? _playing;

  bool get _selectable => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _completion = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
    _load();
  }

  @override
  void didUpdateWidget(SoundPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _load();
  }

  @override
  void dispose() {
    _completion.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = widget.category;
    final files = await Sounds.list(c);
    final def = await Sounds.defaultFor(c);
    final selected = _selectable ? await Sounds.resolve(c, widget.value) : null;
    if (!mounted) return;
    setState(() {
      _files = files;
      _default = def;
      _selected = selected;
    });
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _stop() async {
    await _player.stop();
    if (mounted) setState(() => _playing = null);
  }

  Future<void> _togglePreview(String path) async {
    final wasPlaying = _playing == path;
    await _stop();
    if (wasPlaying) return;
    setState(() => _playing = path);
    try {
      await _player.play(Sounds.source(path));
    } catch (_) {
      await _stop();
      _snack('الملف ده مش راضي يشتغل، جرّب ملف تاني');
    }
  }

  void _choose(String path) {
    _stop();
    // Picking the default stores nothing, so a future default applies too.
    widget.onChanged!(path == _default ? null : path);
  }

  Future<void> _add() async {
    await _stop();
    String? path;
    try {
      path = await Sounds.addFromPhone(widget.category);
    } on PlatformException {
      _snack('مقدرتش أضيف الملف، جرّب ملف تاني');
      return;
    }
    if (path == null) return;
    await _load();
    widget.onChanged?.call(path);
    _snack('اتضاف: ${Sounds.label(path)}');
  }

  Future<void> _delete(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('تمسح «${Sounds.label(path)}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لأ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('امسح')),
        ],
      ),
    );
    if (ok != true) return;
    if (_playing == path) await _stop();
    await Sounds.delete(path);
    await _load();
    if (path == widget.value) widget.onChanged?.call(null);
  }

  Widget _row(String path) {
    final playing = _playing == path;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _selectable
          ? Radio<String>(value: path, groupValue: _selected, onChanged: (_) => _choose(path))
          : const Icon(Icons.music_note),
      title: Text(Sounds.label(path)),
      onTap: _selectable ? () => _choose(path) : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton.icon(
          onPressed: () => _togglePreview(path),
          icon: Icon(playing ? Icons.stop : Icons.play_arrow),
          label: Text(playing ? 'إيقاف' : 'تجربة'),
        ),
        if (Sounds.isUserFile(path))
          IconButton(
            tooltip: 'مسح',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(path),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
          if (_files.isEmpty && !_selectable)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('لسه مفيش تسجيلات — هيتقري بصوت التليفون لحد ما تضيف'),
            ),
          for (final f in _files) _row(f),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _add,
            child: const Text('➕ إضافة صوت من التليفون'),
          ),
        ],
      ),
    );
  }
}
