import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart' as sqlite;
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/local_database.dart';
import 'package:trek_bikes_app/member_category_api.dart';
import 'package:trek_bikes_app/member_food_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SQLite serves cached menu and sync retries an operation only once',
    () async {
      if (Platform.isWindows)
        sqlite.open.overrideFor(
          sqlite.OperatingSystem.windows,
          () => DynamicLibrary.open('winsqlite3.dll'),
        );
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final temp = await Directory.systemTemp.createTemp('food-offline-test-');
      await databaseFactory.setDatabasesPath(temp.path);
      final oldDb = await openDatabase('${temp.path}${Platform.pathSeparator}food_ordering.db', version: 1, onCreate: (db, _) async {
        await db.execute('CREATE TABLE cached_categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL, description TEXT, image_url TEXT, cached_at TEXT NOT NULL)');
        await db.execute('CREATE TABLE cached_food_items (id INTEGER PRIMARY KEY, category_id INTEGER NOT NULL, name TEXT NOT NULL, description TEXT, price REAL NOT NULL, image_url TEXT, cached_at TEXT NOT NULL)');
        await db.execute('CREATE TABLE local_cart_items (food_item_id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL NOT NULL, quantity INTEGER NOT NULL)');
        await db.insert('local_cart_items', {'food_item_id': 9, 'name': 'old', 'price': 1, 'quantity': 2});
      });
      await oldDb.close();
      dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
      FlutterSecureStorage.setMockInitialValues({
        'email': 'member@example.com',
        'access_token': 'token',
      });
      var offline = false;
      var loseResponse = false;
      var rejectSync = false;
      var quantity = 0;
      final applied = <String>{};
      final food = {
        'foodItemId': 1,
        'categoryId': 1,
        'categoryName': 'Món chính',
        'name': 'Cơm gà',
        'description': 'Ngon',
        'price': 30000,
        'imageUrl': null,
      };
      Map<String, dynamic> cart() => {
        'items': quantity == 0
            ? []
            : [
                {
                  'cartItemId': 100,
                  'foodItemId': 1,
                  'name': 'Cơm gà',
                  'unitPrice': 30000,
                  'quantity': quantity,
                },
              ],
        'totalQuantity': quantity,
        'totalAmount': 30000 * quantity,
      };
      final client = MockClient((request) async {
        if (offline) throw http.ClientException('network unavailable');
        final path = request.url.path;
        if (path == '/api/categories')
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {'categoryId': 1, 'name': 'Món chính'},
              ]),
            ),
            200,
          );
        if (path == '/api/foods')
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': [food],
                'meta': {'page': 1, 'totalItems': 1, 'totalPages': 1},
              }),
            ),
            200,
          );
        if (path == '/api/foods/1')
          return http.Response.bytes(utf8.encode(jsonEncode(food)), 200);
        if (path == '/api/cart/sync-item') {
          if (rejectSync)
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'error': {'message': 'Món ăn không còn bán.'},
                }),
              ),
              400,
            );
          final operation = jsonDecode(request.body) as Map<String, dynamic>;
          if (applied.add(operation['operationId'] as String)) {
            switch (operation['action']) {
              case 'add':
                quantity += operation['quantity'] as int;
              case 'set':
                quantity = operation['quantity'] as int;
              case 'remove':
                quantity = 0;
            }
          }
          if (loseResponse) {
            loseResponse = false;
            throw http.ClientException('response lost');
          }
          return http.Response.bytes(utf8.encode(jsonEncode(cart())), 200);
        }
        if (path == '/api/cart')
          return http.Response.bytes(utf8.encode(jsonEncode(cart())), 200);
        return http.Response('not found', 404);
      });
      await http.runWithClient(() async {
        expect(await (await LocalDatabase.instance.database).getVersion(), 2);
        expect((await LocalDatabase.instance.getLocalCartItems()).length, 1);
        expect((await MemberCategoryApi.getAll()).single.name, 'Món chính');
        expect(
          (await MemberFoodApi.getPage(
            page: 1,
            pageSize: 10,
          )).items.single.name,
          'Cơm gà',
        );
        await CartApi.get();
        offline = true;
        expect((await MemberCategoryApi.getAll()).single.name, 'Món chính');
        expect(
          (await MemberFoodApi.getPage(page: 1, pageSize: 10)).isOffline,
          isTrue,
        );
        expect((await MemberFoodApi.getById(1)).name, 'Cơm gà');
        final local = await CartApi.add(1);
        expect(local.isOffline, isTrue);
        expect(local.totalQuantity, 1);
        expect((await CartApi.get()).totalQuantity, 1);
        expect(
          (await LocalDatabase.instance.pendingCart('member@example.com'))
              .length,
          1,
        );
        offline = false;
        loseResponse = true;
        expect((await CartApi.get()).isOffline, isTrue);
        expect(quantity, 1);
        final restored = await CartApi.get();
        expect(restored.isOffline, isFalse);
        expect(restored.totalQuantity, 1);
        expect(applied.length, 1);
        expect(
          await LocalDatabase.instance.pendingCart('member@example.com'),
          isEmpty,
        );
        expect(
          await LocalDatabase.instance.readCart('other@example.com'),
          isNull,
        );
        offline = true;
        expect((await CartApi.setQuantity(100, 2)).totalQuantity, 2);
        expect((await CartApi.remove(100)).totalQuantity, 0);
        expect(
          (await LocalDatabase.instance.pendingCart('member@example.com'))
              .length,
          2,
        );
        FlutterSecureStorage.setMockInitialValues({
          'email': 'other@example.com',
          'access_token': 'other-token',
        });
        await expectLater(CartApi.get(), throwsA(isA<Exception>()));
        FlutterSecureStorage.setMockInitialValues({
          'email': 'member@example.com',
          'access_token': 'token',
        });
        offline = false;
        expect((await CartApi.get()).totalQuantity, 0);
        expect(
          await LocalDatabase.instance.pendingCart('member@example.com'),
          isEmpty,
        );
        offline = true;
        await CartApi.add(1);
        offline = false;
        rejectSync = true;
        final conflict = await CartApi.get();
        expect(conflict.isOffline, isTrue);
        expect(conflict.syncIssue, 'Món ăn không còn bán.');
        expect(
          (await LocalDatabase.instance.pendingCart('member@example.com'))
              .length,
          1,
        );
        expect((await CartApi.discardPendingChanges()).totalQuantity, 0);
        expect(
          await LocalDatabase.instance.pendingCart('member@example.com'),
          isEmpty,
        );
      }, () => client);
      await (await LocalDatabase.instance.database).close();
      await temp.delete(recursive: true);
    },
  );
}
