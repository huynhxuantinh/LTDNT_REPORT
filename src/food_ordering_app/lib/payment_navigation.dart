import 'package:flutter/material.dart';

void returnHomeAfterPayment(BuildContext context, {bool demo = false}) {
  final messenger = ScaffoldMessenger.of(context);
  Navigator.of(context).popUntil((route) => route.isFirst);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          demo ? 'Đã xác nhận thanh toán demo.' : 'Thanh toán thành công.',
        ),
      ),
    );
}
