import 'package:flutter/material.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/category_api.dart';
import 'package:trek_bikes_app/food_item_api.dart';
import 'package:trek_bikes_app/food_image.dart';
import 'package:trek_bikes_app/money_format.dart';

class AdminFoodItemsPage extends StatefulWidget {
  const AdminFoodItemsPage({super.key});

  @override
  State<AdminFoodItemsPage> createState() => _AdminFoodItemsPageState();
}

class _AdminFoodItemsPageState extends State<AdminFoodItemsPage> {
  static const _pageSize = 10;
  final _searchController = TextEditingController();
  late Future<List<AdminCategory>> _categories;
  late Future<AdminFoodPage> _foods;
  int _page = 1;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _categories = CategoryApi.getAll();
    _reloadFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reloadFoods() {
    _foods = FoodItemApi.getPage(
      page: _page,
      pageSize: _pageSize,
      categoryId: _categoryId,
      search: _searchController.text,
    );
  }

  void _applyFilters() {
    setState(() {
      _page = 1;
      _reloadFoods();
    });
  }

  void _goToPage(int page) {
    setState(() {
      _page = page;
      _reloadFoods();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý món ăn')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _applyFilters(),
                decoration: InputDecoration(
                  labelText: 'Tìm món ăn',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  suffixIcon: IconButton(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<AdminCategory>>(
                future: _categories,
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];
                  return DropdownButtonFormField<int?>(
                    value: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả danh mục'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<int?>(
                          value: category.categoryId,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _categoryId = value;
                        _page = 1;
                        _reloadFoods();
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<AdminFoodPage>(
            future: _foods,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const AppLoadingState();
              if (snapshot.hasError)
                return AppErrorState(onRetry: () => setState(_reloadFoods));
              final result = snapshot.data!;
              if (result.items.isEmpty)
                return const AppEmptyState(message: 'Không có món phù hợp.');
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: result.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _FoodItemTile(item: result.items[index]),
              );
            },
          ),
        ),
        FutureBuilder<AdminFoodPage>(
          future: _foods,
          builder: (context, snapshot) {
            final result = snapshot.data;
            if (result == null) return const SizedBox.shrink();
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${result.totalItems} món · Trang ${result.page}/${result.totalPages == 0 ? 1 : result.totalPages}',
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: result.page > 1
                              ? () => _goToPage(result.page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          onPressed: result.page < result.totalPages
                              ? () => _goToPage(result.page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _FoodItemTile extends StatelessWidget {
  final AdminFoodItem item;

  const _FoodItemTile({required this.item});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: FoodImage(imageUrl: item.imageUrl),
      title: Text(item.name),
      subtitle: Text('${item.categoryName} · ${formatVnd(item.price)} đ'),
      trailing: Text(
        item.isAvailable ? 'Đang bán' : 'Đã ẩn',
        style: TextStyle(
          color: item.isAvailable
              ? Colors.green
              : Theme.of(context).colorScheme.error,
        ),
      ),
    ),
  );
}
