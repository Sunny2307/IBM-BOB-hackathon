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


// ---------------------------------------------------------------------------
// Operator layer — the signed-in half of the app.
//
// Mirrors the operator models in src/backend/app/models/schemas.py. These are
// the only models behind authentication; everything above is public.
// ---------------------------------------------------------------------------

/// What a signed-in person is allowed to do. Mirrors the backend's
/// `Literal["admin","field"]`.
enum UserRole {
  admin('admin'),
  field('field');

  const UserRole(this.wire);

  final String wire;

  static UserRole fromJson(Object? value) {
    final raw = value?.toString();
    for (final role in UserRole.values) {
      if (role.wire == raw) return role;
    }
    // Unknown role degrades to the LEAST privileged, never the most.
    return UserRole.field;
  }

  String get label => this == UserRole.admin ? 'Administrator' : 'Field crew';
}

/// Where an alert is in its lifecycle.
enum AlertStatus {
  open('open'),
  acknowledged('acknowledged'),
  resolved('resolved');

  const AlertStatus(this.wire);

  final String wire;

  static AlertStatus fromJson(Object? value) {
    final raw = value?.toString();
    for (final s in AlertStatus.values) {
      if (s.wire == raw) return s;
    }
    return AlertStatus.open;
  }
}

/// The result of POST /auth/login — identity plus the bearer token.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.companyId,
    required this.companyName,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: _toStr(json['access_token']),
        userId: _toInt(json['user_id']),
        email: _toStr(json['email']),
        fullName: _toStr(json['full_name']),
        role: UserRole.fromJson(json['role']),
        companyId: _toInt(json['company_id']),
        companyName: _toStr(json['company_name']),
      );

  final String accessToken;
  final int userId;
  final String email;
  final String fullName;
  final UserRole role;
  final int companyId;
  final String companyName;

  bool get isAdmin => role == UserRole.admin;

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'user_id': userId,
        'email': email,
        'full_name': fullName,
        'role': role.wire,
        'company_id': companyId,
        'company_name': companyName,
      };
}

/// One raised alert: an asset crossed up into High or Critical.
class Alert {
  const Alert({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.region,
    required this.tier,
    required this.previousTier,
    required this.riskScore,
    required this.headline,
    required this.status,
    required this.raisedAt,
    required this.acknowledgedByName,
    required this.acknowledgedAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: _toInt(json['id']),
        assetId: _toStr(json['asset_id']),
        assetName: _toStr(json['asset_name']),
        region: _toStr(json['region']),
        tier: RiskTier.fromJson(json['tier']),
        previousTier: json['previous_tier']?.toString(),
        riskScore: _toDouble(json['risk_score']),
        headline: _toStr(json['headline']),
        status: AlertStatus.fromJson(json['status']),
        raisedAt: DateTime.tryParse(_toStr(json['raised_at'])),
        acknowledgedByName: json['acknowledged_by_name']?.toString(),
        acknowledgedAt: DateTime.tryParse(_toStr(json['acknowledged_at'])),
      );

  final int id;
  final String assetId;
  final String assetName;
  final String region;
  final RiskTier tier;
  final String? previousTier;
  final double riskScore;
  final String headline;
  final AlertStatus status;
  final DateTime? raisedAt;
  final String? acknowledgedByName;
  final DateTime? acknowledgedAt;

  bool get isAcknowledged => status == AlertStatus.acknowledged;
}

/// GET /alerts/mine — the list plus a description of whose alerts these are.
class AlertInbox {
  const AlertInbox({required this.count, required this.scope, required this.alerts});

  factory AlertInbox.fromJson(Map<String, dynamic> json) => AlertInbox(
        count: _toInt(json['count']),
        scope: _toStr(json['scope']),
        alerts: _toMapList(json['alerts']).map(Alert.fromJson).toList(),
      );

  final int count;

  /// e.g. "assets assigned to you" or "all company alerts (admin)".
  final String scope;
  final List<Alert> alerts;
}

/// GET /alerts/{id} — the alert plus the risk breakdown that caused it.
class AlertDetail {
  const AlertDetail({required this.alert, required this.riskBreakdown});

