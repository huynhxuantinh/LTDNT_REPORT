import 'package:flutter/material.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/cart_icon_button.dart';
import 'package:trek_bikes_app/member_food_api.dart';
import 'package:trek_bikes_app/food_image.dart';
import 'package:trek_bikes_app/money_format.dart';
import 'package:trek_bikes_app/related_foods_section.dart';

class FoodDetailPage extends StatefulWidget {
  const FoodDetailPage({
    super.key,
    required this.foodId,
    this.loadFood,
    this.loadCart,
    this.addToCart,
    this.loadImages,
    this.loadRelated,
  });
  final int foodId;
  final Future<MemberFoodItem> Function(int)? loadFood;
  final Future<Cart> Function()? loadCart;
  final Future<Cart> Function(int)? addToCart;
  final Future<List<String>> Function(int)? loadImages;
  final Future<MemberFoodPage> Function(int foodId, int page, int pageSize)?
  loadRelated;
  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  late Future<MemberFoodItem> _food;
  late Future<void> _cartReady;
  late Future<List<String>> _images;
  int _imageIndex = 0;
  bool _adding = false;
  @override
  void initState() {
    super.initState();
    _food = (widget.loadFood ?? MemberFoodApi.getById)(widget.foodId);
    _images = widget.loadImages != null
        ? widget.loadImages!(widget.foodId)
        : widget.loadFood != null
        ? Future.value([])
        : MemberFoodApi.getImages(widget.foodId);
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

  Future<void> _addFood(int foodId) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await _cartReady;
      final cart = await (widget.addToCart ?? CartApi.add)(foodId);
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
              FutureBuilder<List<String>>(
                future: _images,
                builder: (context, snapshot) {
                  final loaded = snapshot.data ?? [];
                  final images = loaded.isNotEmpty
                      ? loaded
                      : (x.imageUrl == null ? <String>[] : [x.imageUrl!]);
                  if (images.length <= 1)
                    return Center(
                      child: FoodImage(
                        imageUrl: images.isEmpty ? null : images.first,
                        size: 220,
                      ),
                    );
                  return Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (index) =>
                              setState(() => _imageIndex = index),
                          itemBuilder: (context, index) => Center(
                            child: FoodImage(
                              imageUrl: images[index],
                              size: 220,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Ảnh ${_imageIndex + 1}/${images.length}'),
                    ],
                  );
                },
              ),
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
                  onPressed: _adding ? null : () => _addFood(widget.foodId),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(_adding ? 'Đang thêm...' : 'Thêm vào giỏ'),
                ),
              ),
              const SizedBox(height: 28),
              RelatedFoodsSection(
                foodId: widget.foodId,
                loadRelated: widget.loadRelated,
                onAdd: (food) => _addFood(food.foodItemId),
                onOpen: (food) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FoodDetailPage(
                      foodId: food.foodItemId,
                      loadFood: widget.loadFood,
                      loadImages: widget.loadImages,
                      loadRelated: widget.loadRelated,
                      loadCart: widget.loadCart,
                      addToCart: widget.addToCart,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
