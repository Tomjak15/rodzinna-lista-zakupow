import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/app/app_state.dart';
import 'package:rodzinna_lista_zakupow/data/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('produkt zapisuje i zmienia recznie wybrana kategorie', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    await appState.addShoppingItem(
      name: 'Platki kukurydziane',
      quantity: 1,
      unit: 'opak.',
      category: 'Sypkie i makarony',
    );

    var item = appState.data.activeShoppingItems.single;
    expect(item.category, 'Sypkie i makarony');
    expect(item.toJson()['category'], 'Sypkie i makarony');
    expect(item.toRemote()['category'], 'Sypkie i makarony');

    await appState.updateShoppingItem(
      item: item,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      category: 'Inne',
      updateCategory: true,
    );

    item = appState.data.activeShoppingItems.single;
    expect(item.category, 'Inne');

    await appState.updateShoppingItem(
      item: item,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      updateCategory: true,
    );

    expect(appState.data.activeShoppingItems.single.category, isNull);
  });
}
