import 'package:flutter/material.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/cart_icon_button.dart';
import 'package:trek_bikes_app/member_food_api.dart';
import 'package:trek_bikes_app/food_image.dart';
import 'package:trek_bikes_app/money_format.dart';

class FoodDetailPage extends StatefulWidget {
  const FoodDetailPage({
    super.key,
    required this.foodId,
    this.loadFood,
    this.loadCart,
    this.addToCart,
  });
  final int foodId;
  final Future<MemberFoodItem> Function(int)? loadFood;
  final Future<Cart> Function()? loadCart;
  final Future<Cart> Function(int)? addToCart;
  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  late Future<MemberFoodItem> _food;
  late Future<void> _cartReady;
  bool _adding = false;
  @override
  void initState() {
    super.initState();
    _food = (widget.loadFood ?? MemberFoodApi.getById)(widget.foodId);
    _cartReady = _refreshCart();
  }

  Future<void> _refreshCart() async {
    try {
      final cart = await (widget.loadCart ?? CartApi.get)();
      cartCount.value = cart.totalQuantity;
    } catch (_) {
      // Keep the last known count if the cart is temporarily unavailable.
    }
  }

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      await _cartReady;
      final cart = await (widget.addToCart ?? CartApi.add)(widget.foodId);
      cartCount.value = cart.totalQuantity;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cart.syncIssue != null
                  ? 'Chưa đồng bộ được giỏ: ${cart.syncIssue}'
                  : cart.isOffline
                  ? 'Đã lưu tạm trên máy; sẽ đồng bộ khi có mạng.'
                  : 'Đã thêm vào giỏ hàng.',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể thêm món vào giỏ.')),
        );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('Chi tiết món'),
      actions: const [CartIconButton()],
    ),
    body: FutureBuilder<MemberFoodItem>(
      future: _food,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done)
          return const AppLoadingState();
        if (s.hasError)
          return AppErrorState(
            onRetry: () => setState(() {
              _food = (widget.loadFood ?? MemberFoodApi.getById)(widget.foodId);
            }),
          );
        final x = s.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: FoodImage(imageUrl: x.imageUrl, size: 220)),
              const SizedBox(height: 20),
              Text(
                x.name,
                style: Theme.of(c).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(x.categoryName),
              const SizedBox(height: 12),
              Text(
                '${formatVnd(x.price)} đ',
                style: Theme.of(c).textTheme.titleLarge?.copyWith(
                  color: Theme.of(c).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (x.description != null) ...[
                const SizedBox(height: 12),
                Text(x.description!),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _adding ? null : _add,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(_adding ? 'Đang thêm...' : 'Thêm vào giỏ'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
