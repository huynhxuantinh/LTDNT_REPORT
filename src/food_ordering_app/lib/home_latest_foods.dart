import 'package:flutter/material.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/member_food_api.dart';

class HomeLatestFoods extends StatefulWidget {
  const HomeLatestFoods({super.key});

  @override
  State<HomeLatestFoods> createState() => _HomeLatestFoodsState();
}

class _HomeLatestFoodsState extends State<HomeLatestFoods> {
  static const _pageSize = 10;
  late Future<MemberFoodPage> _foods;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _foods = MemberFoodApi.getLatest(page: _page, pageSize: _pageSize);

  void _goToPage(int page) {
    setState(() {
      _page = page;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MemberFoodPage>(
    future: _foods,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AppLoadingState(message: 'Đang tải món mới nhất...');
      }
      if (snapshot.hasError) {
        return AppErrorState(onRetry: () => setState(_reload));
      }
      final result = snapshot.data;
      if (result == null || result.items.isEmpty) {
        return const AppEmptyState(message: 'Chưa có món ăn để hiển thị.');
      }
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Món mới nhất',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: result.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final food = result.items[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.fastfood)),
                  title: Text(food.name),
                  subtitle: Text(food.categoryName),
                  trailing: Text('${food.price.toStringAsFixed(0)} đ'),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          ),
        ],
      );
    },
  );
}
