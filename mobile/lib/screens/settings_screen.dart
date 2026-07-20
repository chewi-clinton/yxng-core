import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/calendar_service.dart';
import '../services/payments_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'payments_screen.dart';
import 'profile_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with WidgetsBindingObserver {
  final _paymentsService = PaymentsService();
  final _calendarService = CalendarService();
  bool _extensionConnected = false;
  bool _calendarConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkExtensionConnection();
    _checkCalendarConnection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catches the user coming back from the Google OAuth consent page in
    // their browser, since there's no deep link back into the app.
    if (state == AppLifecycleState.resumed) {
      _checkCalendarConnection();
    }
  }

  Future<void> _checkCalendarConnection() async {
    final connected = await _calendarService.getStatus();
    if (mounted) setState(() => _calendarConnected = connected);
  }

  Future<void> _handleCalendarTap() async {
    if (_calendarConnected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceAlt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Disconnect Google Calendar?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            "Scheduled tasks and roadmap dates will stop syncing to your calendar. "
            "Events already created there stay put.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disconnect', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        final ok = await _calendarService.disconnect();
        if (!mounted) return;
        if (ok) {
          setState(() => _calendarConnected = false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't disconnect. Try again.")),
          );
        }
      }
      return;
    }

    final authUrl = await _calendarService.getAuthUrl();
    if (authUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't start Google sign-in. Try again.")),
        );
      }
      return;
    }
    final uri = Uri.parse(authUrl);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in with Google, then come back to the app.'),
          ),
        );
      }
    }
  }

  Future<void> _checkExtensionConnection() async {
    final platforms = await _paymentsService.listPlatforms();
    if (mounted) {
      setState(() {
        _extensionConnected = platforms.any((p) => p.source == 'extension');
      });
    }
  }

  void _showExtensionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Chrome payment extension',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          _extensionConnected
              ? "Active — we've seen at least one subscription saved from the extension. Install it on more browsers from the yxng-core repo's extension/ folder."
              : "No captures yet. This just means we haven't seen a save come through — "
                  "if you're already logged into the extension, that's expected until it "
                  "actually detects and saves a subscription. If you haven't set it up: load it "
                  "from the extension/ folder via chrome://extensions (enable Developer mode → "
                  "Load unpacked), then log in with this same account.",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log out?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          "You'll need to sign back in to access your projects.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Log out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final displayName = auth.username ?? 'Preview mode';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: 'Your '),
                TextSpan(
                  text: 'settings',
                  style: TextStyle(color: AppColors.accent),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 0.6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        gradient: AppColors.heroGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Yxng Core account',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('PROFILE'),
              const SizedBox(height: 10),
              _SettingsRow(
                icon: Icons.description_rounded,
                label: 'Resume / CV',
                trailing: 'Manage',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),
              const _SectionLabel('GENERAL'),
              const SizedBox(height: 10),
              const _SettingsRow(
                icon: Icons.notifications_rounded,
                label: 'Notifications',
                trailing: 'On',
              ),
              const _SettingsRow(
                icon: Icons.dark_mode_rounded,
                label: 'Appearance',
                trailing: 'Dark',
              ),
              const SizedBox(height: 24),
              const _SectionLabel('CONNECTIONS'),
              const SizedBox(height: 10),
              _SettingsRow(
                icon: Icons.credit_card_rounded,
                label: 'Payments & subscriptions',
                trailing: 'Manage',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                  );
                },
              ),
              _SettingsRow(
                icon: Icons.extension_rounded,
                label: 'Chrome payment extension',
                trailing: _extensionConnected ? 'Active' : 'No captures yet',
                onTap: () => _showExtensionInfo(context),
              ),
              _SettingsRow(
                icon: Icons.calendar_month_rounded,
                label: 'Calendar sync',
                trailing: _calendarConnected ? 'Connected' : 'Connect',
                onTap: _handleCalendarTap,
              ),
              const SizedBox(height: 24),
              const _SectionLabel('ABOUT'),
              const SizedBox(height: 10),
              const _SettingsRow(
                icon: Icons.info_outline_rounded,
                label: 'Version',
                trailing: '1.0.0',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmLogout(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.6),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentSoft, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
