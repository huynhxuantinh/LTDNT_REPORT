import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/vnpay_api.dart';

void main() {
  test('parses VnPayInfo response accurately', () {
    final info = VnPayInfo.fromJson({
      'orderId': 202,
      'orderCode': 'DLV-20261122002',
      'amount': 250000,
      'paymentUrl': 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_Amount=25000000&vnp_Command=pay',
      'paymentStatus': 'Unpaid',
    });

    expect(info.orderId, 202);
    expect(info.orderCode, 'DLV-20261122002');
    expect(info.amount, 250000.0);
    expect(info.paymentUrl, contains('sandbox.vnpayment.vn'));
    expect(info.paymentStatus, 'Unpaid');
  });
}

