import 'dart:async';

import 'package:flutter/material.dart';

import '../models/day_record.dart';
import '../services/background.dart';
import '../services/storage.dart';
import '../services/sync.dart';
import '../utils.dart';
import '../widgets/day_record_view.dart';
import '../widgets/history_list.dart';
import 'reliability_screen.dart';
import 'son_link_screen.dart';

class SonDashboardScreen extends StatelessWidget {
  const SonDashboardScreen({super.key, required this.code});

  final String code;

  Future<void> _unlink(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفك الربط بتليفون الوالدة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لأ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('أيوه')),
        ],
      ),
    );
    if (ok != true) return;
    await Storage.setLinkedCode(null);
    await Background.register();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute<void>(builder: (_) => const SonLinkScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('متابعة الوالدة'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'battery') {
                  Navigator.push(context,
                      MaterialPageRoute<void>(builder: (_) => const ReliabilityScreen()));
                } else {
                  _unlink(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'battery', child: Text('إعدادات البطارية')),
                PopupMenuItem(value: 'unlink', child: Text('فك الربط')),
              ],
            ),
          ],
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            labelStyle: Theme.of(context).textTheme.titleMedium,
            tabs: const [Tab(text: 'النهارده'), Tab(text: 'الأيام اللي فاتت')],
          ),
        ),
        body: TabBarView(children: [_Today(code: code), _History(code: code)]),
      ),
    );
  }
}

class _Today extends StatefulWidget {
  const _Today({required this.code});

  final String code;

  @override
  State<_Today> createState() => _TodayState();
}

class _TodayState extends State<_Today> {
  late final Timer _tick;
  late final Stream<DateTime?> _lastSeen = Sync.watchLastSeen(widget.code);
  late final Stream<DayRecord?> _day = Sync.watchDay(widget.code, dateKey(DateTime.now()));

  @override
  void initState() {
    super.initState();
    // "Missed" depends on the clock, so re-evaluate every minute.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String _ago(Duration d) {
    if (d.inMinutes < 2) return 'دلوقتي';
    if (d.inHours < 1) return 'من ${arNum(d.inMinutes)} دقيقة';
    if (d.inDays < 1) return 'من ${arNum(d.inHours)} ساعة';
    return 'من ${arNum(d.inDays)} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        StreamBuilder<DateTime?>(
          stream: _lastSeen,
          builder: (context, snap) {
            final seen = snap.data;
            final stale = seen == null || now.difference(seen) > const Duration(hours: 6);
            final color = stale ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(children: [
                Icon(stale ? Icons.warning_amber : Icons.phone_android, color: color, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    seen == null
                        ? 'تليفون الوالدة لسه ما بعتش حاجة'
                        : 'آخر ظهور لتليفون الوالدة: ${_ago(now.difference(seen))}',
                    style: theme.textTheme.titleMedium?.copyWith(color: color),
                  ),
                ),
              ]),
            );
          },
        ),
        StreamBuilder<DayRecord?>(
          stream: _day,
          builder: (context, snap) {
            final record = snap.data;
            if (record == null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : const Text('لسه مفيش بيانات النهارده', textAlign: TextAlign.center),
              );
            }
            return DayRecordView(record: record, now: now);
          },
        ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.code});

  final String code;

  Future<List<DayRecord>> _load() async {
    final today = dateKey(DateTime.now());
    final days = await Sync.recentDays(code, 32);
    // The mother's phone also uploads tomorrow's plan; show only past days.
    return days.where((d) => d.date.compareTo(today) < 0 && !d.isEmpty).take(30).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DayRecord>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('اتأكد إن النت شغّال'));
        }
        final records = snap.data;
        if (records == null) return const Center(child: CircularProgressIndicator());
        return HistoryList(records: records, now: DateTime.now());
      },
    );
  }
}
