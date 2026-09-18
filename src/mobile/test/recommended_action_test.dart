import 'package:flutter_test/flutter_test.dart';
import 'package:grid_advisor_mobile/api/mock_data.dart';
import 'package:grid_advisor_mobile/api/types.dart';
import 'package:grid_advisor_mobile/widgets/recommended_action.dart';

MaintenanceItem _item(String assetId) => MaintenanceItem(
      assetId: assetId,
      assetName: 'Asset $assetId',
      riskScore: 80,
      riskTier: RiskTier.critical,
      priorityScore: 640,
      recommendedAction: 'Dispatch crew now.',
      recommendedByDate: '2026-09-25',
      rationale: 'Because the score is high.',
    );

void main() {
  final plan = MaintenancePlan(
    generatedAt: '2026-09-19',
    regions: [
      RegionPlan(
        region: 'North Valley',
        weatherSummary: 'Storm warning in 5 days.',
        items: [_item('AST-001'), _item('AST-002')],
      ),
      RegionPlan(
        region: 'Bayview',
        weatherSummary: 'Clear.',
        items: [_item('AST-003')],
      ),
    ],
  );

  test('finds an asset in the first region, with its weather context', () {
    final found = findPlanItem(plan, 'AST-001');

    expect(found, isNotNull);
    expect(found!.item.assetId, 'AST-001');
    expect(found.weatherSummary, 'Storm warning in 5 days.');
  });

  test('searches across every region, not just the first', () {
    final found = findPlanItem(plan, 'AST-003');

    expect(found, isNotNull);
    expect(found!.weatherSummary, 'Clear.',
        reason: 'must pick up the region the asset actually sits in');
  });

  test('an asset with no recommended work returns null, not a throw', () {
    expect(findPlanItem(plan, 'AST-999'), isNull);
  });

  test('a null plan (still loading) is handled', () {
    expect(findPlanItem(null, 'AST-001'), isNull);
  });

  test('works against the real mock plan shape', () {
    final mock = buildMockMaintenancePlan();
    final firstId = mock.regions.first.items.first.assetId;

    expect(findPlanItem(mock, firstId), isNotNull);
    expect(findPlanItem(mock, 'AST-does-not-exist'), isNull);
  });

  test('the urgent threshold matches the maintenance plan page', () {
    expect(urgentWindowDays, 7);
  });
}
