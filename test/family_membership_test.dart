import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/app/app_state.dart';
import 'package:rodzinna_lista_zakupow/data/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('użytkownik może opuścić lokalną rodzinę', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    expect(appState.hasFamily, isTrue);

    await appState.leaveFamily();

    expect(appState.hasFamily, isFalse);
    expect(appState.data.family, isNull);
    expect(appState.data.currentMember, isNull);
  });

  test('twórca rodziny może wyrzucić członka', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    await appState.addCalendarMember(name: 'Mama');
    final removedMember = appState.data.activeMembers.firstWhere(
      (member) => member.name == 'Mama',
    );
    await appState.addCalendarEvent(
      date: DateTime(2026, 6, 22),
      title: 'Dentysta',
      notes: '',
      memberId: removedMember.id,
      isFamilyWide: false,
    );

    await appState.removeFamilyMember(removedMember);

    expect(appState.data.activeMembers.map((member) => member.name), ['Tomek']);
    expect(appState.calendarEventsForDate(DateTime(2026, 6, 22)), isEmpty);
    expect(
      appState.data.members
          .firstWhere((member) => member.id == removedMember.id)
          .isDeleted,
      isTrue,
    );
  });
}
