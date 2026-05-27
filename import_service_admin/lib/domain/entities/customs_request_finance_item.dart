import 'package:equatable/equatable.dart';

class CustomsRequestFinanceItem extends Equatable {
  const CustomsRequestFinanceItem({
    required this.lineType,
    this.title,
    this.amountText,
    this.paymentQrUrl,
    this.receiptUrl,
  });

  final String lineType;
  final String? title;
  final String? amountText;
  final String? paymentQrUrl;
  final String? receiptUrl;

  @override
  List<Object?> get props => [lineType, amountText];
}
