import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pitwall/core/webhook/delivery_status.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';
import 'package:pitwall/core/webhook/webhook_sender.dart';

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
    values: {'tucson_fli_vol': litres},
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
    expect(received.first['values'], {'tucson_fli_vol': 47.5});
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
    expect(
      pitwall.status.value.lastError,
      const DeliveryError(DeliveryErrorKind.serverError, statusCode: 500),
    );

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
    expect(pitwall.status.value.lastError?.kind, DeliveryErrorKind.noUrl);
    pitwall.dispose();
  });

  test('network errors keep only their kind', () async {
    final pitwall = sender(
      client: MockClient(
        (_) async =>
            throw http.ClientException('Failed host lookup', Uri.parse(_url)),
      ),
    );

    final result = await pitwall.sendTest(_target);

    // Only the kind is kept: the exception text, which names the URL, isn't.
    expect(result.error, const DeliveryError(DeliveryErrorKind.unreachable));
    pitwall.dispose();
  });

  test('a test send is marked as a test and not queued', () async {
    final pitwall = sender();
    await pitwall.init();

    expect((await pitwall.sendTest(_target)).succeeded, isTrue);

    expect(received.single['test'], isTrue);
    expect(pitwall.status.value.queued, 0);
    expect(storage.state.seq, 0);
    pitwall.dispose();
  });

  test('refused requests report the status code', () async {
    failNext = 1;
    final pitwall = sender(client: server(status: 401));

    expect(
      (await pitwall.sendTest(_target)).error,
      const DeliveryError(DeliveryErrorKind.refused, statusCode: 401),
    );
    pitwall.dispose();
  });

  test('errors only the user can fix are not retried', () async {
    for (final status in [401, 403, 404]) {
      storage = FakeDeliveryStorage();
      var requests = 0;
      final pitwall = sender(
        client: MockClient((_) async {
          requests++;
          return http.Response('', status);
        }),
      );
      await pitwall.init();

      await sendFuel(pitwall, 47.5);
      // Well past several backoff periods.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(requests, 1, reason: 'HTTP $status');
      expect(pitwall.status.value.queued, 1);
      pitwall.dispose();
    }
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
    expect(
      pitwall.status.value.lastError,
      const DeliveryError(
        DeliveryErrorKind.authIncomplete,
        authProblem: AuthProblem.missingToken,
      ),
    );
    pitwall.dispose();
  });

  test('the end-of-trip message never replaces the latest reading', () async {
    failNext = 1000;
    final pitwall = sender();
    await pitwall.init();

    await sendFuel(pitwall, 47.5);
    await pitwall.send(device: 'tucson', values: const {}, connected: false);

    final latest = pitwall.status.value.latest!;
    expect(latest.values, {'tucson_fli_vol': 47.5});
    expect(latest.delivered, isFalse);
    expect(pitwall.status.value.queued, 2);

    failNext = 0;
    await pitwall.flush();
    expect(pitwall.status.value.latest!.delivered, isTrue);
    expect(pitwall.status.value.latest!.values, {'tucson_fli_vol': 47.5});
    pitwall.dispose();
  });
}
