import 'package:flutter_test/flutter_test.dart';

import 'package:import_service_app/data/models/request_draft.dart';
import 'package:import_service_app/data/models/request_form_model.dart';

void main() {
  test('companyInn roundtrips in draft JSON', () {
    const form = RequestFormModel(
      companyName: 'ООО Тест',
      companyInn: '7707083893',
      companyEmail: 'a@b.ru',
      companyPhone: '+79990000001',
      personFullName: 'Иванов И.И.',
      personPhone: '+79990000002',
      personSnils: '11223344595',
      carBrand: 'Toyota',
      carModel: 'Camry',
      vin: 'VIN12345678901234',
      hasSunroof: false,
      hasAllWheelDrive: false,
      wasInRussiaLast12Months: false,
      hasOtherCars: false,
      comment: '',
    );

    final draft = RequestDraft(
      id: 'draft-1',
      updatedAt: DateTime.utc(2026, 5, 29),
      form: form,
    );

    final restored = RequestDraft.fromJson(draft.toJson());
    expect(restored.form.companyInn, '7707083893');
  });

  test('fromJson reads legacy inn key', () {
    final form = RequestFormModel.fromJson(<String, dynamic>{
      'companyName': 'ООО Тест',
      'inn': '7707 083 893',
      'companyEmail': '',
      'companyPhone': '',
      'personFullName': '',
      'personPhone': '',
      'personSnils': '',
      'carBrand': '',
      'carModel': '',
      'vin': '',
      'hasSunroof': false,
      'hasAllWheelDrive': false,
      'wasInRussiaLast12Months': false,
      'hasOtherCars': false,
      'comment': '',
    });

    expect(form.companyInn, '7707083893');
  });
}