  factory AlertDetail.fromJson(Map<String, dynamic> json) {
    final breakdown = json['risk_breakdown'];
    return AlertDetail(
      alert: Alert.fromJson(
        (json['alert'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      riskBreakdown: breakdown is Map && !breakdown.containsKey('error')
          ? RiskBreakdown.fromJson(breakdown.cast<String, dynamic>())
          : null,
    );
  }

  final Alert alert;
  final RiskBreakdown? riskBreakdown;
}

/// A person in the operator's company.
class OperatorUser {
  const OperatorUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  factory OperatorUser.fromJson(Map<String, dynamic> json) => OperatorUser(
        id: _toInt(json['id']),
        email: _toStr(json['email']),
        fullName: _toStr(json['full_name']),
        role: UserRole.fromJson(json['role']),
        isActive: _toBool(json['is_active']),
      );

  final int id;
  final String email;
  final String fullName;
  final UserRole role;
  final bool isActive;
}

/// Who is responsible for which region (or single asset).
class Assignment {
  const Assignment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.scopeType,
    required this.scopeValue,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: _toInt(json['id']),
        userId: _toInt(json['user_id']),
        userName: _toStr(json['user_name']),
        scopeType: _toStr(json['scope_type']),
        scopeValue: _toStr(json['scope_value']),
      );

  final int id;
  final int userId;
  final String userName;

  /// `region` | `asset`
  final String scopeType;
  final String scopeValue;
}

/// GET /assignments/mine — the assets this operator owns.
class MyAssignments {
  const MyAssignments({
    required this.count,
    required this.regions,
    required this.assets,
    required this.note,
  });

  factory MyAssignments.fromJson(Map<String, dynamic> json) => MyAssignments(
        count: _toInt(json['count']),
        regions: (json['regions'] as List?)?.map((e) => '$e').toList() ?? const [],
        assets: _toMapList(json['assets']).map(AssignedAsset.fromJson).toList(),
        note: json['note']?.toString(),
      );

  final int count;
  final List<String> regions;
  final List<AssignedAsset> assets;

  /// Present only when nothing is assigned yet, explaining what to do about it.
  final String? note;
}

/// The trimmed asset shape /assignments/mine returns (not the full Asset).
class AssignedAsset {
  const AssignedAsset({
    required this.assetId,
    required this.name,
    required this.region,
    required this.riskScore,
    required this.riskTier,
    required this.customersServed,
  });

  factory AssignedAsset.fromJson(Map<String, dynamic> json) => AssignedAsset(
        assetId: _toStr(json['asset_id']),
        name: _toStr(json['name']),
        region: _toStr(json['region']),
        riskScore: _toDouble(json['risk_score']),
        riskTier: RiskTier.fromJson(json['risk_tier']),
        customersServed: _toInt(json['customers_served']),
      );

  final String assetId;
  final String name;
  final String region;
  final double riskScore;
  final RiskTier riskTier;
  final int customersServed;
}

/// One asset an alert to a given user could land on — the options offered by
/// the Send-alert screen's asset picker.
class AssignableAsset {
  const AssignableAsset({
    required this.assetId,
    required this.name,
    required this.region,
    required this.riskScore,
    required this.riskTier,
  });

  factory AssignableAsset.fromJson(Map<String, dynamic> json) =>
      AssignableAsset(
        assetId: _toStr(json['asset_id']),
        name: _toStr(json['name']),
        region: _toStr(json['region']),
        riskScore: _toDouble(json['risk_score']),
        riskTier: RiskTier.fromJson(json['risk_tier']),
      );

  final String assetId;
  final String name;
  final String region;
  final double riskScore;
  final RiskTier riskTier;
}

/// Result of an admin pressing "Send alert".
class SentAlert {
  const SentAlert({
    required this.alertId,
    required this.assetName,
    required this.tier,
    required this.headline,
    required this.notified,
  });

  factory SentAlert.fromJson(Map<String, dynamic> json) {
    final alert = (json['alert'] as Map?)?.cast<String, dynamic>() ?? const {};
    return SentAlert(
      alertId: _toInt(alert['id']),
      assetName: _toStr(alert['asset_name']),
      tier: RiskTier.fromJson(alert['tier']),
      headline: _toStr(alert['headline']),
      notified: _toStr(json['notified']),
    );
  }

  final int alertId;
  final String assetName;
  final RiskTier tier;
  final String headline;
  final String notified;
}

