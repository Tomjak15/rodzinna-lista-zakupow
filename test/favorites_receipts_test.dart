import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/app/app_state.dart';
import 'package:rodzinna_lista_zakupow/data/local_store.dart';
import 'package:rodzinna_lista_zakupow/data/sync_service.dart';
import 'package:rodzinna_lista_zakupow/models/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ulubiony produkt mozna dodac do listy zakupow', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    await appState.toggleFavoriteProduct(name: 'Mleko', quantity: 2, unit: 'l');

    expect(appState.data.activeFavoriteProducts, hasLength(1));
    expect(appState.isFavoriteProduct('mleko', 'l'), isTrue);

    await appState.addFavoriteProductToShoppingList(
      appState.data.activeFavoriteProducts.single,
    );

    final item = appState.data.activeShoppingItems.single;
    expect(item.name, 'Mleko');
    expect(item.quantity, 2);
    expect(item.unit, 'l');
  });

  test('paragon zapisuje produkty i dodaje je do listy', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    final receipt = await appState.addReceipt(
      storeName: 'Sklep',
      purchasedAt: DateTime(2026, 6, 20, 12),
      total: 9.99,
      imageData: 'abc123',
      imageMimeType: 'image/jpeg',
      items: const [
        ReceiptItem(name: 'Chleb', quantity: 1, unit: 'szt.', price: 4.99),
      ],
    );

    expect(receipt?.storeName, 'Sklep');
    expect(receipt?.total, 9.99);
    expect(appState.data.activeReceipts, hasLength(1));
    expect(appState.data.activeReceipts.single.rawText, isEmpty);
    expect(appState.data.activeReceipts.single.imageData, 'abc123');
    expect(
      appState.data.activeReceipts.single.toRemote()['image_mime_type'],
      'image/jpeg',
    );

    await appState.addReceiptItemsToShoppingList(
      appState.data.activeReceipts.single,
    );

    expect(appState.data.activeShoppingItems.single.name, 'Chleb');
  });

  test('paragon pozwala pominac produkty przy dodawaniu do listy', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    await appState.addReceipt(
      storeName: 'Sklep',
      purchasedAt: DateTime(2026, 6, 20, 12),
      total: 12,
      items: const [
        ReceiptItem(name: 'Chleb', quantity: 1, unit: 'szt.', price: 5),
        ReceiptItem(name: 'Mleko', quantity: 1, unit: 'l', price: 7),
      ],
    );

    final added = await appState.addReceiptItemsToShoppingList(
      appState.data.activeReceipts.single,
      excludedIndexes: {1},
    );

    expect(added, 1);
    expect(appState.data.activeShoppingItems, hasLength(1));
    expect(appState.data.activeShoppingItems.single.name, 'Chleb');
  });

  test('synchronizacja nie usuwa lokalnego zdjecia paragonu', () async {
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousHttpOverrides);

    final now = DateTime.utc(2026, 6, 28, 12);
    final remoteUpdatedAt = now.add(const Duration(minutes: 1));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(
      server.forEach((request) async {
        if (request.method == 'GET' && request.uri.path == '/api/receipts') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode([
                {
                  'id': 'receipt-1',
                  'family_id': 'family-1',
                  'store_name': 'Sklep',
                  'purchased_at': now.toIso8601String(),
                  'total': 9.99,
                  'raw_text': '',
                  'image_data': null,
                  'image_mime_type': null,
                  'items_json': jsonEncode([
                    {
                      'name': 'Chleb',
                      'quantity': 1,
                      'unit': 'szt.',
                      'price': 4.99,
                    },
                  ]),
                  'created_at': now.toIso8601String(),
                  'updated_at': remoteUpdatedAt.toIso8601String(),
                  'created_by': 'member-1',
                  'is_deleted': false,
                },
              ]),
            );
          await request.response.close();
          return;
        }
        if (request.method == 'GET' && request.uri.path.startsWith('/api/')) {
          request.response
            ..headers.contentType = ContentType.json
            ..write('[]');
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
      }),
    );

    final family = Family(
      id: 'family-1',
      familyId: 'family-1',
      name: 'Dom',
      code: 'DOM123',
      createdAt: now,
      updatedAt: now,
      createdBy: 'member-1',
      isDeleted: false,
      syncStatus: SyncStatus.synced,
      createOnSync: false,
    );
    final member = Member(
      id: 'member-1',
      familyId: 'family-1',
      name: 'Tomek',
      email: null,
      phone: null,
      avatar: null,
      createdAt: now,
      updatedAt: now,
      createdBy: 'member-1',
      isDeleted: false,
      syncStatus: SyncStatus.synced,
    );
    final receipt = Receipt(
      id: 'receipt-1',
      familyId: 'family-1',
      storeName: 'Sklep',
      purchasedAt: now,
      total: 9.99,
      rawText: '',
      imageData: 'lokalne-zdjecie',
      imageMimeType: 'image/jpeg',
      items: const [
        ReceiptItem(name: 'Chleb', quantity: 1, unit: 'szt.', price: 4.99),
      ],
      createdAt: now,
      updatedAt: now,
      createdBy: 'member-1',
      isDeleted: false,
      syncStatus: SyncStatus.synced,
    );
    final data = AppData.empty().copyWith(
      family: family,
      currentMember: member,
      members: [member],
      receipts: [receipt],
    );
    final syncService = SyncService('http://127.0.0.1:${server.port}');
    addTearDown(syncService.dispose);

    final synced = await syncService.sync(data);

    expect(synced.receipts.single.imageData, 'lokalne-zdjecie');
    expect(synced.receipts.single.imageMimeType, 'image/jpeg');
    expect(synced.receipts.single.syncStatus, SyncStatus.pending);
  });
}
