import 'package:equatable/equatable.dart';

/// СБКТС, ЭПТС и т.д. — [title] и [downloadUrl] с бэка/1С, без i18n-ключей.
final class DeliveredVehicleDocument extends Equatable {
  const DeliveredVehicleDocument({
    required this.title,
    required this.downloadUrl,
  });

  final String title;
  final String downloadUrl;

  factory DeliveredVehicleDocument.fromJson(Map<String, dynamic> json) {
    return DeliveredVehicleDocument(
      title: (json['title'] as String?)?.trim() ?? '',
      downloadUrl: (json['downloadUrl'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'downloadUrl': downloadUrl,
      };

  @override
  List<Object?> get props => [title, downloadUrl];
}
