import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/app/app_state.dart';
import 'package:rodzinna_lista_zakupow/data/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late List<Map<String, dynamic>> families;
  late List<Map<String, dynamic>> members;
  late HttpOverrides? previousHttpOverrides;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    families = [];
    members = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((request) => _handleRequest(request, families, members)),
    );
  });

  tearDown(() async {
    await server.close(force: true);
    HttpOverrides.global = previousHttpOverrides;
  });

  test('dołącza do prawdziwej rodziny z serwera po kodzie', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.updateServerUrl('http://127.0.0.1:${server.port}');
    await appState.joinFamily(code: 'ADMIN1', memberName: 'Tomek');

    expect(appState.hasFamily, isTrue);
    expect(appState.data.family?.id, 'family-admin');
    expect(appState.data.family?.code, 'ADMIN1');
    expect(appState.data.family?.createOnSync, isFalse);
    expect(appState.data.currentMember?.familyId, 'family-admin');
    expect(appState.data.currentMember?.syncStatus.name, 'synced');
    expect(members, hasLength(1));
    expect(members.single['family_id'], 'family-admin');
  });

  test('dolacza jako ten sam czlonek na drugim urzadzeniu', () async {
    members.add({
      'id': 'admin-member',
      'family_id': 'family-admin',
      'name': 'Tomek',
      'email': null,
      'phone': null,
      'avatar_url': null,
      'created_at': '2026-06-20T10:00:00.000Z',
      'updated_at': '2026-06-20T10:00:00.000Z',
      'created_by': 'admin-member',
      'is_deleted': false,
    });
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.updateServerUrl('http://127.0.0.1:${server.port}');
    await appState.joinFamily(code: 'ADMIN1', memberName: 'Tomek');

    expect(appState.data.currentMember?.id, 'admin-member');
    expect(appState.isFamilyCreator, isTrue);
    expect(members, hasLength(1));
  });

  test('nie tworzy lokalnej rodziny, gdy kod nie istnieje', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.updateServerUrl('http://127.0.0.1:${server.port}');

    expect(
      () => appState.joinFamily(code: 'BRAK12', memberName: 'Tomek'),
      throwsA(isA<AppActionException>()),
    );
    expect(appState.hasFamily, isFalse);
    expect(members, isEmpty);
  });

  test('zmiana serwera wymusza ponowna synchronizacje rodziny', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.updateServerUrl('http://127.0.0.1:${server.port}');
    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');

    expect(appState.data.family?.syncStatus.name, 'synced');
    expect(appState.data.members.single.syncStatus.name, 'synced');

    await appState.updateServerUrl('bez-serwera-test');

    expect(appState.data.family?.syncStatus.name, 'pending');
    expect(appState.data.family?.createOnSync, isTrue);
    expect(appState.data.members.single.syncStatus.name, 'pending');
  });
}

Future<void> _handleRequest(
  HttpRequest request,
  List<Map<String, dynamic>> families,
  List<Map<String, dynamic>> members,
) async {
  final path = request.uri.path;
  if (request.method == 'GET' && path == '/api/families/code/ADMIN1') {
    _sendJson(request, {
      'id': 'family-admin',
      'family_id': 'family-admin',
      'name': 'Rodzina Admina',
      'code': 'ADMIN1',
      'created_at': '2026-06-20T10:00:00.000Z',
      'updated_at': '2026-06-20T10:00:00.000Z',
      'created_by': 'admin-member',
      'is_deleted': false,
    });
    return;
  }

  if (request.method == 'GET' && path.startsWith('/api/families/code/')) {
    _sendJson(request, {'error': 'Nie znaleziono'}, statusCode: 404);
    return;
  }

  if (request.method == 'PUT' && path.startsWith('/api/families/')) {
    final body = await utf8.decoder.bind(request).join();
    final family = Map<String, dynamic>.from(jsonDecode(body) as Map);
    families.removeWhere((item) => item['id'] == family['id']);
    families.add(family);
    _sendJson(request, family);
    return;
  }

  if (request.method == 'PUT' && path.startsWith('/api/members/')) {
    final body = await utf8.decoder.bind(request).join();
    final member = Map<String, dynamic>.from(jsonDecode(body) as Map);
    members.removeWhere((item) => item['id'] == member['id']);
    members.add(member);
    _sendJson(request, member);
    return;
  }

  if (request.method == 'GET' && path == '/api/members') {
    final familyId = request.uri.queryParameters['familyId'];
    _sendJson(
      request,
      members.where((member) => member['family_id'] == familyId).toList(),
    );
    return;
  }

  if (request.method == 'GET' && path.startsWith('/api/')) {
    _sendJson(request, []);
    return;
  }

  _sendJson(request, {'error': 'Nieznana ścieżka'}, statusCode: 404);
}

void _sendJson(HttpRequest request, Object body, {int statusCode = 200}) {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  unawaited(request.response.close());
}
