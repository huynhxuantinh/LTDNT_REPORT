import 'package:flutter/material.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/food_detail_page.dart';
import 'package:trek_bikes_app/food_image.dart';
import 'package:trek_bikes_app/money_format.dart';
import 'package:trek_bikes_app/member_food_api.dart';

class HomeLatestFoods extends StatefulWidget {
  const HomeLatestFoods({super.key, this.categoryId, this.categoryName});
  final int? categoryId;
  final String? categoryName;
  @override
  State<HomeLatestFoods> createState() => _HomeLatestFoodsState();
}

class _HomeLatestFoodsState extends State<HomeLatestFoods> {
  static const _pageSize = 10;
  late Future<MemberFoodPage> _foods;
  final _search = TextEditingController();
  int _page = 1;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeLatestFoods oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _page = 1;
      _reload();
    }
  }

  void _reload() {
    _foods = MemberFoodApi.getPage(
      page: _page,
      pageSize: _pageSize,
      categoryId: widget.categoryId,
      search: _search.text,
    );
  }

  void _applySearch() => setState(() {
    _page = 1;
    _reload();
  });
  void _goToPage(int page) => setState(() {
    _page = page;
    _reload();
  });
  Future<void> _add(MemberFoodItem food) async {
    try {
      final cart = await CartApi.add(food.foodItemId);
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
          const SnackBar(content: Text('Không thể thêm món. Hãy thử lại.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _applySearch(),
          decoration: InputDecoration(
            hintText: 'Tìm món ăn',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Tìm kiếm',
              onPressed: _applySearch,
              icon: const Icon(Icons.arrow_forward),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        child: Text(
          widget.categoryName == null
              ? 'Món mới nhất'
              : 'Món: ${widget.categoryName}',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      Expanded(
        child: FutureBuilder<MemberFoodPage>(
          future: _foods,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const AppLoadingState(message: 'Đang tải món ăn...');
            if (snapshot.hasError)
              return AppErrorState(onRetry: () => setState(_reload));
            final result = snapshot.data;
            if (result == null || result.items.isEmpty)
              return const AppEmptyState(
                message: 'Không tìm thấy món ăn phù hợp.',
              );
            return Column(
              children: [
                if (result.isOffline)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Đang xem dữ liệu đã lưu trên máy; thông tin có thể chưa mới.',
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: result.items.length,
                    itemBuilder: (context, index) {
                      final food = result.items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FoodDetailPage(foodId: food.foodItemId),
                            ),
                          ),
                          leading: FoodImage(imageUrl: food.imageUrl),
                          title: Text(
                            food.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${food.categoryName}\n${formatVnd(food.price)} đ',
                          ),
                          isThreeLine: true,
                          trailing: IconButton.filledTonal(
                            tooltip: 'Thêm vào giỏ',
                            onPressed: () => _add(food),
                            icon: const Icon(Icons.add_shopping_cart),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Trang trước',
                      onPressed: result.page > 1
                          ? () => _goToPage(result.page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('Trang ${result.page}/${result.totalPages}'),
                    IconButton(
                      tooltip: 'Trang sau',
                      onPressed: result.page < result.totalPages
                          ? () => _goToPage(result.page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
