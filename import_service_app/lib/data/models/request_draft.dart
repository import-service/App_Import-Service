import 'package:import_service_app/data/models/request_form_model.dart';

final class RequestDraft {
  const RequestDraft({
    required this.id,
    required this.updatedAt,
    required this.form,
  });

  final String id;
  final DateTime updatedAt;
  final RequestFormModel form;

  factory RequestDraft.fromJson(Map<String, dynamic> json) {
    final formRaw = json['form'];
    if (formRaw is! Map<String, dynamic>) {
      throw const FormatException('RequestDraft: invalid form');
    }
    return RequestDraft(
      id: (json['id'] as String?) ?? '',
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      form: RequestFormModel.fromJson(formRaw),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'updatedAt': updatedAt.toIso8601String(),
        'form': form.toJson(),
      };
}
