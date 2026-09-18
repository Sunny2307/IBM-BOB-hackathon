// Models mirror the real FastAPI backend contract exactly
// (src/backend/app/models/schemas.py), field-for-field the same as the web
// frontend's `src/api/types.ts`. Nothing on the backend changes for mobile.

/// Risk tier, matching the backend's `Literal["Critical","High","Medium","Low"]`.
enum RiskTier {
  critical('Critical'),
  high('High'),
  medium('Medium'),
  low('Low');

  const RiskTier(this.label);

  final String label;

  static RiskTier fromJson(Object? value) {
    final raw = value?.toString();
    for (final tier in RiskTier.values) {
      if (tier.label == raw) return tier;
    }
    return RiskTier.low;
  }
}

double _toDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int _toInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

bool _toBool(Object? value) => value is bool ? value : value == 'true';

String _toStr(Object? value) => value?.toString() ?? '';

List<Map<String, dynamic>> _toMapList(Object? value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

class Asset {
  const Asset({
    required this.assetId,
    required this.name,
    required this.type,
    required this.lat,
    required this.lon,
    required this.region,
    required this.installYear,
    required this.capacityMva,
    required this.customersServed,
    required this.gridImpactSeverity,
    required this.hasHospitalCriticalLoad,
    required this.hasWaterTreatmentLoad,
    required this.hasRedundancy,
    required this.riskScore,
    required this.riskTier,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        assetId: _toStr(json['asset_id']),
        name: _toStr(json['name']),
        type: _toStr(json['type']),
        lat: _toDouble(json['lat']),
        lon: _toDouble(json['lon']),
        region: _toStr(json['region']),
        installYear: _toInt(json['install_year']),
        capacityMva: _toDouble(json['capacity_mva']),
        customersServed: _toInt(json['customers_served']),
        gridImpactSeverity: _toInt(json['grid_impact_severity']),
        hasHospitalCriticalLoad: _toBool(json['has_hospital_critical_load']),
        hasWaterTreatmentLoad: _toBool(json['has_water_treatment_load']),
        hasRedundancy: _toBool(json['has_redundancy']),
        riskScore: _toDouble(json['risk_score']),
        riskTier: RiskTier.fromJson(json['risk_tier']),
      );

  final String assetId;
  final String name;

  /// `transformer` | `substation`
  final String type;
  final double lat;
  final double lon;
  final String region;
  final int installYear;
  final double capacityMva;
  final int customersServed;
  final int gridImpactSeverity;
  final bool hasHospitalCriticalLoad;
  final bool hasWaterTreatmentLoad;
  final bool hasRedundancy;
  final double riskScore;
  final RiskTier riskTier;

  Asset withAssetId(String id) => Asset(
        assetId: id,
        name: name,
        type: type,
        lat: lat,
        lon: lon,
        region: region,
        installYear: installYear,
        capacityMva: capacityMva,
        customersServed: customersServed,
        gridImpactSeverity: gridImpactSeverity,
        hasHospitalCriticalLoad: hasHospitalCriticalLoad,
        hasWaterTreatmentLoad: hasWaterTreatmentLoad,
        hasRedundancy: hasRedundancy,
        riskScore: riskScore,
        riskTier: riskTier,
      );
}

class RiskComponent {
  const RiskComponent({
    required this.factor,
    required this.contribution,
    required this.explanation,
  });

  factory RiskComponent.fromJson(Map<String, dynamic> json) => RiskComponent(
        factor: _toStr(json['factor']),
        contribution: _toDouble(json['contribution']),
        explanation: _toStr(json['explanation']),
      );

  final String factor;
  final double contribution;
  final String explanation;
}

class SensorReading {
  const SensorReading({required this.date, required this.value});

  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
        date: _toStr(json['date']),
        value: _toDouble(json['value']),
      );

  final String date;
  final double value;
}

class SensorSeries {
  const SensorSeries({
    required this.temperature,
    required this.vibration,
    required this.partialDischarge,
    required this.oilQuality,
  });

  factory SensorSeries.fromJson(Map<String, dynamic> json) {
    List<SensorReading> read(String key) =>
        _toMapList(json[key]).map(SensorReading.fromJson).toList();
    return SensorSeries(
      temperature: read('temperature'),
      vibration: read('vibration'),
      partialDischarge: read('partial_discharge'),
      oilQuality: read('oil_quality'),
    );
  }

  final List<SensorReading> temperature;
  final List<SensorReading> vibration;
  final List<SensorReading> partialDischarge;
  final List<SensorReading> oilQuality;
}

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.tempHighF,
    required this.windSpeedMph,
    required this.precipProbability,
    required this.stormWarning,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) => DailyForecast(
        date: _toStr(json['date']),
        tempHighF: _toDouble(json['temp_high_f']),
        windSpeedMph: _toDouble(json['wind_speed_mph']),
        precipProbability: _toDouble(json['precip_probability']),
        stormWarning: _toBool(json['storm_warning']),
      );

  final String date;
  final double tempHighF;
  final double windSpeedMph;
  final double precipProbability;
  final bool stormWarning;
}

