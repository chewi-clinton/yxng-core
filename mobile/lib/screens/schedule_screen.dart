import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/mock_data.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_badge.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduledItem {
  final Task task;
  final Project project;

  const _ScheduledItem(this.task, this.project);
}

class _ScheduleTabState extends State<ScheduleTab> {
  final _projectService = ProjectService();
  List<Project>? _projects;
  List<Task>? _personalTasks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await _projectService.listProjects();
    final personal = await _projectService.listPersonalTasks();
    if (mounted) {
      setState(() {
        _projects = projects;
        _personalTasks = personal;
      });
    }
  }

  Future<void> _showAddReminderSheet() async {
    final titleController = TextEditingController();
    DateTime start = DateTime.now().add(const Duration(hours: 1));
    Duration duration = const Duration(hours: 1);

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
                    TextSpan(text: 'New '),
                    TextSpan(
                      text: 'reminder',
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
                decoration: const InputDecoration(hintText: 'What do you need to do?'),
              ),
              const SizedBox(height: 14),
              _PickerRow(
                icon: Icons.event_rounded,
                label: _formatDateTime(start),
                onTap: () async {
                  final picked = await _pickDateTime(context, start);
                  if (picked != null) setSheetState(() => start = picked);
                },
              ),
              const SizedBox(height: 10),
              _PickerRow(
                icon: Icons.timer_outlined,
                label: '${duration.inMinutes} min',
                onTap: () async {
                  final picked = await showDialog<int>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      backgroundColor: AppColors.surfaceAlt,
                      title: const Text(
                        'Duration',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      children: [15, 30, 60, 90, 120].map((m) {
                        return SimpleDialogOption(
                          onPressed: () => Navigator.of(context).pop(m),
                          child: Text(
                            '$m min',
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() => duration = Duration(minutes: picked));
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Add to schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (added == true && titleController.text.trim().isNotEmpty) {
      await _projectService.addReminder(
        title: titleController.text.trim(),
        start: start,
        end: start.add(duration),
      );
      _load();
    }
  }

  Future<void> _showDetail(_ScheduledItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.task.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.project.title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (item.task.scheduledStart != null)
              _PickerRow(
                icon: Icons.schedule_rounded,
                label:
                    '${_formatDateTime(item.task.scheduledStart!)} · ${_time(item.task.scheduledStart!)}–${_time(item.task.scheduledEnd!)}',
                onTap: () async {
                  final picked = await _pickDateTime(
                    context,
                    item.task.scheduledStart!,
                  );
                  if (picked == null) return;
                  final duration = item.task.scheduledEnd!
                      .difference(item.task.scheduledStart!);
                  await _projectService.rescheduleTask(
                    item.task.id,
                    picked,
                    picked.add(duration),
                  );
                  if (context.mounted) Navigator.of(context).pop();
                  _load();
                },
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await _projectService.updateTaskStatus(item.task.id, 'done');
                  if (context.mounted) Navigator.of(context).pop();
                  _load();
                },
                child: const Text('Mark as done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _time(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              Expanded(
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
                        text: 'schedule',
                        style: TextStyle(color: AppColors.accent),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showAddReminderSheet,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    final projects = _projects;
    final personalTasks = _personalTasks;
    if (projects == null || personalTasks == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final scheduled = <_ScheduledItem>[];
    final unscheduled = <_ScheduledItem>[];
    for (final task in personalTasks) {
      if (task.status == 'done') continue;
      (task.scheduledStart != null ? scheduled : unscheduled)
          .add(_ScheduledItem(task, personalProject));
    }
    for (final project in projects) {
      for (final task in project.tasks) {
        if (task.status == 'done') continue;
        (task.scheduledStart != null ? scheduled : unscheduled)
            .add(_ScheduledItem(task, project));
      }
    }
    scheduled.sort(
      (a, b) => a.task.scheduledStart!.compareTo(b.task.scheduledStart!),
    );

    if (scheduled.isEmpty && unscheduled.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: Icons.calendar_today_rounded, size: 64),
            SizedBox(height: 16),
            Text(
              'Nothing on the schedule',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap + to add a reminder, or create a project.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final groups = <String, List<_ScheduledItem>>{};
    for (final item in scheduled) {
      final day = _dayLabel(item.task.scheduledStart!);
      groups.putIfAbsent(day, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 6),
            child: Text(
              entry.key,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ),
          for (final item in entry.value) ...[
            _ScheduleTile(item: item, onTap: () => _showDetail(item)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
        ],
        if (unscheduled.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10, top: 6),
            child: Text(
              'UNSCHEDULED',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ),
          for (final item in unscheduled) ...[
            _ScheduleTile(item: item, onTap: () => _showDetail(item)),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    if (diff == -1) return 'YESTERDAY';
    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.month}/${date.day}';
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final _ScheduledItem item;
  final VoidCallback onTap;

  const _ScheduleTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final start = item.task.scheduledStart;
    final end = item.task.scheduledEnd;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 0.6),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.project.title,
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
            if (start != null && end != null) ...[
              const SizedBox(width: 12),
              Text(
                '${_shortTime(start)}–${_shortTime(end)}',
                style: const TextStyle(
                  color: AppColors.accentSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  String _shortTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
