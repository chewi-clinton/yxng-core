import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class TailoredResumeScreen extends StatelessWidget {
  final String jobTitle;
  final String jobOrg;
  final String tailoredResume;
  final VoidCallback onContinueToApplication;

  const TailoredResumeScreen({
    super.key,
    required this.jobTitle,
    required this.jobOrg,
    required this.tailoredResume,
    required this.onContinueToApplication,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Tailored for $jobOrg'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Reworked to fit \"$jobTitle\" — review it, then continue to the "
                    "real application page and attach it there.",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 0.6),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  tailoredResume,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tailoredResume));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    child: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onContinueToApplication,
                    child: const Text('Continue to application'),
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