class WeatherContext {
  const WeatherContext({required this.region, required this.forecast});

  factory WeatherContext.fromJson(Map<String, dynamic> json) => WeatherContext(
        region: _toStr(json['region']),
        forecast:
            _toMapList(json['forecast']).map(DailyForecast.fromJson).toList(),
      );

  final String region;
  final List<DailyForecast> forecast;
}

class RiskBreakdown {
  const RiskBreakdown({
    required this.assetId,
    required this.riskScore,
    required this.riskTier,
    required this.components,
    required this.sensorSeries,
    required this.weatherContext,
  });

  factory RiskBreakdown.fromJson(Map<String, dynamic> json) => RiskBreakdown(
        assetId: _toStr(json['asset_id']),
        riskScore: _toDouble(json['risk_score']),
        riskTier: RiskTier.fromJson(json['risk_tier']),
        components:
            _toMapList(json['components']).map(RiskComponent.fromJson).toList(),
        sensorSeries: SensorSeries.fromJson(
          (json['sensor_series'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        weatherContext: WeatherContext.fromJson(
          (json['weather_context'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );

  final String assetId;
  final double riskScore;
  final RiskTier riskTier;
  final List<RiskComponent> components;
  final SensorSeries sensorSeries;
  final WeatherContext weatherContext;

  RiskBreakdown withAssetId(String id) => RiskBreakdown(
        assetId: id,
        riskScore: riskScore,
        riskTier: riskTier,
        components: components,
        sensorSeries: sensorSeries,
        weatherContext: weatherContext,
      );
}

class MaintenanceItem {
  const MaintenanceItem({
    required this.assetId,
    required this.assetName,
    required this.riskScore,
    required this.riskTier,
    required this.priorityScore,
    required this.recommendedAction,
    required this.recommendedByDate,
    required this.rationale,
  });

  factory MaintenanceItem.fromJson(Map<String, dynamic> json) =>
      MaintenanceItem(
        assetId: _toStr(json['asset_id']),
        assetName: _toStr(json['asset_name']),
        riskScore: _toDouble(json['risk_score']),
        riskTier: RiskTier.fromJson(json['risk_tier']),
        priorityScore: _toDouble(json['priority_score']),
        recommendedAction: _toStr(json['recommended_action']),
        recommendedByDate: _toStr(json['recommended_by_date']),
        rationale: _toStr(json['rationale']),
      );

  final String assetId;
  final String assetName;
  final double riskScore;
  final RiskTier riskTier;
  final double priorityScore;
  final String recommendedAction;
  final String recommendedByDate;
  final String rationale;
}

class RegionPlan {
  const RegionPlan({
    required this.region,
    required this.weatherSummary,
    required this.items,
  });

  factory RegionPlan.fromJson(Map<String, dynamic> json) => RegionPlan(
        region: _toStr(json['region']),
        weatherSummary: _toStr(json['weather_summary']),
        items: _toMapList(json['items']).map(MaintenanceItem.fromJson).toList(),
      );

  final String region;
  final String weatherSummary;
  final List<MaintenanceItem> items;
}

class MaintenancePlan {
  const MaintenancePlan({required this.generatedAt, required this.regions});

  factory MaintenancePlan.fromJson(Map<String, dynamic> json) =>
      MaintenancePlan(
        generatedAt: _toStr(json['generated_at']),
        regions: _toMapList(json['regions']).map(RegionPlan.fromJson).toList(),
      );

  final String generatedAt;
  final List<RegionPlan> regions;
}

class ToolCall {
  const ToolCall({required this.tool, required this.args});

  factory ToolCall.fromJson(Map<String, dynamic> json) => ToolCall(
        tool: _toStr(json['tool']),
        args: (json['args'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  final String tool;
  final Map<String, dynamic> args;
}

class CopilotResponse {
  const CopilotResponse({
    required this.answer,
    required this.toolCalls,
    required this.data,
  });

  factory CopilotResponse.fromJson(Map<String, dynamic> json) =>
      CopilotResponse(
        answer: _toStr(json['answer']),
        toolCalls:
            _toMapList(json['tool_calls']).map(ToolCall.fromJson).toList(),
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  final String answer;
  final List<ToolCall> toolCalls;
  final Map<String, dynamic> data;
}

/// One completed question/answer exchange in the Volt panel.
class ChatTurn {
  const ChatTurn({
    required this.question,
    required this.answer,
    required this.toolCalls,
  });

  final String question;
  final String answer;
  final List<ToolCall> toolCalls;
}

/// Conversation history shape sent to the LLM-backed `/copilot/ask` endpoint.
class CopilotHistoryTurn {
  const CopilotHistoryTurn({required this.role, required this.content});

  /// `user` | `assistant`
  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
