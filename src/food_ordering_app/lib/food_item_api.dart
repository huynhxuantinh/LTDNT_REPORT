import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/session_helper.dart';

class AdminFoodItem {
  final int foodItemId;
  final int categoryId;
  final String categoryName;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final DateTime createdAt;

  const AdminFoodItem({
    required this.foodItemId,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.createdAt,
  });

  factory AdminFoodItem.fromJson(Map<String, dynamic> json) => AdminFoodItem(
    foodItemId: json['foodItemId'] as int,
    categoryId: json['categoryId'] as int,
    categoryName: json['categoryName'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    price: (json['price'] as num).toDouble(),
    imageUrl: json['imageUrl'] as String?,
    isAvailable: json['isAvailable'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class AdminFoodPage {
  final List<AdminFoodItem> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  const AdminFoodPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  factory AdminFoodPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return AdminFoodPage(
      items: (json['data'] as List<dynamic>)
          .map((item) => AdminFoodItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: meta['page'] as int,
      pageSize: meta['pageSize'] as int,
      totalItems: meta['totalItems'] as int,
      totalPages: meta['totalPages'] as int,
    );
  }
}

class FoodHasOrdersException implements Exception {
  final String message;
  const FoodHasOrdersException(this.message);
}

class FoodPhoto {
  const FoodPhoto({
    required this.imageId,
    required this.imageUrl,
    required this.isCover,
  });
  final int? imageId;
  final String imageUrl;
  final bool isCover;

  factory FoodPhoto.fromJson(Map<String, dynamic> json) => FoodPhoto(
    imageId: json['imageId'] as int?,
    imageUrl: json['imageUrl'] as String,
    isCover: json['isCover'] as bool,
  );
}

class FoodItemApi {
  static String get _baseUrl => ApiConfig.baseUrl;

  static Future<List<FoodPhoto>> getImages(int foodItemId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/admin/food-items/$foodItemId/images'),
      headers: await _headers(),
    );
    _ensure(response, 200);
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
        .map((value) => FoodPhoto.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  static Future<FoodPhoto> addImage(
    int foodItemId,
    Uint8List bytes,
    String name,
  ) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/api/admin/food-items/$foodItemId/images'),
          )
          ..headers.addAll(await _headers())
          ..files.add(_imagePart(bytes, name));
    final response = await http.Response.fromStream(await request.send());
    _ensure(response, 200);
    return FoodPhoto.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<void> deleteImage(int foodItemId, FoodPhoto photo) async {
    final part = photo.isCover ? 'cover' : '${photo.imageId}';
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/admin/food-items/$foodItemId/images/$part'),
      headers: await _headers(),
    );
    _ensure(response, 204);
  }

  static Future<AdminFoodPage> getPage({
    required int page,
    required int pageSize,
    int? categoryId,
    String? search,
  }) async {
    final query = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
    if (categoryId != null) query['categoryId'] = '$categoryId';
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    final response = await http.get(
      Uri.parse('$_baseUrl/api/admin/food-items')
          .replace(queryParameters: query),
      headers: await _headers(),
    );
    _ensure(response, 200);
    return AdminFoodPage.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// Thêm món ăn mới (Admin) kèm upload file ảnh
  static Future<AdminFoodItem> create({
    required int categoryId,
    required String name,
    String? description,
    required double price,
    required Uint8List imageBytes,
    required String imageName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/admin/food-items'),
    );
    request.headers.addAll(await _headers());
    request.fields['CategoryId'] = '$categoryId';
    request.fields['Name'] = name.trim();
    if (description != null && description.trim().isNotEmpty) {
      request.fields['Description'] = description.trim();
    }
    request.fields['Price'] = price.toStringAsFixed(2);
    request.files.add(_imagePart(imageBytes, imageName));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensure(response, 201);
    return AdminFoodItem.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// Cập nhật món ăn (Admin), chỉ gửi Image nếu có chọn ảnh mới
  static Future<AdminFoodItem> update({
    required int foodItemId,
    required int categoryId,
    required String name,
    String? description,
    required double price,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl/api/admin/food-items/$foodItemId'),
    );
    request.headers.addAll(await _headers());
    request.fields['CategoryId'] = '$categoryId';
    request.fields['Name'] = name.trim();
    if (description != null && description.trim().isNotEmpty) {
      request.fields['Description'] = description.trim();
    }
    request.fields['Price'] = price.toStringAsFixed(2);
    if (imageBytes != null && imageName != null) {
      request.files.add(_imagePart(imageBytes, imageName));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensure(response, 200);
    return AdminFoodItem.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// Xóa cứng món ăn (nếu chưa có trong đơn hàng).
  /// Nếu đã có trong đơn hàng sẽ ném FoodHasOrdersException để UI hỏi ẩn món.
  static Future<void> delete(int foodItemId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/admin/food-items/$foodItemId'),
      headers: await _headers(),
    );
    if (response.statusCode == 204) return;
    if (response.statusCode == 409) {
      try {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final error = json['error'] as Map<String, dynamic>?;
        if ([
          'food_has_order_details',
          'food_in_carts',
          'food_in_use',
        ].contains(error?['code'])) {
          throw FoodHasOrdersException(
            error?['message'] as String? ??
                'Không thể xóa món đã có trong đơn hàng.',
          );
        }
      } on FormatException {
        // Fallback below
      }
    }
    _ensure(response, 204);
  }

  /// Ẩn món ăn (xóa mềm) khi món đã tồn tại trong đơn hàng cũ
  static Future<void> hide(int foodItemId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/admin/food-items/$foodItemId/hide'),
      headers: await _headers(),
    );
    _ensure(response, 200);
  }

  static Future<void> restore(int foodItemId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/admin/food-items/$foodItemId/restore'),
      headers: await _headers(),
    );
    _ensure(response, 200);
  }

  static http.MultipartFile _imagePart(Uint8List bytes, String fileName) {
    final lower = fileName.toLowerCase();
    final MediaType? contentType;
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      contentType = MediaType('image', 'jpeg');
    } else if (lower.endsWith('.png')) {
      contentType = MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      contentType = MediaType('image', 'webp');
    } else {
      contentType = null;
    }
    return http.MultipartFile.fromBytes(
      'Image',
      bytes,
      filename: fileName,
      contentType: contentType,
    );
  }

  static Future<Map<String, String>> _headers() async {
    final accessToken = await SessionHelper.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException('Phiên đăng nhập đã hết hạn.');
    }
    return {'Authorization': 'Bearer $accessToken'};
  }

  static void _ensure(http.Response response, int expected) {
    if (response.statusCode == expected) return;
    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      throw ApiException(error?['message'] as String? ?? 'Có lỗi xảy ra.');
    } on FormatException {
      throw const ApiException('Không thể kết nối đến máy chủ.');
    }
  }
}
