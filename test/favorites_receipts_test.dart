import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/app/app_state.dart';
import 'package:rodzinna_lista_zakupow/data/local_store.dart';
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
    await appState.addReceipt(
      storeName: 'Sklep',
      purchasedAt: DateTime(2026, 6, 20, 12),
      total: 9.99,
      imageData: 'abc123',
      imageMimeType: 'image/jpeg',
      items: const [
        ReceiptItem(name: 'Chleb', quantity: 1, unit: 'szt.', price: 4.99),
      ],
    );

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
}
