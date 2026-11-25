import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/category_api.dart';
import 'package:trek_bikes_app/food_item_api.dart';
import 'package:trek_bikes_app/food_image.dart';
import 'package:trek_bikes_app/money_format.dart';

/// Màn hình Quản lý món ăn (CHỈ DÀNH CHO ADMIN).
/// Cho phép tìm kiếm, lọc, phân trang, thêm món (kèm upload ảnh), sửa món và xóa/ẩn món.
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

  Future<void> _openEditor([AdminFoodItem? item]) async {
    List<AdminCategory> categories;
    try {
      categories = await _categories;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được danh sách danh mục.')),
        );
      }
      return;
    }

    if (categories.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng tạo danh mục trước khi thêm món.')),
        );
      }
      return;
    }

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _FoodItemEditorDialog(
        item: item,
        categories: categories,
      ),
    );

    if (saved == true && mounted) {
      setState(_reloadFoods);
    }
  }

  Future<void> _deleteItem(AdminFoodItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa món ăn'),
        content: Text('Bạn có chắc muốn xóa món "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FoodItemApi.delete(item.foodItemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa món ăn và hình ảnh.')),
        );
        setState(_reloadFoods);
      }
    } on FoodHasOrdersException catch (e) {
      if (!mounted) return;
      final shouldHide = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Món đã có trong đơn hàng'),
          content: Text(
            '${e.message}\n\nBạn có muốn ẨN món "${item.name}" khỏi thực đơn khách hàng không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ẩn món'),
            ),
          ],
        ),
      );
      if (shouldHide == true) {
        try {
          await FoodItemApi.hide(item.foodItemId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã ẩn món khỏi thực đơn.')),
            );
            setState(_reloadFoods);
          }
        } on ApiException catch (err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err.message)),
            );
          }
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể kết nối máy chủ.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý món ăn')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openEditor(),
      icon: const Icon(Icons.add),
      label: const Text('Thêm món'),
    ),
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
              if (snapshot.connectionState != ConnectionState.done) {
                return const AppLoadingState();
              }
              if (snapshot.hasError) {
                return AppErrorState(onRetry: () => setState(_reloadFoods));
              }
              final result = snapshot.data!;
              if (result.items.isEmpty) {
                return const AppEmptyState(message: 'Không có món phù hợp.');
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: result.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = result.items[index];
                  return _FoodItemTile(
                    item: item,
                    onEdit: () => _openEditor(item),
                    onDelete: () => _deleteItem(item),
                  );
                },
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FoodItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: FoodImage(imageUrl: item.imageUrl),
      title: Text(item.name),
      subtitle: Text(
        '${item.categoryName} · ${formatVnd(item.price)} đ · ${item.isAvailable ? 'Đang bán' : 'Đã ẩn'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Sửa món',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Xóa món',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    ),
  );
}

class _FoodItemEditorDialog extends StatefulWidget {
  final AdminFoodItem? item;
  final List<AdminCategory> categories;

  const _FoodItemEditorDialog({
    required this.item,
    required this.categories,
  });

  @override
  State<_FoodItemEditorDialog> createState() => _FoodItemEditorDialogState();
}

class _FoodItemEditorDialogState extends State<_FoodItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descController;
  late int _categoryId;
  Uint8List? _imageBytes;
  String? _imageName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(
      text: widget.item != null ? widget.item!.price.toStringAsFixed(0) : '',
    );
    _descController = TextEditingController(text: widget.item?.description ?? '');
    _categoryId = widget.item?.categoryId ?? widget.categories.first.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final file = files.first;
    final bytes = await file.xFile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.item == null && _imageBytes == null) {
      setState(() => _error = 'Vui lòng chọn hình ảnh cho món ăn mới.');
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = 'Giá món phải lớn hơn 0.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (widget.item == null) {
        await FoodItemApi.create(
          categoryId: _categoryId,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          price: price,
          imageBytes: _imageBytes!,
          imageName: _imageName!,
        );
      } else {
        await FoodItemApi.update(
          foodItemId: widget.item!.foodItemId,
          categoryId: _categoryId,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          price: price,
          imageBytes: _imageBytes,
          imageName: _imageName,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể lưu món ăn. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;
    return AlertDialog(
      title: Text(isNew ? 'Thêm món ăn' : 'Sửa món ăn'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: widget.categories
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: c.categoryId,
                        child: Text(c.name),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _categoryId = val);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên món *'),
                validator: (v) =>
                    v == null || v.trim().length < 2 ? 'Tối thiểu 2 ký tự' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá (VNĐ) *'),
                validator: (v) {
                  final p = double.tryParse((v ?? '').trim());
                  return p == null || p <= 0 ? 'Nhập giá hợp lệ > 0' : null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _imageName != null
                      ? 'Đã chọn: $_imageName'
                      : (isNew ? 'Chọn ảnh món *' : 'Đổi ảnh mới (tùy chọn)'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
        ),
      ],
    );
  }
}
