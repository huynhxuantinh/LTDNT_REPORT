import 'package:flutter/material.dart';
import 'package:food_ordering_app/food_image.dart';
import 'package:food_ordering_app/member_category_api.dart';

class HomeCategories extends StatefulWidget {
  const HomeCategories({super.key, required this.onSelected, this.selectedId});

  final ValueChanged<MemberCategory?> onSelected;
  final int? selectedId;

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

  void _reload() {
    _categories = MemberCategoryApi.getAll();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MemberCategory>>(
    future: _categories,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: TextButton.icon(
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại danh mục'),
          ),
        );
      }
      final categories = snapshot.data ?? [];
      if (categories.isEmpty) {
        return const Center(child: Text('Chưa có danh mục.'));
      }
      return ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: widget.selectedId == null,
              onSelected: (_) => widget.onSelected(null),
            ),
          ),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: category.imageUrl == null || category.imageUrl!.isEmpty
                    ? null
                    : FoodImage(imageUrl: category.imageUrl, size: 24),
                label: Text(category.name),
                selected: widget.selectedId == category.categoryId,
                onSelected: (_) => widget.onSelected(category),
              ),
            ),
          ),
        ],
      );
    },
  );
}
