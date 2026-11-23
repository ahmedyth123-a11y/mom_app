import 'package:flutter/material.dart';

import '../firebase_config.dart';
import '../models/app_settings.dart';
import '../services/background.dart';
import '../services/scheduler.dart';
import '../services/storage.dart';
import '../services/tts.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/section_card.dart';
import '../widgets/sound_picker.dart';
import 'reliability_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;
  String? _code;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Storage.settings();
    final code = await Storage.pairCode();
    if (mounted) {
      setState(() {
        _settings = s;
        _code = code;
      });
    }
  }

  /// Applies [change], saves, and reschedules everything that depends on it.
  Future<void> _update(void Function(AppSettings s) change) async {
    final s = _settings!;
    setState(() => change(s));
    await Storage.saveSettings(s);
    await Scheduler.rescheduleAll();
    await Background.register();
  }

  Future<int?> _pickTime(int minutes) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Widget _switch(String label, bool value, void Function(AppSettings s, bool v) set) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: (v) => _update((s) => set(s, v)),
      );

  Widget _sound(String label, SoundCategory c) => SoundPicker(
        label: label,
        category: c,
        value: _settings!.soundPath(c),
        onChanged: (path) => _update((s) => s.setSound(c, path)),
      );

  Future<void> _testTasbeeh() async {
    final spoken = await speakArabic(tasbeehPhrases.first);
    if (!spoken && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('مفيش صوت عربي على التليفون، التسبيح هيظهر كإشعار مكتوب')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                SectionCard(
                  title: 'الأصوات',
                  icon: Icons.music_note,
                  child: Column(children: [
                    _sound('صوت الأذان', SoundCategory.adhan),
                    _sound('صوت منبّه القيام', SoundCategory.alarm),
                    _sound('صوت تنبيه الدوا', SoundCategory.med),
                  ]),
                ),
                SectionCard(
                  title: 'حجم الخط',
                  icon: Icons.text_fields,
                  child: Slider(
                    value: s.fontScale,
                    min: 0.9,
                    max: 1.5,
                    divisions: 6,
                    onChanged: (v) {
                      setState(() => s.fontScale = v);
                      fontScale.value = v;
                    },
                    onChangeEnd: (_) => Storage.saveSettings(s),
                  ),
                ),
                SectionCard(
                  title: 'التنبيهات',
                  icon: Icons.notifications_active,
                  child: Column(children: [
                    _switch('تنبيه الأدوية', s.meds, (s, v) => s.meds = v),
                    _switch('الأذان وسؤال الصلاة', s.prayers, (s, v) => s.prayers = v),
                    _switch('أذكار الصباح والمسا', s.azkar, (s, v) => s.azkar = v),
                    _switch('تذكير الصيام (الاتنين والخميس والأيام البيض)', s.fasting,
                        (s, v) => s.fasting = v),
                  ]),
                ),
                SectionCard(
                  title: 'قيام الليل',
                  icon: Icons.nightlight_round,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _switch('منبّه القيام', s.qiyam, (s, v) => s.qiyam = v),
                    if (s.qiyam) ...[
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        groupValue: s.qiyamAuto,
                        onChanged: (_) => _update((s) => s.qiyamAuto = true),
                        title: const Text('تلقائي: أول الثلث الأخير من الليل'),
                      ),
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        groupValue: s.qiyamAuto,
                        onChanged: (_) => _update((s) => s.qiyamAuto = false),
                        title: Text('وقت ثابت: ${formatMinutes(s.qiyamFixed)}'),
                      ),
                      if (!s.qiyamAuto)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: const Text('غيّري الوقت'),
                          onPressed: () async {
                            final m = await _pickTime(s.qiyamFixed);
                            if (m != null) await _update((s) => s.qiyamFixed = m);
                          },
                        ),
                    ],
                  ]),
                ),
                SectionCard(
                  title: 'التسبيح بالصوت',
                  icon: Icons.record_voice_over,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _switch('التليفون يسبّح بصوت كل شوية', s.tasbeeh, (s, v) => s.tasbeeh = v),
                    if (s.tasbeeh) ...[
                      Row(children: [
                        const Text('كل'),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: s.tasbeehInterval,
                          style: theme.textTheme.bodyLarge,
                          items: [
                            for (final m in const [30, 60, 90, 120])
                              DropdownMenuItem(value: m, child: Text('${arNum(m)} دقيقة')),
                          ],
                          onChanged: (m) {
                            if (m != null) _update((s) => s.tasbeehInterval = m);
                          },
                        ),
                      ]),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('من الساعة'),
                        trailing: Text(formatMinutes(s.tasbeehStart),
                            style: theme.textTheme.titleMedium),
                        onTap: () async {
                          final m = await _pickTime(s.tasbeehStart);
                          if (m != null && m < s.tasbeehEnd) {
                            await _update((s) => s.tasbeehStart = m);
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('لحد الساعة'),
                        trailing: Text(formatMinutes(s.tasbeehEnd),
                            style: theme.textTheme.titleMedium),
                        onTap: () async {
                          final m = await _pickTime(s.tasbeehEnd);
                          if (m != null && m > s.tasbeehStart) {
                            await _update((s) => s.tasbeehEnd = m);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('اسمعي التسبيح'),
                      onPressed: _testTasbeeh,
                    ),
                  ]),
                ),
                SectionCard(
                  title: 'ربط تليفون الابن',
                  icon: Icons.link,
                  child: !FirebaseConfig.isConfigured || _code == null
                      ? const Text('الربط لسه ما اتفعّلش')
                      : Column(children: [
                          const Text('اكتب الكود ده في تليفون الابن:'),
                          const SizedBox(height: 8),
                          SelectableText(
                            _code!,
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.displaySmall?.copyWith(
                                letterSpacing: 8, color: theme.colorScheme.primary),
                          ),
                        ]),
                ),
                SectionCard(
                  title: 'تشغيل التنبيهات في الخلفية',
                  icon: Icons.battery_charging_full,
                  child: FilledButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute<void>(builder: (_) => const ReliabilityScreen())),
                    child: const Text('خطوات إعداد أوبو'),
                  ),
                ),
              ],
            ),
    );
  }
}
