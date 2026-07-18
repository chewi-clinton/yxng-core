import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../models/project.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_badge.dart';
import 'project_detail_screen.dart';

class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key});

  @override
  State<ProjectsTab> createState() => ProjectsTabState();
}

class ProjectsTabState extends State<ProjectsTab> {
  final _projectService = ProjectService();
  List<Project>? _projects;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final projects = await _projectService.listProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _deleteProject(Project project) async {
    final removedIndex = _projects!.indexOf(project);
    setState(() => _projects!.remove(project));

    await _projectService.deleteProject(project.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        content: Text('"${project.title}" deleted'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accentSoft,
          onPressed: () {
            setState(() {
              _projects!.insert(
                removedIndex.clamp(0, _projects!.length),
                project,
              );
            });
          },
        ),
      ),
    );
  }

  Future<void> showCreateSheet() async {
    final titleController = TextEditingController();
    final techStackController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime? targetEndDate;
    bool letAiDecide = true;

    final created = await showModalBottomSheet<bool>(
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
          child: SingleChildScrollView(
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
                      TextSpan(text: 'New '),
                      TextSpan(
                        text: 'project',
                        style: TextStyle(color: AppColors.accent),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Title'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: techStackController,
                  decoration: const InputDecoration(
                    hintText: 'Tech stack (comma separated)',
                  ),
                ),
                const SizedBox(height: 14),
                _DatePickerRow(
                  icon: Icons.event_rounded,
                  label: 'Start · ${_formatDate(startDate)}',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() => startDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerRow(
                        icon: Icons.flag_rounded,
                        label: letAiDecide
                            ? 'Target date · AI decides'
                            : targetEndDate == null
                                ? 'Target date · Tap to set'
                                : 'Target · ${_formatDate(targetEndDate!)}',
                        enabled: !letAiDecide,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: targetEndDate ??
                                startDate.add(const Duration(days: 7)),
                            firstDate: startDate,
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (picked != null) {
                            setSheetState(() => targetEndDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setSheetState(() => letAiDecide = !letAiDecide),
                  child: Row(
                    children: [
                      Icon(
                        letAiDecide
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Let AI recommend a timeline based on the work",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (created == true && titleController.text.trim().isNotEmpty) {
      final title = titleController.text.trim();
      final techStack = techStackController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (!mounted) return;
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
                  child: Lottie.asset(
                    'assets/lottie/ai_thinking_pulse.json',
                    repeat: true,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'AI is planning your tasks…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));

      // Keep the dialog up for at least a couple of pulse loops so it reads
      // as intentional feedback rather than a flash, even if the request
      // (mock or real) resolves almost instantly.
      final results = await Future.wait([
        _projectService.createProject(
          title: title,
          techStack: techStack,
          startDate: startDate,
          targetEndDate: letAiDecide ? null : targetEndDate,
        ),
        Future.delayed(const Duration(milliseconds: 2200)),
      ]);
      final project = results[0] as Project;

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _projects = [...?_projects, project];
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
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
                TextSpan(text: 'Your '),
                TextSpan(
                  text: 'projects',
                  style: TextStyle(color: AppColors.accent),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Couldn\'t load projects.\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final projects = _projects;
    if (projects == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (projects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: Icons.rocket_launch_rounded, size: 64),
            SizedBox(height: 16),
            Text(
              'No projects yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap + to describe one — AI plans the rest.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      itemCount: projects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final project = projects[index];
        return Dismissible(
          key: ValueKey(project.id),
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
          onDismissed: (_) => _deleteProject(project),
          child: _ProjectCard(
            project: project,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProjectDetailScreen(projectId: project.id),
                ),
              );
              _load();
            },
          ),
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

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
            const IconBadge(icon: Icons.folder_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (project.techStack.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      project.techStack.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${project.taskCount ?? project.tasks.length} tasks',
              style: const TextStyle(
                color: AppColors.accentSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _DatePickerRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.6),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accentSoft, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
              if (enabled)
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
