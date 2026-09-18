import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/types.dart';
import '../state/async_data.dart';
import '../theme/app_theme.dart';
import '../util/formatting.dart';
import '../util/risk_colors.dart';
import '../widgets/risk_badge.dart';
import '../widgets/section_label.dart';
import '../widgets/status_states.dart';

/// Admin: raise an alert so a named person is notified now.
///
/// The alert this sends is a REAL one — same table, same headline wording,
/// same one-open-alert-per-asset rule as the automatic monitor. There is no
/// separate "test notification" path, because a test that doesn't exercise the
/// real pipeline proves nothing about whether the real pipeline works.
///
/// The recipient must have an assignment; a field user with none can't see any
/// alert at all. Rather than let an admin send into the void, the asset picker
/// only offers assets inside the recipient's scope, and an unassigned user is
/// called out with the fix ("assign them a region first") instead of a silent
/// no-op.
class AdminSendAlertPage extends StatefulWidget {
  const AdminSendAlertPage({super.key});

  @override
  State<AdminSendAlertPage> createState() => _AdminSendAlertPageState();
}

class _AdminSendAlertPageState extends State<AdminSendAlertPage> {
  late final AsyncData<List<OperatorUser>> _users = AsyncData(
    fetcher: api.getUsers,
    fallback: () => const <OperatorUser>[],
  )..addListener(_onChanged);

  OperatorUser? _recipient;
  List<AssignableAsset>? _assets;
  AssignableAsset? _chosenAsset;
  bool _loadingAssets = false;
  bool _sending = false;
  String? _error;
  SentAlert? _sent;

  @override
  void dispose() {
    _users.removeListener(_onChanged);
    _users.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectRecipient(OperatorUser user) async {
    setState(() {
      _recipient = user;
      _assets = null;
      _chosenAsset = null;
      _error = null;
      _sent = null;
      _loadingAssets = true;
    });

    try {
      final assets = await api.getAssignableAssets(user.id);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _loadingAssets = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loadingAssets = false;
        _error = err is ApiError ? err.message : 'Could not load their assets.';
      });
    }
  }

  Future<void> _send() async {
    final recipient = _recipient;
    if (recipient == null || _sending) return;

    setState(() {
      _sending = true;
      _error = null;
      _sent = null;
    });

    try {
      final sent = await api.sendAlert(
        userId: recipient.id,
        assetId: _chosenAsset?.assetId,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = sent;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = err is ApiError ? err.message : 'Could not send the alert.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users.data ?? const <OperatorUser>[];
    final recipient = _recipient;
    final assets = _assets;
    final hasNoScope = assets != null && assets.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.gray10,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          const SectionLabel('Notify a crew member'),
          const SizedBox(height: 8),
          Text(
            'Send Alert',
            style: AppText.serif(
              size: 32,
              weight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Raises a real alert on one of their assets, so it reaches their '
            'inbox and their phone straight away.',
            style: AppText.serif(
              size: 15,
              color: AppColors.gray70,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Hairline(),
          const SizedBox(height: 24),

          const SectionLabel('1 · Recipient'),
          const SizedBox(height: 12),
          if (_users.loading)
            const LoadingBlock(label: 'Loading team')
          else if (users.isEmpty)
            const EmptyBlock(message: 'No team members yet.')
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.gray20),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < users.length; i++) ...[
                    if (i > 0) const Hairline(),
                    _RecipientRow(
                      user: users[i],
                      selected: recipient?.id == users[i].id,
                      onTap: () => _selectRecipient(users[i]),
                    ),
                  ],
                ],
              ),
            ),

          if (recipient != null) ...[
            const SizedBox(height: 32),
            const SectionLabel('2 · Which asset'),
            const SizedBox(height: 12),
            if (_loadingAssets)
              const LoadingBlock(label: 'Checking their coverage')
            else if (hasNoScope)
              _NoScopeNotice(name: recipient.fullName)
            else if (assets != null)
              _AssetPicker(
                assets: assets,
                chosen: _chosenAsset,
                onChanged: (asset) => setState(() => _chosenAsset = asset),
              ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 20),
            ErrorBlock(message: _error!),
          ],

          if (_sent != null) ...[
            const SizedBox(height: 20),
            _SentConfirmation(sent: _sent!),
          ],

          if (recipient != null && !hasNoScope && assets != null) ...[
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue60,
                  disabledBackgroundColor: AppColors.gray30,
                  shape: const RoundedRectangleBorder(),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        'SEND ALERT TO ${recipient.fullName.toUpperCase()}',
                        textAlign: TextAlign.center,
                        style: AppText.sans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: AppColors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final OperatorUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: selected ? AppColors.blue20 : null,
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? AppColors.blue60 : AppColors.gray30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: AppText.serif(size: 16, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: AppText.sans(size: 12, color: AppColors.gray60),
                    ),
                  ],
                ),
              ),
              Text(
                user.role.label.toUpperCase(),
                style: AppText.kicker(size: 10),
              ),
            ],
          ),
        ),
      );
}

