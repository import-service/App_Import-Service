import 'package:equatable/equatable.dart';
import 'package:import_service_app/data/models/request_draft.dart';

final class RequestDraftState extends Equatable {
  const RequestDraftState({required this.drafts});

  final List<RequestDraft> drafts;

  int get count => drafts.length;

  /// От новых к старым; порядок поддерживает [RequestDraftCubit.upsert].
  List<RequestDraft> get draftsSorted =>
      List<RequestDraft>.unmodifiable(drafts);

  RequestDraftState copyWith({List<RequestDraft>? drafts}) {
    return RequestDraftState(drafts: drafts ?? this.drafts);
  }

  @override
  List<Object?> get props => [drafts];
}
