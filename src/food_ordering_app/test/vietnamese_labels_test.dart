import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/main.dart';
import 'package:trek_bikes_app/user_error.dart';
import 'package:trek_bikes_app/vietnamese_labels.dart';

void main() {
  testWidgets('application uses Vietnamese Material localization', (tester) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const FoodOrderingApp());
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(context).languageCode, 'vi');
    expect(MaterialLocalizations.of(context).cancelButtonLabel.toLowerCase(), 'huỷ');
  });

  test('order and role labels are displayed in Vietnamese', () {
    expect(orderStatusLabel('Pending'), 'Chờ xác nhận');
    expect(orderStatusLabel('Delivering'), 'Đang giao');
    expect(orderStatusLabel('Completed'), 'Hoàn thành');
    expect(orderTypeLabel('DineIn'), 'Ăn tại quán');
    expect(paymentStatusLabel('Unpaid'), 'Chưa thanh toán');
    expect(roleLabel('Staff'), 'Nhân viên');
    expect(orderStatusLabel('Unknown'), 'Không xác định');
  });

  test('technical exceptions use a Vietnamese message', () {
    expect(
      userErrorMessage(Exception('Network failure'), 'Không thể kết nối.'),
      'Không thể kết nối.',
    );
    expect(
      userErrorMessage(
        const ApiException('Đơn hàng đã thanh toán.'),
        'Có lỗi.',
      ),
      'Đơn hàng đã thanh toán.',
    );
  });
}
