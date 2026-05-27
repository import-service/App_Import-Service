import 'package:equatable/equatable.dart';

class OneCSettings extends Equatable {
  const OneCSettings({
    this.oneCRequestCreateUrl,
    this.oneCRequestCreateBearerTokenMasked,
    this.hasBearerToken = false,
    this.updatedAt,
  });

  final String? oneCRequestCreateUrl;
  final String? oneCRequestCreateBearerTokenMasked;
  final bool hasBearerToken;
  final String? updatedAt;

  @override
  List<Object?> get props => [oneCRequestCreateUrl, hasBearerToken, updatedAt];
}
