import 'package:flutter/material.dart';

void returnHomeAfterPayment(
  BuildContext context, {
  bool demo = false,
  bool popToRoot = true,
}) {
  final messenger = ScaffoldMessenger.of(context);
  if (popToRoot) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  } else {
    Navigator.of(context).pop(true);
  }
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
