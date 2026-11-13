import 'package:flutter/material.dart';
import 'package:trek_bikes_app/cart_api.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final form = GlobalKey<FormState>(),
      name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController(),
      note = TextEditingController();
  bool loading = false;
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await CartApi.checkout(
        name: name.text,
        phone: phone.text,
        address: address.text,
        note: note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Checkout')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: form,
        child: Column(
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên người nhận'),
              validator: (v) => v!.isEmpty ? 'Bắt buộc' : null,
            ),
            TextFormField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'SĐT'),
              validator: (v) => v!.isEmpty ? 'Bắt buộc' : null,
            ),
            TextFormField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
              validator: (v) => v!.isEmpty ? 'Bắt buộc' : null,
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: loading ? null : submit,
              child: const Text('Đặt hàng'),
            ),
          ],
        ),
      ),
    ),
  );
}
