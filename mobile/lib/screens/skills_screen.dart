import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/opportunity.dart';
import '../models/resume.dart';
import '../models/roadmap.dart';
import '../services/opportunities_service.dart';
import '../services/resume_service.dart';
import '../services/roadmap_service.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_badge.dart';
import '../widgets/progress_bar.dart';
import 'profile_screen.dart';
import 'tailored_resume_screen.dart';

const _attributionSources = {
  'Remote OK': 'https://remoteok.com',
  'Remotive': 'https://remotive.com',
  'Jobicy': 'https://jobicy.com',
};

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class SkillsTab extends StatefulWidget {
  const SkillsTab({super.key});

  @override
  State<SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends State<SkillsTab> {
  final _roadmapService = RoadmapService();
  final _opportunitiesService = OpportunitiesService();
  final _resumeService = ResumeService();
  List<Roadmap>? _roadmaps;
  late Future<List<Opportunity>> _opportunitiesFuture;
  final Set<String> _activeFilters = {};

  @override
  void initState() {
    super.initState();
    _opportunitiesFuture = _opportunitiesService.fetchAll();
    _loadRoadmaps();
  }

  Future<void> _loadRoadmaps() async {
    final roadmaps = await _roadmapService.listRoadmaps();
    if (mounted) setState(() => _roadmaps = roadmaps);
  }

  void _reloadOpportunities() {
    setState(() {
      _opportunitiesFuture = _opportunitiesService.fetchAll();
    });
  }

  Future<void> _addRoadmap() async {
    final controller = TextEditingController();
    DateTime? targetDate;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What do you want to learn?',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "AI will generate a real milestone-by-milestone roadmap for it.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'e.g. GraphQL, Rust, UI design',
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setSheetState(() => targetDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 0.6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_rounded,
                            color: AppColors.accentSoft,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            targetDate == null
                                ? 'Target date · Tap to set (optional)'
                                : 'Target · ${_formatDate(targetDate!)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Generate roadmap'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    final title = controller.text.trim();
    if (submitted != true || title.isEmpty || !mounted) return;

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => Center(
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border, width: 0.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 70,
                child: Lottie.asset('assets/lottie/ai_thinking_pulse.json', repeat: true),
              ),
              const SizedBox(height: 20),
              const Text(
                'AI is mapping your roadmap…',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ));

    try {
      final results = await Future.wait([
        _roadmapService.createRoadmap(title: title, targetDate: targetDate),
        Future.delayed(const Duration(milliseconds: 2200)),
      ]);
      final roadmap = results[0] as Roadmap;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _roadmaps = [...?_roadmaps, roadmap]);
      }
    } on RoadmapGenerationException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _deleteRoadmap(Roadmap roadmap) async {
    final roadmaps = _roadmaps;
    if (roadmaps == null) return;
    final removedIndex = roadmaps.indexOf(roadmap);
    setState(() => _roadmaps = [...roadmaps]..remove(roadmap));

    await _roadmapService.deleteRoadmap(roadmap.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        content: Text('"${roadmap.title}" deleted'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accentSoft,
          onPressed: () {
            setState(() {
              final current = [...?_roadmaps];
              current.insert(removedIndex.clamp(0, current.length), roadmap);
              _roadmaps = current;
            });
          },
        ),
      ),
    );
  }

  void _openRoadmap(Roadmap summary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _RoadmapDetailBody(
          roadmapId: summary.id,
          roadmapService: _roadmapService,
          scrollController: scrollController,
          onUpdated: (updated) {
            setState(() {
              _roadmaps = [
                for (final r in _roadmaps ?? <Roadmap>[])
                  if (r.id == updated.id) updated else r,
              ];
            });
          },
        ),
      ),
    );
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

  void _openOpportunityDetail(Opportunity o) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                o.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                o.tagline != null ? '${o.org} · ${o.tagline}' : o.org,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    o.description.isEmpty
                        ? 'No description provided for this listing.'
                        : o.description,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openListing(o),
                      child: const Text('View original posting'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _startApplyFlow(o);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startApplyFlow(Opportunity o) async {
    final ResumeInfo? resume;
    try {
      resume = await _resumeService.getResume();
    } on ResumeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;

    if (resume == null) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceAlt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Upload your resume first',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            "We need a resume on file to tailor one for this job. Upload a PDF from your "
            "profile, then come back and apply.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: const Text('Go to profile'),
            ),
          ],
        ),
      );
      return;
    }

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => Center(
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border, width: 0.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 70,
                child: Lottie.asset('assets/lottie/ai_thinking_pulse.json', repeat: true),
              ),
              const SizedBox(height: 20),
              const Text(
                'AI is tailoring your resume…',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ));

    try {
      final results = await Future.wait([
        _resumeService.tailorResume(
          jobTitle: o.title,
          jobOrg: o.org,
          jobDescription: o.description,
        ),
        Future.delayed(const Duration(milliseconds: 2200)),
      ]);
      final tailored = results[0] as String;
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TailoredResumeScreen(
            jobTitle: o.title,
            jobOrg: o.org,
            tailoredResume: tailored,
            onContinueToApplication: () => _openListing(o),
          ),
        ),
      );
    } on ResumeException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
              if (_roadmaps == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (_roadmaps!.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    "No roadmaps yet — tap + and tell the AI what you want to learn.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )
              else
                for (final r in _roadmaps!) ...[
                  Dismissible(
                    key: ValueKey(r.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteRoadmap(r),
                    child: _RoadmapCard(roadmap: r, onTap: () => _openRoadmap(r)),
                  ),
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
                          onTap: () => _openOpportunityDetail(o),
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
  final Roadmap roadmap;
  final VoidCallback onTap;
  const _RoadmapCard({required this.roadmap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 0.6),
        ),
        child: Row(
          children: [
            const IconBadge(icon: Icons.flag_rounded),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapDetailBody extends StatefulWidget {
  final int roadmapId;
  final RoadmapService roadmapService;
  final ScrollController scrollController;
  final ValueChanged<Roadmap> onUpdated;

  const _RoadmapDetailBody({
    required this.roadmapId,
    required this.roadmapService,
    required this.scrollController,
    required this.onUpdated,
  });

  @override
  State<_RoadmapDetailBody> createState() => _RoadmapDetailBodyState();
}

class _RoadmapDetailBodyState extends State<_RoadmapDetailBody> {
  Roadmap? _roadmap;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final roadmap = await widget.roadmapService.getRoadmap(widget.roadmapId);
    if (mounted) setState(() => _roadmap = roadmap);
  }

  Future<void> _toggleMilestone(int index) async {
    final roadmap = _roadmap;
    if (roadmap == null) return;
    final milestone = roadmap.milestones[index];
    final newStatus = milestone.done ? 'todo' : 'done';
    final updatedMilestones = [...roadmap.milestones];
    updatedMilestones[index] = Milestone(
      id: milestone.id,
      title: milestone.title,
      description: milestone.description,
      order: milestone.order,
      status: newStatus,
      targetDate: milestone.targetDate,
    );
    final updated = roadmap.copyWith(milestones: updatedMilestones);
    setState(() => _roadmap = updated);
    widget.onUpdated(updated);

    await widget.roadmapService.updateMilestoneStatus(
      roadmapId: roadmap.id,
      milestoneIndex: index,
      milestoneId: milestone.id,
      status: newStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roadmap = _roadmap;
    if (roadmap == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.flag_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roadmap.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                    if (roadmap.targetDate != null)
                      Text(
                        'Target · ${_formatDate(roadmap.targetDate!)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          YProgressBar(value: roadmap.progress),
          const SizedBox(height: 6),
          Text(
            '${(roadmap.progress * 100).round()}% complete · ${roadmap.stage}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              itemCount: roadmap.milestones.length,
              itemBuilder: (context, index) {
                final m = roadmap.milestones[index];
                final isLast = index == roadmap.milestones.length - 1;
                return _MilestoneRow(
                  milestone: m,
                  isLast: isLast,
                  onToggle: () => _toggleMilestone(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final Milestone milestone;
  final bool isLast;
  final VoidCallback onToggle;

  const _MilestoneRow({
    required this.milestone,
    required this.isLast,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: milestone.done ? AppColors.accent : AppColors.surface,
                    border: Border.all(
                      color: milestone.done ? AppColors.accent : AppColors.border,
                      width: 1.4,
                    ),
                  ),
                  child: milestone.done
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            milestone.title,
                            style: TextStyle(
                              color: milestone.done
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              decoration: milestone.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (milestone.targetDate != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _formatDate(milestone.targetDate!),
                              style: const TextStyle(
                                color: AppColors.accentSoft,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (milestone.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        milestone.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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
