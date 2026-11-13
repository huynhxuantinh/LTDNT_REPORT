import 'package:flutter/material.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/member_category_api.dart';

class HomeCategories extends StatefulWidget {
  const HomeCategories({super.key});

  @override
  State<HomeCategories> createState() => _HomeCategoriesState();
}

class _HomeCategoriesState extends State<HomeCategories> {
  late Future<List<MemberCategory>> _categories;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _categories = MemberCategoryApi.getAll();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MemberCategory>>(
    future: _categories,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AppLoadingState(message: 'Đang tải danh mục...');
      }
      if (snapshot.hasError) {
        return AppErrorState(onRetry: () => setState(_reload));
      }
      final categories = snapshot.data ?? [];
      if (categories.isEmpty) {
        return const AppEmptyState(message: 'Chưa có danh mục.');
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Danh mục món ăn',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...categories.map(
            (category) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.restaurant_menu)),
                title: Text(category.name),
                subtitle: category.description?.isNotEmpty == true
                    ? Text(category.description!)
                    : null,
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        ],
      );
    },
  );
}
