import 'package:flutter/material.dart';
import 'package:trek_bikes_app/user_error.dart';
import 'package:flutter/services.dart';
import 'package:trek_bikes_app/vietqr_api.dart';
import 'package:trek_bikes_app/payment_navigation.dart';
import 'package:trek_bikes_app/money_format.dart';

class VietQrPaymentPage extends StatefulWidget {
  final int orderId;
  final Future<VietQrInfo> Function(int)? loadInfo;
  final Future<String> Function(int)? checkStatus;
  final Future<bool> Function(int)? confirmDemo;
  final bool popToRootOnSuccess;
  const VietQrPaymentPage({
    super.key,
    required this.orderId,
    this.loadInfo,
    this.checkStatus,
    this.confirmDemo,
    this.popToRootOnSuccess = true,
  });

  @override
  State<VietQrPaymentPage> createState() => _VietQrPaymentPageState();
}

class _VietQrPaymentPageState extends State<VietQrPaymentPage> {
  VietQrInfo? info;
  bool loading = true;
  bool confirming = false;
  String? error;
  String paymentStatus = 'Unpaid';

  @override
  void initState() {
    super.initState();
    _loadVietQr();
  }

  Future<void> _loadVietQr() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await (widget.loadInfo ?? VietQrApi.getVietQr)(
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
          error = userErrorMessage(e, 'Không thể tải mã QR. Vui lòng thử lại.');
          loading = false;
        });
      }
    }
  }

  Future<void> _checkStatus() async {
    try {
      final status = await (widget.checkStatus ?? VietQrApi.getPaymentStatus)(
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
                  ? 'Đơn hàng đã được thanh toán!'
                  : 'Đơn hàng chưa nhận được tiền.',
            ),
            backgroundColor: status == 'Paid' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userErrorMessage(e, 'Không thể kiểm tra trạng thái thanh toán.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _simulateConfirm() async {
    setState(() => confirming = true);
    try {
      final ok = await (widget.confirmDemo ?? VietQrApi.confirmPayment)(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userErrorMessage(
                e,
                'Không thể xác nhận thanh toán. Vui lòng thử lại.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => confirming = false);
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

  Widget _buildInfoRow(String label, String value, {bool copyable = false}) {
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
              if (copyable) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _copyToClipboard(value, label),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 16, color: Colors.blue),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán VietQR')),
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
                    onPressed: _loadVietQr,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Banner thông báo thanh toán thành công
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
                                  'ĐÃ THANH TOÁN THÀNH CÔNG',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Quán đã ghi nhận thanh toán cho đơn hàng.',
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

                  // Card chứa mã QR
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            '${formatVnd(info!.amount)} đ',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Đơn hàng: ${info!.orderCode}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              info!.qrImageUrl,
                              width: 260,
                              height: 260,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  width: 260,
                                  height: 260,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => const SizedBox(
                                width: 260,
                                height: 260,
                                child: Center(
                                  child: Text('Không tải được ảnh QR'),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Mở ứng dụng Ngân hàng để quét mã thanh toán',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card thông tin chuyển khoản chi tiết
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
                          const Text(
                            'Thông tin chuyển khoản',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          _buildInfoRow('Ngân hàng', info!.bankId),
                          _buildInfoRow(
                            'Số tài khoản',
                            info!.accountNo,
                            copyable: true,
                          ),
                          _buildInfoRow('Chủ tài khoản', info!.accountName),
                          _buildInfoRow(
                            'Số tiền',
                            '${formatVnd(info!.amount)} đ',
                            copyable: true,
                          ),
                          _buildInfoRow(
                            'Nội dung',
                            info!.transferContent,
                            copyable: true,
                          ),
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
                            onPressed: confirming ? null : _simulateConfirm,
                            icon: confirming
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
