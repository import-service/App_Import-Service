import 'package:flutter_test/flutter_test.dart';

import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/presentation/helpers/request_detail_pending_actions.dart';
import 'package:import_service_app/presentation/helpers/request_status_action_hint.dart';

CustomsRequestFile _file(String docType) => CustomsRequestFile(
      docType: docType,
      fileUrl: 'https://example.test/$docType.pdf',
    );

CarListItem _item({
  required String subType,
  List<CustomsRequestFile> files = const [],
}) =>
    CarListItem(
      id: '1',
      ownerFullName: 'Test',
      carMake: 'Lexus',
      carModel: 'RX',
      vin: 'VIN0001',
      status: RequestStatus.inProgress,
      statusSubType: subType,
      dealType: 'bilateral',
      files: files,
    );

void main() {
  group('signingSectionNeedsAction', () {
    test('all *_sign uploaded → no action', () {
      final item = _item(
        subType: 'primary_documents_sent',
        files: [
          _file('contract'),
          _file('kuts'),
          _file('contract_sign'),
          _file('kuts_sign'),
          _file('passport_notarized_copy_sign'),
        ],
      );
      final grouped = groupedFilesForItem(item);
      expect(grouped.signingPairs, isNotEmpty);
      expect(signingSectionNeedsAction(item, grouped), isFalse);
      expect(hasPendingClientUploadActions(item), isFalse);
    });

    test('missing *_sign → action required', () {
      final item = _item(
        subType: 'primary_documents_sent',
        files: [_file('contract'), _file('kuts')],
      );
      final grouped = groupedFilesForItem(item);
      expect(signingSectionNeedsAction(item, grouped), isTrue);
      expect(hasPendingClientUploadActions(item), isTrue);
    });
  });

  group('paymentSectionNeedsAction', () {
    test('fee without receipt → action', () {
      final item = _item(
        subType: 'primary_documents_sent',
        files: [
          _file('contract'),
          _file('kuts'),
          _file('contract_sign'),
          _file('kuts_sign'),
          _file('passport_notarized_copy_sign'),
          _file('payment_recycling_fee'),
        ],
      );
      final grouped = groupedFilesForItem(item);
      expect(paymentSectionNeedsAction(item, grouped), isTrue);
      expect(requestNeedsPaymentReceiptAction(item), isTrue);
      expect(hasPendingClientUploadActions(item), isTrue);
    });

    test('fee + receipt → no action', () {
      final item = _item(
        subType: 'primary_documents_sent',
        files: [
          _file('contract'),
          _file('kuts'),
          _file('contract_sign'),
          _file('kuts_sign'),
          _file('passport_notarized_copy_sign'),
          _file('payment_recycling_fee'),
          _file('payment_recycling_fee_receipt'),
        ],
      );
      final grouped = groupedFilesForItem(item);
      expect(paymentSectionNeedsAction(item, grouped), isFalse);
      expect(requestNeedsPaymentReceiptAction(item), isFalse);
      expect(hasPendingClientUploadActions(item), isFalse);
    });
  });
}
