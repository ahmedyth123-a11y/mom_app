import 'package:flutter/material.dart';

import '../services/notifications.dart';
import '../services/system_settings.dart';
import 'mother_shell.dart';

/// Guided permissions/battery steps so OPPO (ColorOS) doesn't kill reminders.
class ReliabilityScreen extends StatefulWidget {
  const ReliabilityScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<ReliabilityScreen> createState() => _ReliabilityScreenState();
}

class _ReliabilityScreenState extends State<ReliabilityScreen> with WidgetsBindingObserver {
  Map<String, bool> _status = const {};
  bool _notifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(); // back from a settings screen
  }

  Future<void> _load() async {
    final status = await SystemSettings.status();
    final notifications = await Notifs.enabled();
    if (mounted) {
      setState(() {
        _status = status;
        _notifications = notifications;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عشان التنبيهات ما تتأخرش')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('تليفونات أوبو بتقفل البرامج عشان توفّر البطارية، '
                'فالأذان والمنبّهات ممكن ما تشتغلش. اعمل الخطوات دي مرة واحدة بس:'),
          ),
          _Step(
            number: 1,
            title: 'السماح بالإشعارات',
            done: _notifications,
            button: 'اسمح بالإشعارات',
            onPressed: () async {
              await Notifs.requestPermission();
              await _load();
            },
          ),
          _Step(
            number: 2,
            title: 'المنبّهات في ميعادها بالظبط',
            done: _status['exactAlarm'],
            help: 'فعّل "السماح بضبط المنبّهات والتذكيرات".',
            button: 'افتح الإعداد',
            onPressed: SystemSettings.openExactAlarm,
          ),
          _Step(
            number: 3,
            title: 'من غير توفير بطارية',
            done: _status['battery'],
            help: 'اختار "سماح" أو "بدون قيود" للتطبيق ده.',
            button: 'افتح إعداد البطارية',
            onPressed: SystemSettings.openBattery,
          ),
          _Step(
            number: 4,
            title: 'يظهر فوق شاشة القفل',
            done: _status['fullScreen'],
            help: 'عشان شاشة المنبّه تفتح لوحدها والتليفون مقفول.',
            button: 'افتح الإعداد',
            onPressed: SystemSettings.openFullScreen,
          ),
          const _Step(
            number: 5,
            title: 'التشغيل التلقائي (أوبو)',
            help: 'فعّل "التشغيل التلقائي" للتطبيق ده، ولو لقيت '
                '"السماح بالنشاط في الخلفية" فعّله كمان.',
            button: 'افتح التشغيل التلقائي',
            onPressed: SystemSettings.openAutostart,
          ),
          const _Step(
            number: 6,
            title: 'اقفل التطبيق في البرامج المفتوحة',
            help: 'دوس على زرار البرامج المفتوحة (المربع أو اسحب من تحت لفوق وثبّت)، '
                'وبعدين اسحب كارت التطبيق لتحت أو دوس على النقط التلاتة واختار "قفل". '
                'هيظهر جنبه قفل صغير.',
          ),
          if (widget.firstRun)
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const MotherShell()),
                  (_) => false,
                ),
                child: const Text('تمام، يلا نبدأ'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    this.done,
    this.help,
    this.button,
    this.onPressed,
  });

  final int number;
  final String title;

  /// null when the phone can't tell us (OPPO-specific steps).
  final bool? done;
  final String? help;
  final String? button;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = this.done;
    final help = this.help;
    final button = this.button;
    final onPressed = this.onPressed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text('$number', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          if (done != null)
            Icon(done ? Icons.check_circle : Icons.error,
                size: 34, color: done ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00)),
        ]),
        if (help != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(help)),
        if (button != null && onPressed != null && done != true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(onPressed: onPressed, child: Text(button)),
          ),
      ]),
    );
  }
}
