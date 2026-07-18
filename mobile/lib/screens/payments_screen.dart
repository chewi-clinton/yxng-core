import 'package:flutter/material.dart';

import '../models/linked_platform.dart';
import '../services/payments_service.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_badge.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _paymentsService = PaymentsService();
  List<LinkedPlatform>? _platforms;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final platforms = await _paymentsService.listPlatforms();
    if (mounted) setState(() => _platforms = platforms);
  }

  IconData _iconFor(PlatformIcon id) {
    switch (id) {
      case PlatformIcon.streaming:
        return Icons.smart_display_rounded;
      case PlatformIcon.music:
        return Icons.music_note_rounded;
      case PlatformIcon.cloud:
        return Icons.cloud_rounded;
      case PlatformIcon.software:
        return Icons.code_rounded;
      case PlatformIcon.other:
        return Icons.credit_card_rounded;
    }
  }

  Color _urgencyColor(int daysLeft) {
    if (daysLeft <= 2) return AppColors.error;
    if (daysLeft <= 7) return AppColors.accentSoft;
    return AppColors.textSecondary;
  }

  Future<void> _deletePlatform(LinkedPlatform platform) async {
    final removedIndex = _platforms!.indexOf(platform);
    setState(() => _platforms!.remove(platform));
    await _paymentsService.deletePlatform(platform.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        content: Text('"${platform.name}" removed'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accentSoft,
          onPressed: () {
            setState(() {
              _platforms!.insert(
                removedIndex.clamp(0, _platforms!.length),
                platform,
              );
            });
          },
        ),
      ),
    );
  }

  Future<void> _showAddSheet() async {
    final nameController = TextEditingController();
    final cardController = TextEditingController();
    final amountController = TextEditingController();
    DateTime renewsOn = DateTime.now().add(const Duration(days: 30));

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            28,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    TextSpan(text: 'Link a '),
                    TextSpan(
                      text: 'platform',
                      style: TextStyle(color: AppColors.accent),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Service name'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: cardController,
                decoration: const InputDecoration(hintText: 'Card (e.g. Visa •••• 4242)'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'Amount'),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: renewsOn,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setSheetState(() => renewsOn = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 0.6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: AppColors.accentSoft, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        'Renews ${renewsOn.month}/${renewsOn.day}/${renewsOn.year}',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Link platform'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (added == true && nameController.text.trim().isNotEmpty) {
      final amount = double.tryParse(amountController.text.trim()) ?? 0;
      final platform = await _paymentsService.addPlatform(
        name: nameController.text.trim(),
        cardLabel: cardController.text.trim(),
        amount: amount,
        renewsOn: renewsOn,
      );
      setState(() {
        _platforms = [...?_platforms, platform];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final platforms = _platforms;
    final sorted = platforms == null
        ? null
        : ([...platforms]..sort((a, b) => a.renewsOn.compareTo(b.renewsOn)));
    final monthlyTotal =
        sorted?.fold<double>(0, (sum, p) => sum + p.amount) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments & subscriptions'),
        actions: [
          IconButton(
            onPressed: _showAddSheet,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: sorted == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Linked this month',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${monthlyTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${sorted.length} platforms',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (sorted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Nothing linked yet. Tap + to add one.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else ...[
                  const Text(
                    'RENEWALS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final platform in sorted) ...[
                    Dismissible(
                      key: ValueKey(platform.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: AppColors.errorSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) => _deletePlatform(platform),
                      child: _PlatformCard(
                        platform: platform,
                        icon: _iconFor(platform.icon),
                        urgencyColor: _urgencyColor(
                          platform.renewsOn.difference(DateTime.now()).inDays,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 0.6),
                  ),
                  child: Row(
                    children: [
                      const IconBadge(icon: Icons.extension_rounded, size: 44),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chrome extension',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Not connected — install it to auto-capture new payments.',
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
              ],
            ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final LinkedPlatform platform;
  final IconData icon;
  final Color urgencyColor;

  const _PlatformCard({
    required this.platform,
    required this.icon,
    required this.urgencyColor,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = platform.renewsOn.difference(DateTime.now()).inDays;
    final label = daysLeft <= 0
        ? 'Renews today'
        : daysLeft == 1
            ? 'Renews tomorrow'
            : 'Renews in $daysLeft days';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.6),
      ),
      child: Row(
        children: [
          IconBadge(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (platform.cardLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    platform.cardLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${platform.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: urgencyColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
