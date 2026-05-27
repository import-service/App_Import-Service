import 'package:import_service_admin/domain/entities/one_c_settings.dart';

class OneCSettingsModel {
  OneCSettingsModel({
    this.oneCRequestCreateUrl,
    this.oneCRequestCreateBearerTokenMasked,
    this.hasBearerToken = false,
    this.updatedAt,
  });

  final String? oneCRequestCreateUrl;
  final String? oneCRequestCreateBearerTokenMasked;
  final bool hasBearerToken;
  final String? updatedAt;

  factory OneCSettingsModel.fromJson(Map<String, dynamic> json) {
    return OneCSettingsModel(
      oneCRequestCreateUrl: json['oneCRequestCreateUrl'] as String?,
      oneCRequestCreateBearerTokenMasked:
          json['oneCRequestCreateBearerTokenMasked'] as String?,
      hasBearerToken: json['hasBearerToken'] == true,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  OneCSettings toEntity() => OneCSettings(
        oneCRequestCreateUrl: oneCRequestCreateUrl,
        oneCRequestCreateBearerTokenMasked: oneCRequestCreateBearerTokenMasked,
        hasBearerToken: hasBearerToken,
        updatedAt: updatedAt,
      );
}
