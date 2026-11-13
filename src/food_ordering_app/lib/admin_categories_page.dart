import 'package:flutter/material.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/category_api.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  late Future<List<AdminCategory>> _categories;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _categories = CategoryApi.getAll();

  Future<void> _edit([AdminCategory? category]) async {
    final nameController = TextEditingController(text: category?.name);
    final descriptionController = TextEditingController(
      text: category?.description,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _CategoryEditorDialog(
        title: category == null ? 'Thêm danh mục' : 'Sửa danh mục',
        nameController: nameController,
        descriptionController: descriptionController,
        onSave: () async {
          final name = nameController.text.trim();
          if (name.length < 2)
            throw const ApiException('Tên danh mục phải có ít nhất 2 ký tự.');
          if (category == null) {
            await CategoryApi.create(
              name: name,
              description: descriptionController.text.trim(),
            );
          } else {
            await CategoryApi.update(
              categoryId: category.categoryId,
              name: name,
              description: descriptionController.text.trim(),
            );
          }
        },
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (saved == true && mounted) setState(_reload);
  }

  Future<void> _delete(AdminCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa danh mục'),
        content: Text('Xóa "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await CategoryApi.delete(category.categoryId);
      if (mounted) setState(_reload);
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể kết nối máy chủ. Hãy thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý danh mục')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _edit,
      icon: const Icon(Icons.add),
      label: const Text('Thêm'),
    ),
    body: FutureBuilder<List<AdminCategory>>(
      future: _categories,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const AppLoadingState();
        if (snapshot.hasError)
          return AppErrorState(onRetry: () => setState(_reload));
        final categories = snapshot.data ?? [];
        if (categories.isEmpty)
          return const AppEmptyState(message: 'Chưa có danh mục.');
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                subtitle:
                    category.description == null ||
                        category.description!.isEmpty
                    ? null
                    : Text(category.description!),
                trailing: Wrap(
                  children: [
                    IconButton(
                      onPressed: () => _edit(category),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Sửa',
                    ),
                    IconButton(
                      onPressed: () => _delete(category),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Xóa',
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class _CategoryEditorDialog extends StatefulWidget {
  final String title;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final Future<void> Function() onSave;

  const _CategoryEditorDialog({
    required this.title,
    required this.nameController,
    required this.descriptionController,
    required this.onSave,
  });

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên danh mục'),
        ),
        TextField(
          controller: widget.descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Mô tả'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
      ),
    ],
  );
}
