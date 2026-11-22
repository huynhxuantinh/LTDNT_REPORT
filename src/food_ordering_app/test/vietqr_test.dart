import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/vietqr_api.dart';

void main() {
  test('parses VietQrInfo response accurately', () {
    final info = VietQrInfo.fromJson({
      'orderId': 101,
      'orderCode': 'DLV-20261122001',
      'amount': 150000,
      'bankId': 'MB',
      'accountNo': '0987654321',
      'accountName': 'QUAN AN DEMO',
      'transferContent': 'DLV-20261122001',
      'qrImageUrl': 'https://img.vietqr.io/image/MB-0987654321-compact2.png',
      'paymentStatus': 'Unpaid',
    });

    expect(info.orderId, 101);
    expect(info.orderCode, 'DLV-20261122001');
    expect(info.amount, 150000.0);
    expect(info.bankId, 'MB');
    expect(info.accountNo, '0987654321');
    expect(info.accountName, 'QUAN AN DEMO');
    expect(info.transferContent, 'DLV-20261122001');
    expect(info.qrImageUrl, 'https://img.vietqr.io/image/MB-0987654321-compact2.png');
    expect(info.paymentStatus, 'Unpaid');
  });
}

