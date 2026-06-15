import 'package:equatable/equatable.dart';

class OneCSettings extends Equatable {
  const OneCSettings({
    this.oneCRequestCreateUrl,
    this.oneCRequestUpdateUrl,
    this.oneCRequestUpdateUrlEffective,
    this.oneCRequestCreateBearerTokenMasked,
    this.hasBearerToken = false,
    this.updatedAt,
  });

  final String? oneCRequestCreateUrl;
  final String? oneCRequestUpdateUrl;
  final String? oneCRequestUpdateUrlEffective;
  final String? oneCRequestCreateBearerTokenMasked;
  final bool hasBearerToken;
  final String? updatedAt;

  @override
  List<Object?> get props => [
        oneCRequestCreateUrl,
        oneCRequestUpdateUrl,
        oneCRequestUpdateUrlEffective,
        hasBearerToken,
        updatedAt,
      ];
}
