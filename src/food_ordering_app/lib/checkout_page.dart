import 'package:flutter/material.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/vietqr_payment_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
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
      final orderId = await CartApi.checkout(
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
            builder: (_) => VietQrPaymentPage(orderId: orderId),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đặt hàng thành công!')),
        );
      }

      if (mounted) Navigator.pop(context, true);
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
