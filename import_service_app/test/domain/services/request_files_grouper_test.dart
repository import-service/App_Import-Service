import 'package:flutter_test/flutter_test.dart';

import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/services/request_files_grouper.dart';

CustomsRequestFile _file(String docType) => CustomsRequestFile(
      docType: docType,
      fileUrl: 'https://example.test/$docType.pdf',
    );

void main() {
  group('groupRequestFiles signing section', () {
    test('TC1 bilateral + only contract/kuts → 2 signing rows, no creation contract', () {
      final files = [
        _file('passport_front'),
        _file('contract'),
        _file('kuts'),
      ];

      final grouped = groupRequestFiles(
        files: files,
        statusSubType: 'primary_documents_sent',
        dealType: 'bilateral',
      );

      expect(grouped.signingPairs.length, 2);
      expect(
        grouped.signingPairs.map((p) => p.baseDocType).toSet(),
        {CustomsDocType.contract, CustomsDocType.kuts},
      );
      expect(
        grouped.creation.any((f) => f.docType == 'contract'),
        isFalse,
      );
    });

    test('TC2 manager_execution → signing section empty', () {
      final files = [
        _file('passport_front'),
        _file('contract'),
        _file('invoice'),
      ];

      final grouped = groupRequestFiles(
        files: files,
        statusSubType: 'manager_execution',
        dealType: 'bilateral',
      );

      expect(grouped.signingPairs, isEmpty);
      expect(
        grouped.creation.any((f) => f.docType == 'contract'),
        isTrue,
      );
    });

    test('dealType null → signing section empty even with signing files', () {
      final grouped = groupRequestFiles(
        files: [_file('contract'), _file('kuts')],
        statusSubType: 'primary_documents_sent',
        dealType: null,
      );

      expect(grouped.signingPairs, isEmpty);
    });

    test('no empty slots for signing types without files at primary_documents_sent', () {
      final grouped = groupRequestFiles(
        files: [_file('contract'), _file('kuts')],
        statusSubType: 'primary_documents_sent',
        dealType: 'bilateral',
      );

      final bases = grouped.signingPairs.map((p) => p.baseDocType).toSet();
      expect(bases.contains(CustomsDocType.recyclingFeeCalc), isFalse);
      expect(bases.contains(CustomsDocType.fundsTransferApplication), isFalse);
      expect(bases.contains(CustomsDocType.passportNotarizedCopy), isFalse);
    });
  });
}
