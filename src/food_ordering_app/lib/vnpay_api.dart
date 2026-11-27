import 'package:food_ordering_app/network_timeout.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:food_ordering_app/api_config.dart';
import 'package:food_ordering_app/auth_api.dart';
import 'package:food_ordering_app/session_helper.dart';

/// Dữ liệu thanh toán VNPay Sandbox trả về từ API.
class VnPayInfo {
  final int orderId;
  final String orderCode;
  final double amount;
  final String paymentUrl;
  final String paymentStatus;
  final bool demoEnabled;

  const VnPayInfo({
    required this.orderId,
    required this.orderCode,
    required this.amount,
    required this.paymentUrl,
    required this.paymentStatus,
    this.demoEnabled = false,
  });

  factory VnPayInfo.fromJson(Map<String, dynamic> j) => VnPayInfo(
    orderId: j['orderId'] as int,
    orderCode: j['orderCode'] as String,
    amount: (j['amount'] as num).toDouble(),
    paymentUrl: j['paymentUrl'] as String,
    paymentStatus: j['paymentStatus'] as String,
    demoEnabled: j['demoEnabled'] == true,
  );
}

class VnPayApi {
  /// Lấy URL thanh toán VNPay Sandbox cho đơn hàng
  static Future<VnPayInfo> getVnPayUrl(int orderId) async {
    final token = await SessionHelper.accessToken;
    final res = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/orders/$orderId/vnpay'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(apiRequestTimeout);

    if (res.statusCode == 200) {
      return VnPayInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    String? message;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['error'] is Map) {
        message = (body['error'] as Map)['message'] as String?;
      }
    } catch (_) {
      // Use the generic message for malformed responses.
    }
    throw ApiException(
      message ?? 'Không thể tạo URL thanh toán VNPay.',
      statusCode: res.statusCode,
    );
  }

  /// Giả lập xác nhận thanh toán VNPay thành công (phục vụ Demo / chấm điểm)
  static Future<bool> simulateSuccess(int orderId) async {
    final token = await SessionHelper.accessToken;
    final res = await http
        .post(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/orders/$orderId/vnpay/simulate-success',
          ),
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
        .timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['paymentStatus'] as String;
    }
    throw ApiException(
      'Không thể kiểm tra trạng thái thanh toán.',
      statusCode: res.statusCode,
    );
  }
}
