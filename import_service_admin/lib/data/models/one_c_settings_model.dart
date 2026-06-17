import 'package:import_service_admin/domain/entities/one_c_settings.dart';

class OneCSettingsModel {
  const OneCSettingsModel({
    this.oneCRequestCreateUrl,
    this.oneCRequestUpdateUrl,
    this.oneCRequestUpdateUrlEffective,
    this.oneCRequestCreateBearerToken,
    this.oneCRequestCreateBearerTokenMasked,
    this.hasBearerToken = false,
    this.updatedAt,
  });

  final String? oneCRequestCreateUrl;
  final String? oneCRequestUpdateUrl;
  final String? oneCRequestUpdateUrlEffective;
  final String? oneCRequestCreateBearerToken;
  final String? oneCRequestCreateBearerTokenMasked;
  final bool hasBearerToken;
  final String? updatedAt;

  factory OneCSettingsModel.fromJson(Map<String, dynamic> json) {
    return OneCSettingsModel(
      oneCRequestCreateUrl: json['oneCRequestCreateUrl'] as String?,
      oneCRequestUpdateUrl: json['oneCRequestUpdateUrl'] as String?,
      oneCRequestUpdateUrlEffective:
          json['oneCRequestUpdateUrlEffective'] as String?,
      oneCRequestCreateBearerToken:
          json['oneCRequestCreateBearerToken'] as String?,
      oneCRequestCreateBearerTokenMasked:
          json['oneCRequestCreateBearerTokenMasked'] as String?,
      hasBearerToken: json['hasBearerToken'] as bool? ?? false,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  OneCSettings toEntity() => OneCSettings(
        oneCRequestCreateUrl: oneCRequestCreateUrl,
        oneCRequestUpdateUrl: oneCRequestUpdateUrl,
        oneCRequestUpdateUrlEffective: oneCRequestUpdateUrlEffective,
        oneCRequestCreateBearerToken: oneCRequestCreateBearerToken,
        oneCRequestCreateBearerTokenMasked: oneCRequestCreateBearerTokenMasked,
        hasBearerToken: hasBearerToken,
        updatedAt: updatedAt,
      );
}
