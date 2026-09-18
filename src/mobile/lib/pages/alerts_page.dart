import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/client.dart';
import '../api/types.dart';
import '../state/alert_poller.dart';
import '../state/auth_controller.dart';
import '../theme/app_theme.dart';
import '../util/formatting.dart';
import '../util/risk_colors.dart';
import '../widgets/copilot_sheet.dart';
import '../widgets/risk_badge.dart';
import '../widgets/section_label.dart';
import '../widgets/status_states.dart';

/// The crew inbox — what the notification opens into, and the reason the app
/// exists for a field engineer. Everything else in the app is reference
/// material; this is the work.
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final _poller = AlertPoller.instance;

  @override
  void initState() {
    super.initState();
    _poller.addListener(_onChanged);
    if (_poller.alerts.isEmpty) _poller.poll();
  }

  @override
  void dispose() {
    _poller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthController.instance.session;
    final alerts = _poller.alerts;
    final open = alerts.where((a) => a.status == AlertStatus.open).toList();
    final acknowledged = alerts.where((a) => a.isAcknowledged).toList();

    return RefreshIndicator(
      color: AppColors.blue60,
      onRefresh: _poller.poll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          const SectionLabel('Your inbox'),
          const SizedBox(height: 8),
          Text(
            'Alerts',
            style: AppText.serif(size: 30, weight: FontWeight.w600, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            session == null
                ? ''
                : session.isAdmin
                    ? 'Every alert raised across ${session.companyName}.'
                    : 'Raised on the assets assigned to you.',
            style: AppText.serif(
              size: 15,
              color: AppColors.gray70,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Hairline(),

          // Admins get a manual trigger right here in the inbox. Waiting for an
          // asset to cross tiers on its own is fine in production and useless
          // in a demo or a drill, where you need an alert to land on a
          // specific person's phone now.
          if (session?.isAdmin ?? false) ...[
            const SizedBox(height: 20),
            _SendAlertBar(onSent: _poller.poll),
          ],

          const SizedBox(height: 24),

          if (_poller.error != null) ...[
            ErrorBlock(message: _poller.error!, onRetry: _poller.poll),
            const SizedBox(height: 24),
          ],

          if (_poller.loading && alerts.isEmpty)
            const LoadingBlock(label: 'Loading your alerts')
          else if (alerts.isEmpty)
            const EmptyBlock(
              message: 'Nothing needs your attention. Assets you are assigned to '
                  'are all below the High risk threshold.',
            )
          else ...[
            if (open.isNotEmpty) ...[
              SectionLabel('Needs action — ${open.length}'),
              const SizedBox(height: 12),
              for (final alert in open) _AlertCard(alert: alert, poller: _poller),
            ],
            if (acknowledged.isNotEmpty) ...[
              const SizedBox(height: 28),
              SectionLabel('Acknowledged — ${acknowledged.length}'),
              const SizedBox(height: 12),
              for (final alert in acknowledged) _AlertCard(alert: alert, poller: _poller),
            ],
          ],
        ],
      ),
    );
  }
}

class _AlertCard extends StatefulWidget {
  const _AlertCard({required this.alert, required this.poller});

  final Alert alert;
  final AlertPoller poller;

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _acknowledging = false;

  Future<void> _acknowledge() async {
    setState(() => _acknowledging = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.acknowledgeAlert(widget.alert.id);
      widget.poller.markAcknowledgedLocally(widget.alert.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Acknowledged ${widget.alert.assetName}.')),
      );
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(err is ApiError ? err.message : 'Could not acknowledge.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final accent = colorForTier(alert.tier);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          left: BorderSide(color: accent, width: 3),
          top: const BorderSide(color: AppColors.gray20),
          right: const BorderSide(color: AppColors.gray20),
          bottom: const BorderSide(color: AppColors.gray20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RiskBadge(tier: alert.tier, size: BadgeSize.sm),
                const Spacer(),
                if (alert.previousTier != null)
                  Text(
                    '${alert.previousTier} → ${alert.tier.label}',
                    style: AppText.mono(size: 11, color: AppColors.gray60),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.assetName,
              style: AppText.serif(size: 18, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${alert.region} · ${alert.assetId} · risk ${alert.riskScore.toStringAsFixed(1)}/100',
              style: AppText.mono(size: 12, color: AppColors.gray60),
            ),
            const SizedBox(height: 10),
            Text(
              alert.headline,
              style: AppText.sans(size: 14, color: AppColors.gray70, height: 1.5),
            ),

            if (alert.isAcknowledged) ...[
              const SizedBox(height: 10),
              Text(
                'Acknowledged by ${alert.acknowledgedByName ?? 'you'}'
                '${alert.acknowledgedAt != null ? ' · ${formatRelative(DateTime.now().difference(alert.acknowledgedAt!))}' : ''}',
                style: AppText.sans(size: 12, color: AppColors.riskLow, weight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 14),
            const Hairline(),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!alert.isAcknowledged)
                  TextButton(
                    onPressed: _acknowledging ? null : _acknowledge,
                    child: _acknowledging
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            "I'll take it",
                            style: AppText.sans(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppColors.blue60,
                            ),
                          ),
                  ),
                // Hands the whole question to the copilot, which can call the
                // same grounded tools the dashboard uses — so the crew member
                // gets the *reason*, not just the score.
                TextButton(
                  onPressed: () => showCopilotSheet(
                    context,
                    seed: 'What is the threat on ${alert.assetId} '
                        '(${alert.assetName}) and what should I do about it?',
                  ),
                  child: Text(
                    'Ask Volt why',
                    style: AppText.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.blue60,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Open asset',
                  icon: const Icon(Icons.chevron_right, color: AppColors.gray60),
                  onPressed: () => context.go('/assets/${alert.assetId}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin-only shortcut in the inbox: raise a real alert for a chosen teammate
/// without leaving the screen. Deliberately a strip rather than a lone icon —
/// an admin should be able to see what it does before tapping it.
class _SendAlertBar extends StatelessWidget {
  const _SendAlertBar({required this.onSent});

  final Future<void> Function() onSent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined, size: 20, color: AppColors.blue60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trigger an alert',
                  style: AppText.serif(size: 16, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Notify a specific crew member now',
                  style: AppText.sans(size: 12, color: AppColors.gray60),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.push('/admin/send-alert');
              // Anything sent while we were away should show up on return.
              await onSent();
            },
            style: TextButton.styleFrom(
              shape: const RoundedRectangleBorder(),
              backgroundColor: AppColors.blue60,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              'SEND',
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