/// A recipient with no assignments cannot see any alert, so say so plainly and
/// name the fix rather than letting the admin press a button that will fail.
class _NoScopeNotice extends StatelessWidget {
  const _NoScopeNotice({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.riskMediumBg,
          border: Border(
            left: BorderSide(color: AppColors.riskMedium, width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name has no coverage yet',
              style: AppText.sans(size: 14, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Alerts only reach the people responsible for that asset. Assign '
              'them a region on the Coverage tab, then come back and send.',
              style: AppText.sans(
                size: 13,
                color: AppColors.gray70,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
}

class _AssetPicker extends StatelessWidget {
  const _AssetPicker({
    required this.assets,
    required this.chosen,
    required this.onChanged,
  });

  final List<AssignableAsset> assets;
  final AssignableAsset? chosen;
  final ValueChanged<AssignableAsset?> onChanged;

  @override
  Widget build(BuildContext context) {
    final top = assets.first;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onChanged(null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: chosen == null ? AppColors.blue20 : null,
              child: Row(
                children: [
                  Icon(
                    chosen == null
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color:
                        chosen == null ? AppColors.blue60 : AppColors.gray30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Highest risk in their area',
                          style: AppText.serif(
                            size: 16,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${top.name} · ${formatScore(top.riskScore)}/100',
                          style: AppText.sans(
                            size: 12,
                            color: AppColors.gray60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RiskBadge(tier: top.riskTier, size: BadgeSize.sm),
                ],
              ),
            ),
          ),
          const Hairline(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'or pick one of ${assets.length}',
                    style: AppText.sans(size: 13, color: AppColors.gray70),
                  ),
                ),
                Flexible(
                  child: DropdownButton<AssignableAsset?>(
                    value: chosen,
                    hint: Text(
                      'Choose asset',
                      style: AppText.sans(size: 13, color: AppColors.blue60),
                    ),
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.zero,
                    dropdownColor: AppColors.white,
                    onChanged: onChanged,
                    items: [
                      for (final asset in assets)
                        DropdownMenuItem<AssignableAsset?>(
                          value: asset,
                          child: Text(
                            '${asset.name} · ${formatScore(asset.riskScore)}',
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sans(
                              size: 13,
                              color: colorForTier(asset.riskTier),
                            ),
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

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({required this.sent});

  final SentAlert sent;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.riskLowBg,
          border: Border(
            left: BorderSide(color: AppColors.riskLow, width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Alert #${sent.alertId} sent to ${sent.notified}',
                  style: AppText.sans(size: 14, weight: FontWeight.w700),
                ),
                const Spacer(),
                RiskBadge(tier: sent.tier, size: BadgeSize.sm),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sent.headline,
              style: AppText.sans(
                size: 13,
                color: AppColors.gray70,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'It is in their inbox now. Their phone notifies on the next poll.',
              style: AppText.sans(size: 12, color: AppColors.gray60),
            ),
          ],
        ),
      );
}
