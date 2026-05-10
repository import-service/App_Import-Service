import 'package:equatable/equatable.dart';

/// Пошлина / утиль: сумма с 1С, ссылка для оплаты по QR, ссылка на чек после загрузки на бэк.
/// [lineType] — код из 1С, не ключ локализации (напр. [customsDuty], [recyclingFee]).
final class VehicleFinanceItem extends Equatable {
  const VehicleFinanceItem({
    required this.lineType,
    required this.amountText,
    this.title,
    this.paymentQrUrl,
    this.receiptUrl,
  });

  /// Стабильные коды согласуйте с 1С (примеры): `customs_duty`, `recycling_fee`.
  final String lineType;

  /// Сумма, как к показу (или сериализуется с бэка).
  final String amountText;

  /// Необязательная подпись строки от 1С; если пусто — клиент подставляет по [lineType].
  final String? title;

  /// URL для отображения в QR (страница/сессия оплаты).
  final String? paymentQrUrl;

  /// URL загруженного на бэк чека (после аплода).
  final String? receiptUrl;

  factory VehicleFinanceItem.fromJson(Map<String, dynamic> json) {
    final fromNew = (json['lineType'] as String?)?.trim();
    if (fromNew != null && fromNew.isNotEmpty) {
      return VehicleFinanceItem(
        lineType: fromNew,
        amountText: (json['amountText'] as String?)?.trim() ?? (json['amount']?.toString() ?? ''),
        title: (json['title'] as String?)?.trim(),
        paymentQrUrl: (json['paymentQrUrl'] as String?)?.trim(),
        receiptUrl: (json['receiptUrl'] as String?)?.trim(),
      );
    }
    return VehicleFinanceItem(
      lineType: _lineTypeFromLegacyI18nKey(
        (json['labelI18nKey'] as String?)?.trim() ?? '',
      ),
      amountText: (json['amountText'] as String?)?.trim() ?? '',
      title: null,
      paymentQrUrl: (json['paymentQrUrl'] as String?)?.trim(),
      receiptUrl: (json['receiptUrl'] as String?)?.trim(),
    );
  }

  static String _lineTypeFromLegacyI18nKey(String key) {
    if (key == 'requestDetailFinanceRecycling' || key == 'recycling' || key == 'recycling_fee') {
      return 'recycling_fee';
    }
    return 'customs_duty';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lineType': lineType,
        'amountText': amountText,
        if (title != null) 'title': title,
        if (paymentQrUrl != null) 'paymentQrUrl': paymentQrUrl,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
      };

  @override
  List<Object?> get props => [lineType, amountText, title, paymentQrUrl, receiptUrl];
}
