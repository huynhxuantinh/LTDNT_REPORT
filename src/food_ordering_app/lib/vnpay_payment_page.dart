import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trek_bikes_app/vnpay_api.dart';
import 'package:trek_bikes_app/payment_navigation.dart';
import 'package:trek_bikes_app/vnpay_webview_page.dart';
import 'package:trek_bikes_app/money_format.dart';

class VnPayPaymentPage extends StatefulWidget {
  final int orderId;
  final Future<VnPayInfo> Function(int)? loadInfo;
  final Future<String> Function(int)? checkStatus;
  final Future<bool> Function(int)? confirmDemo;
  final bool popToRootOnSuccess;
  const VnPayPaymentPage({
    super.key,
    required this.orderId,
    this.loadInfo,
    this.checkStatus,
    this.confirmDemo,
    this.popToRootOnSuccess = true,
  });

  @override
  State<VnPayPaymentPage> createState() => _VnPayPaymentPageState();
}

class _VnPayPaymentPageState extends State<VnPayPaymentPage> {
  VnPayInfo? info;
  bool loading = true;
  bool simulating = false;
  String? error;
  String paymentStatus = 'Unpaid';

  @override
  void initState() {
    super.initState();
    _loadVnPay();
  }

  Future<void> _loadVnPay() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await (widget.loadInfo ?? VnPayApi.getVnPayUrl)(
        widget.orderId,
      );
      if (mounted) {
        if (res.paymentStatus == 'Paid') {
          returnHomeAfterPayment(context, popToRoot: widget.popToRootOnSuccess);
          return;
        }
        setState(() {
          info = res;
          paymentStatus = res.paymentStatus;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Lỗi tạo URL VNPay: $e';
          loading = false;
        });
      }
    }
  }

  Future<void> _openWebView() async {
    if (info == null) return;
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VnPayWebViewPage(
          orderId: widget.orderId,
          orderCode: info!.orderCode,
          paymentUrl: info!.paymentUrl,
        ),
      ),
    );

    if (success == true && mounted) {
      returnHomeAfterPayment(context, popToRoot: widget.popToRootOnSuccess);
    } else if (mounted) {
      _checkStatus();
    }
  }

  Future<void> _openPortal() async {
    if (info == null) return;
    final uri = Uri.parse(info!.paymentUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở cổng VNPay trên trình duyệt.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi mở trình duyệt: $e')));
      }
    }
  }

  Future<void> _checkStatus() async {
    try {
      final status = await (widget.checkStatus ?? VnPayApi.getPaymentStatus)(
        widget.orderId,
      );
      if (mounted) {
        if (status == 'Paid') {
          returnHomeAfterPayment(context, popToRoot: widget.popToRootOnSuccess);
          return;
        }
        setState(() => paymentStatus = status);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'Paid'
                  ? 'Đơn hàng đã thanh toán thành công!'
                  : 'Đơn hàng chưa ghi nhận thanh toán.',
            ),
            backgroundColor: status == 'Paid' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi kiểm tra trạng thái: $e')));
      }
    }
  }

  Future<void> _simulateSuccess() async {
    setState(() => simulating = true);
    try {
      final ok = await (widget.confirmDemo ?? VnPayApi.simulateSuccess)(
        widget.orderId,
      );
      if (mounted) {
        if (ok) {
          returnHomeAfterPayment(
            context,
            demo: true,
            popToRoot: widget.popToRootOnSuccess,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể xác nhận thanh toán.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => simulating = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildCardInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _copyToClipboard(value, label),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy, size: 16, color: Colors.blue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cổng thanh toán VNPay')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadVnPay,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Banner trạng thái
                  if (paymentStatus == 'Paid')
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 32,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'THANH TOÁN VNPAY THÀNH CÔNG',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Giao dịch đã được ghi nhận trên hệ thống.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Card tóm tắt đơn
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.payment,
                                color: Colors.blue,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${formatVnd(info!.amount)} đ',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mã đơn hàng: ${info!.orderCode}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF005BAA,
                                ), // Màu xanh đặc trưng VNPay
                              ),
                              onPressed: _openWebView,
                              icon: const Icon(Icons.payment),
                              label: const Text(
                                'Thanh toán VNPay (Trong ứng dụng)',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _openPortal,
                            icon: const Icon(Icons.open_in_browser, size: 18),
                            label: const Text(
                              'Hoặc mở bằng trình duyệt ngoài',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card hướng dẫn thẻ test Sandbox
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.credit_card, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Thẻ test VNPay Sandbox miễn phí',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          _buildCardInfoRow('Ngân hàng', 'NCB'),
                          _buildCardInfoRow('Số thẻ', '9704198526191432152'),
                          _buildCardInfoRow('Tên chủ thẻ', 'NGUYEN VAN A'),
                          _buildCardInfoRow('Ngày phát hành', '07/15'),
                          _buildCardInfoRow('Mã OTP', '123456'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nút hành động
                  if (paymentStatus != 'Paid') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _checkStatus,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Kiểm tra'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: simulating ? null : _simulateSuccess,
                            icon: simulating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Đã chuyển (Demo)'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: () => returnHomeAfterPayment(
                        context,
                        popToRoot: widget.popToRootOnSuccess,
                      ),
                      child: const Text('Hoàn tất'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
