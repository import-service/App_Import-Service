import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';

/// Маркер URL демо-файла: открытие через генерацию PDF, без сети.
const String kDemoFileUrlScheme = 'demo://doc/';

bool isDemoRequestFileUrl(String? url) {
  final u = (url ?? '').trim();
  return u.startsWith(kDemoFileUrlScheme) || u.startsWith('demo://');
}

/// Файл заявки для демо-сида (всегда PDF-мок).
CustomsRequestFile demoSeedFile(String docType, {String? fileName}) {
  final code = normalizeDocType(docType);
  final name = (fileName ?? '$code.pdf').trim();
  return CustomsRequestFile(
    docType: code,
    fileName: name,
    mimeType: 'application/pdf',
    fileUrl: '$kDemoFileUrlScheme$code',
  );
}

List<CustomsRequestFile> demoCreationFiles({bool includeOptional = true}) {
  final list = <CustomsRequestFile>[
    for (final t in CustomsDocType.requiredOnCreate) demoSeedFile(t.apiCode),
  ];
  if (includeOptional) {
    for (final t in CustomsDocType.optionalOnCreate) {
      list.add(demoSeedFile(t.apiCode));
    }
  }
  return list;
}

/// Пакет на подпись: оригиналы (+ опционально уже загруженные `*_sign`).
List<CustomsRequestFile> demoSigningFiles(
  DealType dealType, {
  bool includeSigned = true,
  bool includeClientSignOnlySlot = true,
}) {
  final out = <CustomsRequestFile>[];
  for (final t in signingDocTypesForDealType(dealType)) {
    if (t.isHiddenFromMpSigningSection) continue;
    if (t.isClientSignOnly) {
      if (includeClientSignOnlySlot && includeSigned) {
        out.add(demoSeedFile(t.signedApiCode));
      }
      continue;
    }
    out.add(demoSeedFile(t.apiCode));
    if (includeSigned) {
      out.add(demoSeedFile(t.signedApiCode));
    }
  }
  return out;
}

List<CustomsRequestFile> demoPaymentFiles({
  bool withReceipts = true,
}) {
  final out = <CustomsRequestFile>[
    demoSeedFile(CustomsDocType.paymentRecyclingFee.apiCode),
    demoSeedFile(CustomsDocType.paymentCustomsDuty.apiCode),
  ];
  if (withReceipts) {
    out.addAll([
      demoSeedFile(CustomsDocType.paymentRecyclingFeeReceipt.apiCode),
      demoSeedFile(CustomsDocType.paymentCustomsDutyReceipt.apiCode),
    ]);
  }
  return out;
}

List<CustomsRequestFile> demoTransitArchiveFiles() => [
      demoSeedFile('transit_archive_photo_1', fileName: 'transit_1.pdf'),
      demoSeedFile('transit_archive_photo_2', fileName: 'transit_2.pdf'),
      demoSeedFile('transit_archive_photo_3', fileName: 'transit_3.pdf'),
      demoSeedFile(CustomsDocType.transitArchiveVideo.apiCode),
    ];

/// Галерея «Фото машины» (СВХ), demo.
List<CustomsRequestFile> demoSvhCarGalleryFiles({int count = 3}) {
  final n = count.clamp(1, kSvhCarGalleryMaxPhotos);
  return [
    for (var i = 1; i <= n; i++)
      CustomsRequestFile(
        docType: svhCarGalleryDocType(i),
        fileName: 'svh_car_photo_$i.jpg',
        mimeType: 'image/jpeg',
        fileUrl: '$kDemoFileUrlScheme${svhCarGalleryDocType(i)}',
      ),
  ];
}

List<CustomsRequestFile> demoFinalFiles() => [
      for (final t in CustomsDocType.finalTypes) demoSeedFile(t.apiCode),
    ];

List<CustomsRequestFile> mergeDemoFiles(Iterable<List<CustomsRequestFile>> parts) {
  final byType = <String, CustomsRequestFile>{};
  for (final part in parts) {
    for (final f in part) {
      final key = normalizeDocType(f.docType);
      if (key.isEmpty) continue;
      byType[key] = f;
    }
  }
  return byType.values.toList(growable: false);
}
