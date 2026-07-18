import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/opportunity.dart';
import '../services/opportunities_service.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_badge.dart';
import '../widgets/progress_bar.dart';

class _Roadmap {
  final String title;
  final String stage;
  final double progress;
  final IconData icon;

  const _Roadmap({
    required this.title,
    required this.stage,
    required this.progress,
    required this.icon,
  });
}

const _defaultRoadmaps = [
  _Roadmap(
    title: 'Advanced Flutter',
    stage: 'State management deep dive',
    progress: 0.6,
    icon: Icons.flutter_dash_rounded,
  ),
  _Roadmap(
    title: 'System design',
    stage: 'Scaling data stores',
    progress: 0.25,
    icon: Icons.hub_rounded,
  ),
  _Roadmap(
    title: 'AI automation',
    stage: 'Agent orchestration basics',
    progress: 0.1,
    icon: Icons.smart_toy_rounded,
  ),
];

const _attributionSources = {
  'Remote OK': 'https://remoteok.com',
  'Remotive': 'https://remotive.com',
  'Jobicy': 'https://jobicy.com',
};

class SkillsTab extends StatefulWidget {
  const SkillsTab({super.key});

  @override
  State<SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends State<SkillsTab> {
  final List<_Roadmap> _roadmaps = [..._defaultRoadmaps];
  final _opportunitiesService = OpportunitiesService();
  late Future<List<Opportunity>> _opportunitiesFuture;
  final Set<String> _activeFilters = {};

  @override
  void initState() {
    super.initState();
    _opportunitiesFuture = _opportunitiesService.fetchAll();
  }

  void _reloadOpportunities() {
    setState(() {
      _opportunitiesFuture = _opportunitiesService.fetchAll();
    });
  }

  Future<void> _addRoadmap() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'What do you want to learn?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. GraphQL, Rust, UI design'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      setState(() {
        _roadmaps.add(
          _Roadmap(
            title: title,
            stage: 'Just started',
            progress: 0,
            icon: Icons.auto_awesome_rounded,
          ),
        );
      });
    }
  }

  Future<void> _openListing(Opportunity o) async {
    final uri = Uri.tryParse(o.url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that listing')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                TextSpan(text: 'Keep '),
                TextSpan(
                  text: 'growing',
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
              Row(
                children: [
                  const Expanded(child: _SectionLabel('LEARNING ROADMAPS')),
                  GestureDetector(
                    onTap: _addRoadmap,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final r in _roadmaps) ...[
                _RoadmapCard(roadmap: r),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: _SectionLabel('OPPORTUNITIES · LIVE')),
                  GestureDetector(
                    onTap: _reloadOpportunities,
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Opportunity>>(
                future: _opportunitiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    );
                  }
                  final opportunities = snapshot.data ?? [];
                  if (opportunities.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Text(
                            "Couldn't load live opportunities.",
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _reloadOpportunities,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    );
                  }

                  final types = opportunities.map((o) => o.type).toSet().toList();
                  final filtered = _activeFilters.isEmpty
                      ? opportunities
                      : opportunities
                          .where((o) => _activeFilters.contains(o.type))
                          .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final type in types) ...[
                              _FilterChip(
                                label: type,
                                selected: _activeFilters.contains(type),
                                onTap: () {
                                  setState(() {
                                    _activeFilters.contains(type)
                                        ? _activeFilters.remove(type)
                                        : _activeFilters.add(type);
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final o in filtered) ...[
                        _OpportunityCard(
                          opportunity: o,
                          onTap: () => _openListing(o),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (opportunities.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 6,
                            children: [
                              const Text(
                                'Sourced from',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              for (final source in _attributionSources.entries) ...[
                                GestureDetector(
                                  onTap: () => launchUrl(
                                    Uri.parse(source.value),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  child: Text(
                                    source.key,
                                    style: const TextStyle(
                                      color: AppColors.accentSoft,
                                      fontSize: 11,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 0.6,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  final _Roadmap roadmap;
  const _RoadmapCard({required this.roadmap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 0.6),
      ),
      child: Row(
        children: [
          IconBadge(icon: roadmap.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roadmap.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  roadmap.stage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                YProgressBar(value: roadmap.progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final Opportunity opportunity;
  final VoidCallback onTap;
  const _OpportunityCard({required this.opportunity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 0.6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opportunity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    opportunity.tagline != null
                        ? '${opportunity.org} · ${opportunity.tagline}'
                        : opportunity.org,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.open_in_new_rounded,
              color: AppColors.accentSoft,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
