import 'package:import_service_admin/core/constants/api_config.dart';

String? resolveFileUrl(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  final base = ApiConfig.baseUrl.trim();
  final normalized = base.endsWith('/') ? base : '$base/';
  final apiUri = Uri.parse(normalized);
  return apiUri
      .resolve(value.startsWith('/') ? value.substring(1) : value)
      .toString();
}
