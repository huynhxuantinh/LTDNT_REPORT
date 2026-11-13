import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:trek_bikes_app/member_category_api.dart';
import 'package:trek_bikes_app/member_food_api.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();
  static const _version = 1;
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'food_ordering.db');
    return openDatabase(
      path,
      version: _version,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _create(Database db, int version) async {
    await db.execute(
      'CREATE TABLE cached_categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL, description TEXT, image_url TEXT, cached_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE cached_food_items (id INTEGER PRIMARY KEY, category_id INTEGER NOT NULL, name TEXT NOT NULL, description TEXT, price REAL NOT NULL, image_url TEXT, cached_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE local_cart_items (food_item_id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL NOT NULL, quantity INTEGER NOT NULL)',
    );
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) await _create(db, newVersion);
  }

  Future<void> cacheCategories(List<MemberCategory> values) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.delete('cached_categories');
      final batch = tx.batch(); final now = DateTime.now().toIso8601String();
      for (final value in values) batch.insert('cached_categories', {'id': value.categoryId, 'name': value.name, 'description': value.description, 'image_url': value.imageUrl, 'cached_at': now});
      await batch.commit(noResult: true);
    });
  }

  Future<void> cacheFoods(List<MemberFoodItem> values) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.delete('cached_food_items');
      final batch = tx.batch(); final now = DateTime.now().toIso8601String();
      for (final value in values) batch.insert('cached_food_items', {'id': value.foodItemId, 'category_id': value.categoryId, 'name': value.name, 'description': value.description, 'price': value.price, 'image_url': value.imageUrl, 'cached_at': now});
      await batch.commit(noResult: true);
    });
  }

  Future<void> saveLocalCartItem(MemberFoodItem food, int quantity) async {
    final db = await database;
    await db.insert('local_cart_items', {'food_item_id': food.foodItemId, 'name': food.name, 'price': food.price, 'quantity': quantity}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeLocalCartItem(int foodItemId) async =>
      (await database).delete('local_cart_items', where: 'food_item_id = ?', whereArgs: [foodItemId]);

  Future<List<Map<String, Object?>>> getLocalCartItems() async =>
      (await database).query('local_cart_items', orderBy: 'food_item_id');
}
