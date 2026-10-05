import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class PaymentMessage {
  const PaymentMessage({
    required this.source,
    required this.externalId,
    required this.text,
    required this.receivedAt,
  });

  final String source;
  final String externalId;
  final String text;
  final DateTime receivedAt;
}

// Conservative suggestions only: the user always confirms the original text.
class PaymentMessageParser {
  const PaymentMessageParser();

  ExpenseDraft? parse(PaymentMessage message) {
    final text = message.text;
    if (RegExp(
      r'취소|환불|충전|입금|이체|결제예정|결제 예정|청구|캐시백|적립|인증번호|OTP',
      caseSensitive: false,
    ).hasMatch(text)) {
      return null;
    }
    if (!RegExp(r'승인|결제|이용').hasMatch(text)) return null;
    if (RegExp(
      r'USD|EUR|JPY|달러|엔화|해외|\$|€',
      caseSensitive: false,
    ).hasMatch(text)) {
      return null;
    }
    final amounts = <int>{};
    for (final line in text.split('\n')) {
      if (RegExp(r'잔액|누적|한도|총액|결제일').hasMatch(line)) continue;
      for (final match in RegExp(
        r'(?<![\d.,])([1-9]\d{0,2}(?:,\d{3})+|[1-9]\d*)\s*원',
      ).allMatches(line)) {
        final value = int.tryParse(match[1]!.replaceAll(',', ''));
        if (value != null && value <= 999999999999) amounts.add(value);
      }
    }
    if (amounts.length != 1) return null;
    final local = message.receivedAt.toLocal();
    var date = LocalDate.fromDateTime(local);
    var minutes = local.hour * 60 + local.minute;
    final stamp = RegExp(
      r'(?:([12]\d{3})[./-])?(\d{1,2})[./-](\d{1,2})\s+(\d{1,2}):(\d{2})',
    ).firstMatch(text);
    if (stamp != null) {
      try {
        var year = stamp[1] == null ? local.year : int.parse(stamp[1]!);
        final month = int.parse(stamp[2]!);
        final day = int.parse(stamp[3]!);
        if (stamp[1] == null && month == 12 && local.month == 1) year--;
        final hour = int.parse(stamp[4]!);
        final minute = int.parse(stamp[5]!);
        if (hour > 23 || minute > 59) return null;
        date = LocalDate(year, month, day);
        minutes = hour * 60 + minute;
      } on ArgumentError {
        return null;
      }
    }
    return ExpenseDraft(
      amount: amounts.single,
      category: ExpenseCategory.other,
      paymentMethod: PaymentMethod.card,
      eventDate: date,
      eventTimeMinutes: minutes,
    );
  }
}
