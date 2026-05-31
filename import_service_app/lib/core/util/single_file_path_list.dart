/// Один локальный файл на слот docType (контракт v2). Всегда изменяемый список.
List<String> singleFilePathList(Iterable<String> paths) {
  for (final raw in paths) {
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      return List<String>.from([trimmed]);
    }
  }
  return <String>[];
}

/// Из initial/payload — изменяемый список, не больше одного пути.
List<String> mutableSlotPaths(List<String> source) {
  return List<String>.from(
    source.map((e) => e.trim()).where((e) => e.isNotEmpty).take(1),
  );
}
