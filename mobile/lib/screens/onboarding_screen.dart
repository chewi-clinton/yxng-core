import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';

class _OnboardingPage {
  final String headline;
  final String highlight;
  final String headlineTail;
  final String subtext;
  final IconData? icon;
  final String? logoAsset;
  final String? lottieAsset;

  const _OnboardingPage({
    required this.headline,
    required this.highlight,
    required this.headlineTail,
    required this.subtext,
    this.icon,
    this.logoAsset,
    this.lottieAsset,
  });
}

const _pages = [
  _OnboardingPage(
    headline: 'This is your ',
    highlight: 'core',
    headlineTail: '.',
    subtext: 'One system for your projects, schedule, payments, and growth.',
    logoAsset: 'assets/logo/yxng_core_logo.png',
  ),
  _OnboardingPage(
    headline: 'Describe it. ',
    highlight: 'AI',
    headlineTail: ' builds the plan.',
    subtext: "Tell it what you're building — it breaks the work into scheduled tasks automatically.",
    lottieAsset: 'assets/lottie/ai_thinking_pulse.json',
  ),
  _OnboardingPage(
    headline: 'Your time, ',
    highlight: 'protected',
    headlineTail: '.',
    subtext: 'Tasks slot into your free time. Bills and renewals remind you before they\'re due.',
    icon: Icons.shield_moon_rounded,
  ),
  _OnboardingPage(
    headline: 'Keep ',
    highlight: 'growing',
    headlineTail: '.',
    subtext: 'Structured learning roadmaps and real opportunities, surfaced for you.',
    icon: Icons.trending_up_rounded,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _secureStorage = const FlutterSecureStorage();
  int _index = 0;

  Future<void> _finish() async {
    await _secureStorage.write(key: 'onboarding_complete', value: 'true');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _OnboardingPageView(page: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(_pages.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? AppColors.accent : AppColors.muted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _index == _pages.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (page.logoAsset != null)
            Image.asset(page.logoAsset!, width: 112, height: 112)
          else if (page.lottieAsset != null)
            SizedBox(
              height: 96,
              child: Lottie.asset(
                page.lottieAsset!,
                repeat: true,
                fit: BoxFit.fitHeight,
                alignment: Alignment.centerLeft,
              ),
            )
          else
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(page.icon, color: AppColors.accent, size: 44),
            ),
          const SizedBox(height: 48),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
                height: 1.15,
              ),
              children: [
                TextSpan(text: page.headline),
                TextSpan(
                  text: page.highlight,
                  style: const TextStyle(color: AppColors.accent),
                ),
                TextSpan(text: page.headlineTail),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.subtext,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
