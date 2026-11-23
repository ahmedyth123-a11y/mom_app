import 'dart:math';

import 'package:flutter/material.dart';

import '../app.dart';
import '../models/app_settings.dart';
import '../services/storage.dart';
import 'reliability_screen.dart';
import 'son_link_screen.dart';

/// First launch: whose phone is this?
class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  Future<void> _choose(BuildContext context, AppMode mode) async {
    if (mode == AppMode.mother && await Storage.pairCode() == null) {
      await Storage.setPairCode('${Random.secure().nextInt(900000) + 100000}');
    }
    await Storage.setMode(mode);
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(
        builder: (_) => mode == AppMode.mother
            ? const ReliabilityScreen(firstRun: true)
            : const SonLinkScreen(),
      ),
      (_) => false,
    );
    await refreshAppData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Icon(Icons.favorite, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('أهلاً بيك', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
            Text('التليفون ده بتاع مين؟',
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 32),
            _ModeCard(
              icon: Icons.elderly_woman,
              title: 'تليفون الوالدة',
              subtitle: 'الأدوية والأذان والقيام والأذكار',
              onTap: () => _choose(context, AppMode.mother),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              icon: Icons.family_restroom,
              title: 'تليفون المتابع (الابن)',
              subtitle: 'تشوف خدت الدوا وصلّت ولا لأ',
              onTap: () => _choose(context, AppMode.son),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard(
      {required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(icon, size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleLarge),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
