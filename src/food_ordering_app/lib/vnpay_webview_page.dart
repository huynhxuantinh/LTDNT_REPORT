import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Màn hình nhúng WebView hiển thị cổng thanh toán VNPay trực tiếp trong app.
/// Đợi trang trả về được tải trước khi quay lại màn kiểm tra trạng thái.
class VnPayWebViewPage extends StatefulWidget {
  final int orderId;
  final String orderCode;
  final String paymentUrl;

  const VnPayWebViewPage({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.paymentUrl,
  });

  @override
  State<VnPayWebViewPage> createState() => _VnPayWebViewPageState();
}

class _VnPayWebViewPageState extends State<VnPayWebViewPage> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _returnNavigationStarted = false;
  bool _returnHandled = false;

  bool _isReturnUrl(String url) =>
      Uri.tryParse(url)?.path.endsWith('/api/orders/vnpay-return') ?? false;

  void _finishReturn() {
    if (!_returnNavigationStarted || _returnHandled || !mounted) return;
    _returnHandled = true;
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_isReturnUrl(request.url)) _returnNavigationStarted = true;
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) {
            if (_isReturnUrl(url)) _finishReturn();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _finishReturn();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
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

  void _showTestCardSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.credit_card, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Thông tin thẻ test Sandbox (NCB)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Ngân hàng', 'NCB'),
            _buildInfoRow('Số thẻ', '9704198526191432152'),
            _buildInfoRow('Tên chủ thẻ', 'NGUYEN VAN A'),
            _buildInfoRow('Ngày phát hành', '07/15'),
            _buildInfoRow('Mã OTP', '123456'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu, tiếp tục nhập thanh toán'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Row(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
                onPressed: () => _copyToClipboard(value, label),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
      appBar: AppBar(
        title: Text('VNPay - ${widget.orderCode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Xem thông tin thẻ test',
            onPressed: _showTestCardSheet,
          ),
        ],
        bottom: _loadingProgress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _loadingProgress / 100.0),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
