import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:food_ordering_app/app_states.dart';
import 'package:food_ordering_app/auth_api.dart';
import 'package:food_ordering_app/category_api.dart';
import 'package:food_ordering_app/food_image.dart';

typedef CategoryImage = ({Uint8List bytes, String name});

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key, this.pickImage});
  final Future<CategoryImage?> Function()? pickImage;

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

  void _reload() {
    _categories = CategoryApi.getAll();
  }

  Future<void> _edit([AdminCategory? category]) async {
    var current = category;
    var changed = false;
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
        imageUrl: category?.imageUrl,
        pickImage: widget.pickImage,
        onSave: (image, removeImage) async {
          final name = nameController.text.trim();
          if (name.length < 2)
            throw const ApiException('Tên danh mục phải có ít nhất 2 ký tự.');
          if (current == null) {
            current = await CategoryApi.create(
              name: name,
              description: descriptionController.text.trim(),
            );
          } else {
            current = await CategoryApi.update(
              categoryId: current!.categoryId,
              name: name,
              description: descriptionController.text.trim(),
            );
          }
          changed = true;
          try {
            if (image != null) {
              await CategoryApi.uploadImage(
                current!.categoryId,
                image.bytes,
                image.name,
              );
            } else if (removeImage && current!.imageUrl != null) {
              await CategoryApi.deleteImage(current!.categoryId);
            }
          } on ApiException catch (error) {
            throw ApiException(
              'Đã lưu thông tin danh mục nhưng chưa cập nhật ảnh: ${error.message}',
            );
          } on TimeoutException {
            throw const ApiException(
              'Ảnh có thể đã được cập nhật. Hãy kiểm tra lại danh mục trước khi thử lại.',
            );
          } catch (_) {
            throw const ApiException(
              'Đã lưu thông tin danh mục nhưng chưa cập nhật ảnh. Hãy thử lại.',
            );
          }
        },
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if ((saved == true || changed) && mounted) setState(_reload);
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  leading: FoodImage(imageUrl: category.imageUrl),
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
  final Future<void> Function(CategoryImage? image, bool removeImage) onSave;
  final String? imageUrl;
  final Future<CategoryImage?> Function()? pickImage;

  const _CategoryEditorDialog({
    required this.title,
    required this.nameController,
    required this.descriptionController,
    required this.onSave,
    this.imageUrl,
    this.pickImage,
  });

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  bool _saving = false;
  CategoryImage? _selectedImage;
  bool _removeImage = false;
  String? _error;

  Future<void> _pickImage() async {
    try {
      final CategoryImage? selected;
      if (widget.pickImage != null) {
        selected = await widget.pickImage!();
      } else {
        final files = await FilePicker.pickFiles(type: FileType.image);
        if (files.isEmpty) return;
        final file = files.first;
        if (await file.xFile.length() > 5 * 1024 * 1024)
          throw const ApiException('Ảnh không được vượt quá 5 MB.');
        selected = (bytes: await file.xFile.readAsBytes(), name: file.name);
      }
      if (!mounted || selected == null) return;
      final name = selected.name.toLowerCase();
      if (!(name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.png') ||
          name.endsWith('.webp'))) {
        throw const ApiException('Chỉ hỗ trợ ảnh JPEG, PNG hoặc WEBP.');
      }
      if (selected.bytes.isEmpty || selected.bytes.length > 5 * 1024 * 1024)
        throw const ApiException('Ảnh phải có dung lượng từ 1 byte đến 5 MB.');
      setState(() {
        _selectedImage = selected;
        _removeImage = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Không thể mở ảnh. Vui lòng chọn lại.');
    }
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_selectedImage, _removeImage);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on TimeoutException {
      if (mounted)
        setState(
          () => _error = 'Chưa xác nhận được kết quả. Hãy kiểm tra danh mục trước khi lưu lại.',
        );
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
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên danh mục'),
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _selectedImage!.bytes,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Text('Không thể xem trước ảnh.'),
              ),
            )
          else if (!_removeImage &&
              widget.imageUrl != null &&
              widget.imageUrl!.isNotEmpty)
            FoodImage(imageUrl: widget.imageUrl, size: 120)
          else
            const Text('Chưa có ảnh danh mục'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _selectedImage != null ||
                          (!_removeImage && widget.imageUrl != null)
                      ? 'Đổi ảnh'
                      : 'Chọn ảnh',
                ),
              ),
              if (_selectedImage != null ||
                  (!_removeImage &&
                      widget.imageUrl != null &&
                      widget.imageUrl!.isNotEmpty))
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _selectedImage = null;
                          _removeImage = true;
                        }),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xóa ảnh'),
                ),
            ],
          ),
          if (_selectedImage != null)
            Text(
              _selectedImage!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 12),
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
