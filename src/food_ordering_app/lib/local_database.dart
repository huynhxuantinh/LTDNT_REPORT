import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:trek_bikes_app/member_category_api.dart';
import 'package:trek_bikes_app/member_food_api.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();
  static const _version = 2;
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
    await _createV2(db);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createV2(db);
  }

  Future<void> _createV2(Database db) async {
    await db.execute(
      'CREATE TABLE cached_responses (cache_key TEXT PRIMARY KEY, body TEXT NOT NULL, cached_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE cart_snapshots (account TEXT PRIMARY KEY, body TEXT NOT NULL, cached_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE cart_pending (sequence INTEGER PRIMARY KEY AUTOINCREMENT, account TEXT NOT NULL, operation_id TEXT NOT NULL UNIQUE, food_id INTEGER NOT NULL, action TEXT NOT NULL, quantity INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE INDEX idx_cart_pending_account ON cart_pending(account, sequence)',
    );
  }

  Future<void> saveResponse(String key, Object value) async {
    final db = await database;
    await db.insert('cached_responses', {
      'cache_key': key,
      'body': jsonEncode(value),
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<dynamic> readResponse(String key) async {
    final db = await database;
    final rows = await db.query(
      'cached_responses',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : jsonDecode(rows.first['body'] as String);
  }

  Future<Map<String, dynamic>?> readCart(String account) async {
    final db = await database;
    final rows = await db.query(
      'cart_snapshots',
      where: 'account = ?',
      whereArgs: [account],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['body'] as String) as Map<String, dynamic>;
  }

  Future<void> saveCart(String account, Map<String, dynamic> cart) async {
    final db = await database;
    await db.insert('cart_snapshots', {
      'account': account,
      'body': jsonEncode(cart),
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> pendingCart(String account) async =>
      (await database).query(
        'cart_pending',
        where: 'account = ?',
        whereArgs: [account],
        orderBy: 'sequence',
      );

  Future<void> queueCart(
    String account,
    String operationId,
    int foodId,
    String action,
    int quantity,
    Map<String, dynamic> snapshot,
  ) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.insert('cart_pending', {
        'account': account,
        'operation_id': operationId,
        'food_id': foodId,
        'action': action,
        'quantity': quantity,
      });
      await tx.insert('cart_snapshots', {
        'account': account,
        'body': jsonEncode(snapshot),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> acknowledgeCart(
    String account,
    String operationId,
    Map<String, dynamic> serverCart,
  ) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.delete(
        'cart_pending',
        where: 'account = ? AND operation_id = ?',
        whereArgs: [account, operationId],
      );
      final left =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT COUNT(*) FROM cart_pending WHERE account = ?',
              [account],
            ),
          ) ??
          0;
      if (left == 0)
        await tx.insert('cart_snapshots', {
          'account': account,
          'body': jsonEncode(serverCart),
          'cached_at': DateTime.now().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> discardPendingCart(
    String account,
    Map<String, dynamic> serverCart,
  ) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.delete(
        'cart_pending',
        where: 'account = ?',
        whereArgs: [account],
      );
      await tx.insert('cart_snapshots', {
        'account': account,
        'body': jsonEncode(serverCart),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> cacheCategories(List<MemberCategory> values) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.delete('cached_categories');
      final batch = tx.batch();
      final now = DateTime.now().toIso8601String();
      for (final value in values)
        batch.insert('cached_categories', {
          'id': value.categoryId,
          'name': value.name,
          'description': value.description,
          'image_url': value.imageUrl,
          'cached_at': now,
        });
      await batch.commit(noResult: true);
    });
  }

  Future<void> cacheFoods(List<MemberFoodItem> values) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.delete('cached_food_items');
      final batch = tx.batch();
      final now = DateTime.now().toIso8601String();
      for (final value in values)
        batch.insert('cached_food_items', {
          'id': value.foodItemId,
          'category_id': value.categoryId,
          'name': value.name,
          'description': value.description,
          'price': value.price,
          'image_url': value.imageUrl,
          'cached_at': now,
        });
      await batch.commit(noResult: true);
    });
  }

  Future<void> saveLocalCartItem(MemberFoodItem food, int quantity) async {
    final db = await database;
    await db.insert('local_cart_items', {
      'food_item_id': food.foodItemId,
      'name': food.name,
      'price': food.price,
      'quantity': quantity,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeLocalCartItem(int foodItemId) async =>
      (await database).delete(
        'local_cart_items',
        where: 'food_item_id = ?',
        whereArgs: [foodItemId],
      );

  Future<List<Map<String, Object?>>> getLocalCartItems() async =>
      (await database).query('local_cart_items', orderBy: 'food_item_id');
}
