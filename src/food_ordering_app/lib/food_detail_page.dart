import 'package:flutter/material.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/member_food_api.dart';

class FoodDetailPage extends StatefulWidget {
  const FoodDetailPage({super.key, required this.foodId});
  final int foodId;
  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  late Future<MemberFoodItem> _food;
  bool _adding = false;
  @override
  void initState() {
    super.initState();
    _food = MemberFoodApi.getById(widget.foodId);
  }

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      await CartApi.add(widget.foodId);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã thêm vào giỏ hàng.')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết món')),
    body: FutureBuilder<MemberFoodItem>(
      future: _food,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done)
          return const AppLoadingState();
        if (s.hasError)
          return AppErrorState(
            onRetry: () =>
                setState(() => _food = MemberFoodApi.getById(widget.foodId)),
          );
        final x = s.data!;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(x.name, style: Theme.of(c).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(x.categoryName),
              const SizedBox(height: 12),
              Text('${x.price.toStringAsFixed(0)} đ'),
              if (x.description != null) ...[
                const SizedBox(height: 12),
                Text(x.description!),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: _adding ? null : _add,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(_adding ? 'Đang thêm...' : 'Thêm vào giỏ'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
