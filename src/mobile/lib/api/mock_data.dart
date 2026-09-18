// Local fallback data — used ONLY when the real API is unreachable, so the UI
// stays demo-able if the backend isn't running. Not a source of truth; field
// shapes match app/models/schemas.py exactly. Ported from the web frontend's
// `src/api/mockData.ts` so both clients fall back to the same demo story.

import 'dart:math' as math;

import 'types.dart';

const List<Asset> mockAssets = [
  Asset(
    assetId: 'AST-014',
    name: 'North Valley Transformer 03',
    type: 'transformer',
    lat: 37.9,
    lon: -121.3,
    region: 'North Valley',
    installYear: 1998,
    capacityMva: 50,
    customersServed: 8200,
    gridImpactSeverity: 9,
    hasHospitalCriticalLoad: true,
    hasWaterTreatmentLoad: false,
    hasRedundancy: false,
    riskScore: 91,
    riskTier: RiskTier.critical,
  ),
  Asset(
    assetId: 'AST-208',
    name: 'Riverside Substation 02',
    type: 'substation',
    lat: 33.95,
    lon: -117.4,
    region: 'Riverside',
    installYear: 2006,
    capacityMva: 90,
    customersServed: 3400,
    gridImpactSeverity: 6,
    hasHospitalCriticalLoad: false,
    hasWaterTreatmentLoad: false,
    hasRedundancy: true,
    riskScore: 74,
    riskTier: RiskTier.high,
  ),
  Asset(
    assetId: 'AST-091',
    name: 'North Valley Transformer 07',
    type: 'transformer',
    lat: 37.88,
    lon: -121.25,
    region: 'North Valley',
    installYear: 2015,
    capacityMva: 10,
    customersServed: 1100,
    gridImpactSeverity: 4,
    hasHospitalCriticalLoad: false,
    hasWaterTreatmentLoad: false,
    hasRedundancy: true,
    riskScore: 48,
    riskTier: RiskTier.medium,
  ),
  Asset(
    assetId: 'AST-330',
    name: 'Highland Substation 01',
    type: 'substation',
    lat: 39.7,
    lon: -104.9,
    region: 'Highland',
    installYear: 2019,
    capacityMva: 138,
    customersServed: 6500,
    gridImpactSeverity: 7,
    hasHospitalCriticalLoad: false,
    hasWaterTreatmentLoad: true,
    hasRedundancy: true,
    riskScore: 22,
    riskTier: RiskTier.low,
  ),
  Asset(
    assetId: 'AST-142',
    name: 'Riverside Transformer 05',
    type: 'transformer',
    lat: 33.99,
    lon: -117.35,
    region: 'Riverside',
    installYear: 2001,
    capacityMva: 75,
    customersServed: 12400,
    gridImpactSeverity: 9,
    hasHospitalCriticalLoad: false,
    hasWaterTreatmentLoad: false,
    hasRedundancy: false,
    riskScore: 88,
    riskTier: RiskTier.critical,
  ),
];

String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

List<SensorReading> _series(double base, double drift, {int days = 30}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final date = now.subtract(Duration(days: days - i));
    final value = (base + (drift * i) / days + math.sin(i.toDouble()) * 1.5);
    return SensorReading(
      date: _isoDate(date),
      value: (value * 10).round() / 10,
    );
  });
}

