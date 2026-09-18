import 'package:flutter_test/flutter_test.dart';
import 'package:grid_advisor_mobile/api/types.dart';
import 'package:grid_advisor_mobile/widgets/region_grouped_assets.dart';

Asset _asset(
  String id, {
  required String region,
  required double score,
  required RiskTier tier,
  int customers = 100,
}) =>
    Asset(
      assetId: id,
      name: 'Asset $id',
      type: 'transformer',
      lat: 0,
      lon: 0,
      region: region,
      installYear: 2000,
      capacityMva: 10,
      customersServed: customers,
      gridImpactSeverity: 5,
      hasHospitalCriticalLoad: false,
      hasWaterTreatmentLoad: false,
      hasRedundancy: false,
      riskScore: score,
      riskTier: tier,
    );

void main() {
  final assets = [
    _asset('A', region: 'Bayview', score: 40, tier: RiskTier.medium, customers: 10),
    _asset('B', region: 'Eastgate', score: 88, tier: RiskTier.critical, customers: 20),
    _asset('C', region: 'Bayview', score: 72, tier: RiskTier.high, customers: 30),
    _asset('D', region: 'Eastgate', score: 51, tier: RiskTier.high, customers: 40),
    _asset('E', region: 'Bayview', score: 12, tier: RiskTier.low, customers: 50),
  ];

  test('every asset lands in exactly one region group', () {
    final groups = groupAssetsByRegion(assets);

    expect(groups.map((g) => g.region), ['Eastgate', 'Bayview']);
    expect(groups.fold<int>(0, (n, g) => n + g.assets.length), assets.length);
    expect(groups.firstWhere((g) => g.region == 'Bayview').assets, hasLength(3));
  });

  test('regions are ordered by their worst asset, not by name or size', () {
    final groups = groupAssetsByRegion(assets);

    // Bayview has MORE assets but Eastgate holds the worst one, so Eastgate
    // leads — the dashboard answers "where do I send a crew first".
    expect(groups.first.region, 'Eastgate');
    expect(groups.first.worstScore, 88);
  });

  test('a group summarises the region: worst tier, counts, customers', () {
    final bayview =
        groupAssetsByRegion(assets).firstWhere((g) => g.region == 'Bayview');

    expect(bayview.worstTier, RiskTier.high, reason: 'highest tier present');
    expect(bayview.criticalCount, 0);
    expect(bayview.highCount, 1);
    expect(bayview.customers, 90, reason: '10 + 30 + 50');
    expect(bayview.worstScore, 72);
  });

  test('assets inside a region are ranked, and the sort toggle flips both', () {
    final desc = groupAssetsByRegion(assets, sortDesc: true);
    expect(desc.first.assets.map((a) => a.assetId), ['B', 'D']);

    final asc = groupAssetsByRegion(assets, sortDesc: false);
    expect(asc.first.region, 'Bayview', reason: 'ascending puts calmest first');
    expect(asc.first.assets.map((a) => a.assetId), ['E', 'A', 'C']);
  });

  test('an empty list produces no groups rather than throwing', () {
    expect(groupAssetsByRegion(const []), isEmpty);
  });

  test('a single-asset region is still a valid group', () {
    final groups = groupAssetsByRegion([
      _asset('Z', region: 'Solo', score: 30, tier: RiskTier.medium),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.assets, hasLength(1));
    expect(groups.single.worstTier, RiskTier.medium);
  });
}
