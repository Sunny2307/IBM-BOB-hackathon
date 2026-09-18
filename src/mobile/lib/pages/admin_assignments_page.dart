import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/types.dart';
import '../state/async_data.dart';
import '../theme/app_theme.dart';
import '../widgets/section_label.dart';
import '../widgets/status_states.dart';

/// Admin: who is responsible for which region.
///
/// This is the screen that makes alerts mean anything. Until a region has an
/// owner, an alert raised in it reaches nobody — so the page leads with the
/// unassigned regions rather than burying them under the existing rows.
class AdminAssignmentsPage extends StatefulWidget {
  const AdminAssignmentsPage({super.key});

  @override
  State<AdminAssignmentsPage> createState() => _AdminAssignmentsPageState();
}

class _AdminAssignmentsPageState extends State<AdminAssignmentsPage> {
  late final AsyncData<List<Assignment>> _assignments = AsyncData(
    fetcher: api.getAssignments,
    fallback: () => const <Assignment>[],
  )..addListener(_onChanged);

  late final AsyncData<List<OperatorUser>> _users = AsyncData(
    fetcher: api.getUsers,
    fallback: () => const <OperatorUser>[],
  )..addListener(_onChanged);

  /// Regions come from the live asset list, so this always offers exactly the
  /// regions the risk engine actually reports on — no hardcoded list to drift.
  late final AsyncData<List<String>> _regions = AsyncData(
    fetcher: () async {
      final assets = await api.getAssets();
      final regions = assets.map((a) => a.region).toSet().toList()..sort();
      return regions;
    },
    fallback: () => const <String>[],
  )..addListener(_onChanged);

  @override
  void dispose() {
    for (final source in [_assignments, _users, _regions]) {
      source.removeListener(_onChanged);
      source.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _assign(String region) async {
    final users = _users.data ?? const <OperatorUser>[];
    if (users.isEmpty) return;

    final chosen = await showModalBottomSheet<OperatorUser>(
      context: context,
      backgroundColor: AppColors.gray10,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            SectionLabel('Assign $region to'),
            const SizedBox(height: 12),
            for (final user in users)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(user.fullName, style: AppText.serif(size: 16)),
                subtitle: Text(user.role.label,
                    style: AppText.sans(size: 12, color: AppColors.gray60)),
                onTap: () => Navigator.of(context).pop(user),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    // The sheet is awaited, so this page can be gone by the time it closes —
    // reading ScaffoldMessenger off a dead context would throw.
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.createAssignment(userId: chosen.id, scopeValue: region);
      _assignments.refetch();
      messenger.showSnackBar(
        SnackBar(content: Text('$region assigned to ${chosen.fullName}.')),
      );
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(content: Text(err is ApiError ? err.message : 'Could not assign.')),
      );
    }
  }

  Future<void> _remove(Assignment assignment) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.deleteAssignment(assignment.id);
      _assignments.refetch();
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(content: Text(err is ApiError ? err.message : 'Could not remove.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignments = _assignments.data ?? const <Assignment>[];
    final regions = _regions.data ?? const <String>[];
    final covered = assignments.map((a) => a.scopeValue).toSet();
    final uncovered = regions.where((r) => !covered.contains(r)).toList();

    return Scaffold(
      backgroundColor: AppColors.gray10,
      body: RefreshIndicator(
        color: AppColors.blue60,
        onRefresh: () async {
          _assignments.refetch();
          _users.refetch();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            const SectionLabel('Administration'),
            const SizedBox(height: 8),
            Text('Coverage',
                style: AppText.serif(size: 30, weight: FontWeight.w600, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              'An alert only reaches someone if their region is assigned. '
              'Unassigned regions raise alerts nobody receives.',
              style: AppText.serif(
                  size: 15, color: AppColors.gray70, fontStyle: FontStyle.italic, height: 1.5),
            ),
            const SizedBox(height: 20),
            const Hairline(),
            const SizedBox(height: 24),

            if (uncovered.isNotEmpty) ...[
              SectionLabel('Nobody assigned — ${uncovered.length}',
                  color: AppColors.riskCritical),
              const SizedBox(height: 12),
              for (final region in uncovered)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.riskCriticalBg,
                    border: Border(
                      left: BorderSide(color: AppColors.riskCritical, width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(region, style: AppText.serif(size: 16, weight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: () => _assign(region),
                        child: Text('Assign',
                            style: AppText.sans(
                                size: 13, weight: FontWeight.w600, color: AppColors.blue60)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],

            SectionLabel('Assigned — ${assignments.length}'),
            const SizedBox(height: 12),
            if (_assignments.loading)
              const LoadingBlock(label: 'Loading coverage')
            else if (assignments.isEmpty)
              const EmptyBlock(message: 'No regions assigned yet.')
            else
              for (final assignment in assignments)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.gray20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(assignment.scopeValue,
                                style: AppText.serif(size: 16, weight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                              '${assignment.scopeType} · ${assignment.userName}',
                              style: AppText.sans(size: 13, color: AppColors.gray70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove assignment',
                        icon: const Icon(Icons.close, size: 18, color: AppColors.gray60),
                        onPressed: () => _remove(assignment),
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
