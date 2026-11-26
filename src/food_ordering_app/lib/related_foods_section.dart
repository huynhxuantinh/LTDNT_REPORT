import 'package:flutter/material.dart';
import 'package:trek_bikes_app/food_image.dart';
import 'package:trek_bikes_app/member_food_api.dart';
import 'package:trek_bikes_app/money_format.dart';

class RelatedFoodsSection extends StatefulWidget {
  const RelatedFoodsSection({
    super.key,
    required this.foodId,
    required this.onOpen,
    required this.onAdd,
    this.loadRelated,
  });
  final int foodId;
  final void Function(MemberFoodItem) onOpen;
  final void Function(MemberFoodItem) onAdd;
  final Future<MemberFoodPage> Function(int foodId, int page, int pageSize)?
  loadRelated;

  @override
  State<RelatedFoodsSection> createState() => _RelatedFoodsSectionState();
}

class _RelatedFoodsSectionState extends State<RelatedFoodsSection> {
  static const _pageSize = 4;
  int _page = 1;
  late Future<MemberFoodPage> _related;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _related =
        widget.loadRelated?.call(widget.foodId, _page, _pageSize) ??
        MemberFoodApi.getRelated(
          foodId: widget.foodId,
          page: _page,
          pageSize: _pageSize,
        );
  }

  void _goTo(int page) => setState(() {
    _page = page;
    _reload();
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Món liên quan',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      FutureBuilder<MemberFoodPage>(
        future: _related,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Column(
              children: [
                const Text('Không thể tải món liên quan.'),
                TextButton.icon(
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            );
          }
          final result = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (result.isOffline)
                const Text('Đang xem các món đã lưu trên máy.'),
              if (result.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Chưa có món liên quan.'),
                ),
              ...result.items.map(
                (food) => Card(
                  child: ListTile(
                    leading: FoodImage(imageUrl: food.imageUrl),
                    title: Text(
                      food.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${formatVnd(food.price)} đ'),
                    onTap: () => widget.onOpen(food),
                    trailing: IconButton(
                      tooltip: 'Thêm ${food.name} vào giỏ',
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () => widget.onAdd(food),
                    ),
                  ),
                ),
              ),
              if (result.totalPages > 1 || _page > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Trang món liên quan trước',
                      onPressed: _page > 1 ? () => _goTo(_page - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      'Trang $_page/${result.totalPages == 0 ? 1 : result.totalPages}',
                    ),
                    IconButton(
                      tooltip: 'Trang món liên quan sau',
                      onPressed: _page < result.totalPages
                          ? () => _goTo(_page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    ],
  );
}
