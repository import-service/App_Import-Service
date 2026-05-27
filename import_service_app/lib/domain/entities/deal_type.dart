/// Вид сделки (`dealType`), задаётся 1С при `in_progress`.
enum DealType {
  bilateral('bilateral'),
  cash('cash'),
  tripartite('tripartite'),
  quadripartite('quadripartite');

  const DealType(this.apiCode);

  final String apiCode;

  static final Map<String, DealType> _byCode = {
    for (final v in DealType.values) v.apiCode: v,
  };

  static DealType? tryParse(String? raw) {
    final code = (raw ?? '').trim();
    if (code.isEmpty) return null;
    return _byCode[code];
  }
}
