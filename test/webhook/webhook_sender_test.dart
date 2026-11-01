import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pitwall/webhook/webhook_auth.dart';
import 'package:pitwall/webhook/webhook_sender.dart';

import 'fake_delivery_storage.dart';

const _url = 'https://example.com/api/webhook/secret-id';
const _target = WebhookTarget(_url);

void main() {
  late FakeDeliveryStorage storage;
  late List<Map<String, Object?>> received;
  late int failNext;

  /// A server that records each body, failing the next [failNext] requests.
  MockClient server({int status = 500}) => MockClient((request) async {
    if (failNext > 0) {
      failNext--;
      return http.Response('', status);
    }
    received.add(jsonDecode(request.body) as Map<String, Object?>);
    return http.Response('', 200);
  });

  WebhookSender sender({
    http.Client? client,
    String? url = _url,
    WebhookAuth auth = WebhookAuth.none,
  }) => WebhookSender(
    storage: storage,
    webhookTarget: () async => url == null ? null : WebhookTarget(url, auth),
    client: client ?? server(),
    clock: () => DateTime.utc(2026, 10, 31, 19, 40),
    backoff: (_) => const Duration(milliseconds: 10),
  );

  Future<void> sendFuel(WebhookSender sender, double litres) => sender.send(
    device: 'tucson',
    values: {'fuel_level_l': litres},
    connected: true,
  );

  setUp(() {
    storage = FakeDeliveryStorage();
    received = [];
    failNext = 0;
  });

  test('delivers readings with increasing sequence numbers', () async {
    final pitwall = sender();
    await pitwall.init();

    await sendFuel(pitwall, 47.5);
    await sendFuel(pitwall, 47);

    expect(received.map((p) => p['seq']), [1, 2]);
    expect(received.first['device'], 'tucson');
    expect(received.first['values'], {'fuel_level_l': 47.5});
    expect(pitwall.status.value.queued, 0);
    expect(pitwall.status.value.lastSuccess, isNotNull);
    pitwall.dispose();
  });

  test('keeps readings while failing and retries them in order', () async {
    failNext = 2;
    final pitwall = sender();
    await pitwall.init();

    await sendFuel(pitwall, 47.5);
    expect(received, isEmpty);
    expect(pitwall.status.value.queued, 1);
    expect(pitwall.status.value.lastError, contains('HTTP 500'));

    await sendFuel(pitwall, 47);
    // The retries succeed once the server recovers.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(received.map((p) => p['seq']), [1, 2]);
    expect(pitwall.status.value.queued, 0);
    expect(pitwall.status.value.lastError, isNull);
    pitwall.dispose();
  });

  test('a restart resumes the queue and the sequence', () async {
    failNext = 1000;
    final first = sender();
    await first.init();
    await sendFuel(first, 47.5);
    first.dispose();
    expect(storage.state.queue, hasLength(1));

    failNext = 0;
    final second = sender();
    await second.init();
    await Future<void>.delayed(Duration.zero);
    await sendFuel(second, 47);

    expect(received.map((p) => p['seq']), [1, 2]);
    second.dispose();
  });

  test('without a URL, readings wait in the queue', () async {
    final pitwall = sender(url: null);
    await pitwall.init();

    await sendFuel(pitwall, 47.5);

    expect(received, isEmpty);
    expect(pitwall.status.value.queued, 1);
    expect(pitwall.status.value.lastError, 'No webhook URL is set.');
    pitwall.dispose();
  });

  test('error messages never include the URL', () async {
    final pitwall = sender(
      client: MockClient(
        (_) async =>
            throw http.ClientException('Failed host lookup', Uri.parse(_url)),
      ),
    );

    final error = await pitwall.sendTest(_target);

    expect(error, isNotNull);
    expect(error, isNot(contains('secret-id')));
    pitwall.dispose();
  });

  test('a test send is marked as a test and not queued', () async {
    final pitwall = sender();
    await pitwall.init();

    expect(await pitwall.sendTest(_target), isNull);

    expect(received.single['test'], isTrue);
    expect(pitwall.status.value.queued, 0);
    expect(storage.state.seq, 0);
    pitwall.dispose();
  });

  test('refused requests get a hint to check the URL', () async {
    failNext = 1;
    final pitwall = sender(client: server(status: 401));

    expect(await pitwall.sendTest(_target), contains('Check the URL'));
    pitwall.dispose();
  });

  test('credentials are sent as headers on every request', () async {
    final headers = <Map<String, String>>[];
    final pitwall = sender(
      auth: const WebhookAuth(type: WebhookAuthType.bearer, token: 'abc123'),
      client: MockClient((request) async {
        headers.add(request.headers);
        return http.Response('', 200);
      }),
    );
    await pitwall.init();

    await sendFuel(pitwall, 47.5);

    expect(headers.single['Authorization'], 'Bearer abc123');
    expect(headers.single['Content-Type'], startsWith('application/json'));
    pitwall.dispose();
  });

  test('unusable credentials keep readings queued', () async {
    final pitwall = sender(
      auth: const WebhookAuth(type: WebhookAuthType.bearer),
    );
    await pitwall.init();

    await sendFuel(pitwall, 47.5);

    expect(received, isEmpty);
    expect(pitwall.status.value.queued, 1);
    expect(pitwall.status.value.lastError, contains('Enter the token'));
    pitwall.dispose();
  });
}
