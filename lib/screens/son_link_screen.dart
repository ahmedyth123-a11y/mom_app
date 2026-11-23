import 'package:flutter/material.dart';

import '../firebase_config.dart';
import '../services/background.dart';
import '../services/notifications.dart';
import '../services/storage.dart';
import '../services/sync.dart';
import '../utils.dart';
import 'son_dashboard_screen.dart';

class SonLinkScreen extends StatefulWidget {
  const SonLinkScreen({super.key});

  @override
  State<SonLinkScreen> createState() => _SonLinkScreenState();
}

class _SonLinkScreenState extends State<SonLinkScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final code = westernDigits(_code.text.trim());
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'الكود ٦ أرقام');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      if (!await Sync.ensure() || !await Sync.familyExists(code)) {
        error = 'الكود ده مش موجود، اتأكد منه من إعدادات تليفون الوالدة';
      }
    } catch (_) {
      error = 'اتأكد إن النت شغّال وجرّب تاني';
    }
    if (error == null) {
      await Storage.setLinkedCode(code);
      await Notifs.requestPermission();
      await Background.register();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => SonDashboardScreen(code: code)),
        (_) => false,
      );
      return;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ربط تليفون الوالدة')),
      body: !FirebaseConfig.isConfigured
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'الربط لسه ما اتفعّلش.\nلازم الأول تتحط إعدادات Firebase في التطبيق (شوف ملف README).',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.link, size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('اكتب كود الربط اللي ظاهر في إعدادات تليفون الوالدة',
                    textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                const SizedBox(height: 24),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 8),
                  decoration: InputDecoration(counterText: '', errorText: _error),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _link,
                  child: _busy ? const CircularProgressIndicator() : const Text('اربط'),
                ),
              ],
            ),
    );
  }
}
