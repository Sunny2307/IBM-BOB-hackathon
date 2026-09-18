import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../util/formatting.dart';

/// "Live-updating feel" indicator: relative time since the last successful
/// fetch (real or fallback), a pulsing dot while a background refresh is in
/// flight, and a manual refresh button. Ticks locally every second so the
/// label stays fresh without waiting on the next poll.
class LastUpdated extends StatefulWidget {
  const LastUpdated({
    super.key,
    required this.timestamp,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final DateTime? timestamp;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  State<LastUpdated> createState() => _LastUpdatedState();
}

class _LastUpdatedState extends State<LastUpdated> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.timestamp;
    final label = timestamp == null
        ? '—'
        : formatRelative(DateTime.now().difference(timestamp));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isRefreshing ? AppColors.blue60 : AppColors.riskLow,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Updated $label',
          style: AppText.sans(size: 12, color: AppColors.gray70),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: widget.isRefreshing ? null : widget.onRefresh,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: AppColors.gray30)),
            child: Text(
              widget.isRefreshing ? 'Refreshing…' : 'Refresh',
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w500,
                color: widget.isRefreshing ? AppColors.gray60 : AppColors.blue60,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
