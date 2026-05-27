import 'package:equatable/equatable.dart';

class CustomsRequestDeliveredDocument extends Equatable {
  const CustomsRequestDeliveredDocument({
    required this.title,
    required this.downloadUrl,
  });

  final String title;
  final String downloadUrl;

  @override
  List<Object?> get props => [title, downloadUrl];
}
