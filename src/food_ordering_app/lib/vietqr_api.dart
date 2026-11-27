import 'package:trek_bikes_app/network_timeout.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/session_helper.dart';

/// Dữ liệu thông tin thanh toán VietQR trả về từ API.
class VietQrInfo {
  final int orderId;
  final String orderCode;
  final double amount;
  final String bankId;
  final String accountNo;
  final String accountName;
  final String transferContent;
  final String qrImageUrl;
  final String paymentStatus;
  final bool demoEnabled;

  const VietQrInfo({
    required this.orderId,
    required this.orderCode,
    required this.amount,
    required this.bankId,
    required this.accountNo,
    required this.accountName,
    required this.transferContent,
    required this.qrImageUrl,
    required this.paymentStatus,
    this.demoEnabled = false,
  });

  factory VietQrInfo.fromJson(Map<String, dynamic> j) => VietQrInfo(
    orderId: j['orderId'] as int,
    orderCode: j['orderCode'] as String,
    amount: (j['amount'] as num).toDouble(),
    bankId: j['bankId'] as String,
    accountNo: j['accountNo'] as String,
    accountName: j['accountName'] as String,
    transferContent: j['transferContent'] as String,
    qrImageUrl: j['qrImageUrl'] as String,
    paymentStatus: j['paymentStatus'] as String,
    demoEnabled: j['demoEnabled'] == true,
  );
}

class VietQrApi {
  /// Lấy thông tin mã VietQR cho đơn hàng
  static Future<VietQrInfo> getVietQr(int orderId) async {
    final token = await SessionHelper.accessToken;
    final res = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/orders/$orderId/vietqr'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(apiRequestTimeout);

    if (res.statusCode == 200) {
      return VietQrInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } else {
      throw const ApiException('Không thể lấy thông tin mã VietQR.');
    }
  }

  /// Xác nhận thanh toán VietQR thành công (Đối soát nhận tiền / Demo)
  static Future<bool> confirmPayment(int orderId) async {
    final token = await SessionHelper.accessToken;
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/orders/$orderId/vietqr/confirm'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(apiRequestTimeout);

    return res.statusCode == 200;
  }

  /// Kiểm tra trạng thái thanh toán hiện tại của đơn hàng
  static Future<String> getPaymentStatus(int orderId) async {
    final token = await SessionHelper.accessToken;
    final res = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/orders/$orderId/payment-status'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(apiRequestTimeout);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['paymentStatus'] as String;
    }
    return 'Unpaid';
  }
}
