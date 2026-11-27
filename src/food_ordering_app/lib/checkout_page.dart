import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ordering_app/cart_api.dart';
import 'package:food_ordering_app/vietqr_payment_page.dart';
import 'package:food_ordering_app/vnpay_payment_page.dart';
import 'package:food_ordering_app/auth_api.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, this.checkout, this.vietQrBuilder});
  final Future<int> Function({
    required String name,
    required String phone,
    required String address,
    String? note,
  })?
  checkout;
  final Widget Function(int orderId)? vietQrBuilder;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final note = TextEditingController();
  String paymentMethod = 'VietQR';
  bool loading = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final orderId = await (widget.checkout ?? CartApi.checkout)(
        name: name.text,
        phone: phone.text,
        address: address.text,
        note: note.text,
      );

      if (!mounted) return;

      if (paymentMethod == 'VietQR') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                widget.vietQrBuilder?.call(orderId) ??
                VietQrPaymentPage(orderId: orderId),
          ),
        );
      } else if (paymentMethod == 'VNPay') {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VnPayPaymentPage(orderId: orderId)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đặt hàng thành công. Thanh toán khi nhận hàng.'),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      // Payment can remove this route before its transition has disposed it.
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (mounted && error.code == 'cart_price_changed') {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Giá món đã thay đổi'),
            content: Text(error.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Xem lại giỏ hàng'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa xác nhận được kết quả. Hãy kiểm tra đơn hàng trước khi đặt lại.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đặt hàng. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Thông tin giao hàng')),
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên người nhận'),
                validator: (v) => v!.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'SĐT'),
                validator: (v) => v!.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
                validator: (v) => v!.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Hình thức thanh toán',
                  prefixIcon: Icon(Icons.payment),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'VietQR',
                    child: Text('Chuyển khoản VietQR'),
                  ),
                  DropdownMenuItem(
                    value: 'VNPay',
                    child: Text('Cổng thanh toán VNPay Sandbox'),
                  ),
                  DropdownMenuItem(
                    value: 'COD',
                    child: Text('Tiền mặt khi nhận hàng (COD)'),
                  ),
                ],
                onChanged: (val) => setState(() => paymentMethod = val!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: loading ? null : submit,
                child: Text(loading ? 'Đang đặt hàng...' : 'Đặt hàng'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
