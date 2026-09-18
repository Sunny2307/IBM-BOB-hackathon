import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/types.dart';
import '../theme/app_theme.dart';
import '../util/formatting.dart';
import '../util/risk_colors.dart';
import 'risk_badge.dart';

/// Port of the web frontend's `GridMap` (react-leaflet + OpenStreetMap
/// tiles). Markers are colored by risk tier; tapping one opens an asset
/// summary sheet — the mobile equivalent of the web's marker popup.
class GridMap extends StatelessWidget {
  const GridMap({
    super.key,
    required this.assets,
    required this.onOpenAsset,
    this.height = 300,
  });

  final List<Asset> assets;
  final void Function(String assetId) onOpenAsset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = assets.map((a) => LatLng(a.lat, a.lon)).toList();

    // Continental-US fallback when there is nothing to plot.
    final center = points.isEmpty
        ? const LatLng(39.8, -98.6)
        : LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
            points.map((p) => p.longitude).reduce((a, b) => a + b) /
                points.length,
          );

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray20),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 6,
                initialCameraFit: points.isEmpty
                    ? null
                    : CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(36),
                        maxZoom: 11,
                      ),
                interactionOptions: const InteractionOptions(
                  // Rotation off — the editorial layout reads better upright,
                  // and it matches the web map's fixed north-up orientation.
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                backgroundColor: AppColors.gray10,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ai.gridadvisor.grid_advisor_mobile',
                  maxNativeZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    for (final asset in assets)
                      Marker(
                        point: LatLng(asset.lat, asset.lon),
                        width: 28,
                        height: 28,
                        child: _RiskMarker(
                          tier: asset.riskTier,
                          onTap: () => _showAssetSheet(context, asset),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                color: AppColors.white.withValues(alpha: 0.82),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: AppText.sans(size: 9, color: AppColors.gray70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssetSheet(BuildContext context, Asset asset) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                asset.name,
                style: AppText.serif(size: 18, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  RiskBadge(tier: asset.riskTier, size: BadgeSize.sm),
                  const SizedBox(width: 10),
                  Text(
                    '${formatScore(asset.riskScore)}/100',
                    style: AppText.mono(size: 12, color: AppColors.gray70),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${asset.type} — ${asset.region}',
                style: AppText.sans(size: 13, color: AppColors.gray70),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onOpenAsset(asset.assetId);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                    side: const BorderSide(color: AppColors.blue60),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'VIEW ASSET DETAIL →',
                    style: AppText.sans(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.blue60,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The web's `.grid-map-marker`: a tier-colored dot with a paper ring and a
/// soft glow halo.
class _RiskMarker extends StatelessWidget {
  const _RiskMarker({required this.tier, required this.onTap});

  final RiskTier tier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorForTier(tier);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
            ],
          ),
        ),
      ),
    );
  }
}
