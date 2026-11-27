import 'package:flutter/material.dart';
import 'package:food_ordering_app/cart_api.dart';
import 'package:food_ordering_app/cart_page.dart';

class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: cartCount,
    builder: (context, count, _) => IconButton(
      tooltip: 'Giỏ hàng',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartPage()),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.shopping_cart),
      ),
    ),
  );
}