RiskBreakdown buildMockRiskBreakdown() {
  final now = DateTime.now();
  return RiskBreakdown(
    assetId: 'AST-014',
    riskScore: 91,
    riskTier: RiskTier.critical,
    components: const [
      RiskComponent(
        factor: 'Sensor Anomaly — Oil Quality',
        contribution: 18,
        explanation:
            'Oil quality has fallen 34% versus its 15-day baseline, consistent with developing equipment stress.',
      ),
      RiskComponent(
        factor: 'Sensor Anomaly — Partial Discharge',
        contribution: 18,
        explanation:
            'Partial discharge has risen 58% versus its 15-day baseline, consistent with developing equipment stress.',
      ),
      RiskComponent(
        factor: 'Weather Risk',
        contribution: 25,
        explanation:
            'Storm warning forecast for North Valley within 5 days — compounds any existing equipment stress in this region.',
      ),
      RiskComponent(
        factor: 'Historical Incident Rate',
        contribution: 16.5,
        explanation:
            "Transformers of similar age (28 yrs, 'old' bracket) show 8 historical incidents in the record.",
      ),
      RiskComponent(
        factor: 'Sensor Anomaly — Vibration',
        contribution: 8.5,
        explanation: 'Vibration has risen 42% versus its 15-day baseline.',
      ),
      RiskComponent(
        factor: 'Sensor Anomaly — Temperature',
        contribution: 5.0,
        explanation:
            'Temperature shows a mild deviation from baseline; worth monitoring.',
      ),
      RiskComponent(
        factor: 'Baseline Operational Risk',
        contribution: 5.0,
        explanation:
            'Fixed floor reflecting that any energized grid asset carries nonzero risk.',
      ),
    ],
    sensorSeries: SensorSeries(
      temperature: _series(62, 8),
      vibration: _series(2.1, 0.9),
      partialDischarge: _series(80, 45),
      oilQuality: _series(78, -30),
    ),
    weatherContext: WeatherContext(
      region: 'North Valley',
      forecast: List.generate(7, (i) {
        return DailyForecast(
          date: _isoDate(now.add(Duration(days: i))),
          tempHighF: 75 + i.toDouble(),
          windSpeedMph: 12 + i * 6.0,
          precipProbability: math.min(0.9, i * 0.15),
          stormWarning: i == 4,
        );
      }),
    ),
  );
}

MaintenancePlan buildMockMaintenancePlan() {
  final now = DateTime.now();
  String inDays(int days) => _isoDate(now.add(Duration(days: days)));

  return MaintenancePlan(
    generatedAt: _isoDate(now),
    regions: [
      RegionPlan(
        region: 'North Valley',
        weatherSummary:
            'Storm warning in 5 days — high wind and precipitation risk.',
        items: [
          MaintenanceItem(
            assetId: 'AST-014',
            assetName: 'North Valley Transformer 03',
            riskScore: 91,
            riskTier: RiskTier.critical,
            priorityScore: 819,
            recommendedAction:
                'Dispatch crew for emergency inspection now; pre-stage replacement parts/transformer.',
            recommendedByDate: inDays(4),
            rationale:
                'Risk score 91 (Critical) x grid impact severity 9/10; pre-positioned ahead of the storm warning.',
          ),
          MaintenanceItem(
            assetId: 'AST-091',
            assetName: 'North Valley Transformer 07',
            riskScore: 48,
            riskTier: RiskTier.medium,
            priorityScore: 192,
            recommendedAction:
                'Schedule inspection in the next routine maintenance window.',
            recommendedByDate: inDays(21),
            rationale:
                'Risk score 48 (Medium) x grid impact severity 4/10; standard response window.',
          ),
        ],
      ),
      RegionPlan(
        region: 'Riverside',
        weatherSummary: 'No severe weather in the 7-day forecast.',
        items: [
          MaintenanceItem(
            assetId: 'AST-142',
            assetName: 'Riverside Transformer 05',
            riskScore: 88,
            riskTier: RiskTier.critical,
            priorityScore: 792,
            recommendedAction:
                'Dispatch crew for emergency inspection now; pre-stage replacement parts/transformer.',
            recommendedByDate: inDays(3),
            rationale:
                'Risk score 88 (Critical) x grid impact severity 9/10; high customer impact if failure occurs.',
          ),
          MaintenanceItem(
            assetId: 'AST-208',
            assetName: 'Riverside Substation 02',
            riskScore: 74,
            riskTier: RiskTier.high,
            priorityScore: 444,
            recommendedAction:
                'Schedule priority inspection within days; order replacement parts if degradation confirmed.',
            recommendedByDate: inDays(10),
            rationale: 'Risk score 74 (High) x grid impact severity 6/10.',
          ),
        ],
      ),
    ],
  );
}

Asset getMockAsset(String id) {
  for (final asset in mockAssets) {
    if (asset.assetId == id) return asset;
  }
  return mockAssets.first.withAssetId(id);
}

RiskBreakdown getMockRiskBreakdown(String id) =>
    buildMockRiskBreakdown().withAssetId(id);

const CopilotResponse mockCopilotResponse = CopilotResponse(
  answer:
      'Top 2 highest-risk assets: North Valley Transformer 03 — Critical (score 91/100, North Valley), Riverside Transformer 05 — Critical (score 88/100, Riverside).',
  toolCalls: [
    ToolCall(
      tool: 'get_at_risk_assets',
      args: {'region': null, 'min_tier': 'High', 'limit': 5},
    ),
  ],
  data: {'count': 2},
);
