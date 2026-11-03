import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pitwall/core/webhook/delivery_status.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';
import 'package:pitwall/core/webhook/webhook_sender.dart';
import 'package:pitwall/core/webhook/webhook_target.dart';

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
    webhookTarget: () async => WebhookTarget(url ?? '', auth),
    client: client ?? server(),
    clock: () => DateTime.utc(2026, 10, 31, 19, 40),
    backoff: (_) => const Duration(milliseconds: 10),
  );

  /// Queues a reading and waits for the delivery it starts.
  Future<void> sendFuel(WebhookSender sender, double litres) async {
    await sender.queue(
      device: 'tucson',
      values: {'tucson_fli_vol': litres},
      connected: true,
    );
    await sender.flush();
  }

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
    expect(pitwall.status.value.outcome.lastSuccess, isNotNull);
    pitwall.dispose();
  });

  test('keeps readings while failing and retries them in order', () async {
    failNext = 2;
    final pitwall = sender();
    await pitwall.init();

    await sendFuel(pitwall, 47.5);
    expect(received, isEmpty);
    expect(pitwall.status.value.queued, 1);
    expect(pitwall.status.value.outcome.lastError, const Rejected(500));

    await sendFuel(pitwall, 47);
    // The retries succeed once the server recovers.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(received.map((p) => p['seq']), [1, 2]);
    expect(pitwall.status.value.queued, 0);
    expect(pitwall.status.value.outcome.lastError, isNull);
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
    expect(
      pitwall.status.value.outcome.lastError,
      const UnusableWebhook(NoWebhookUrl()),
    );
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
    expect(result.error, const Unreachable());
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

    expect((await pitwall.sendTest(_target)).error, const Rejected(401));
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

  test('failed attempts are counted once, and back off with each', () async {
    failNext = 3;
    final waits = <int>[];
    final pitwall = WebhookSender(
      storage: storage,
      webhookTarget: () async => _target,
      client: server(),
      clock: () => DateTime.utc(2026, 10, 31, 19, 40),
      backoff: (attempt) {
        waits.add(attempt);
        return const Duration(milliseconds: 5);
      },
    );
    await pitwall.init();

    await sendFuel(pitwall, 47.5);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Three failures, each backing off further, then a success.
    expect(waits, [0, 1, 2]);
    expect(pitwall.status.value.outcome.failedAttempts, 0);
    expect(received, hasLength(1));
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
    expect(
      pitwall.status.value.outcome.lastError,
      const UnusableWebhook(IncompleteWebhookAuth(AuthProblem.missingToken)),
    );
    pitwall.dispose();
  });

  test(
    'a queued reading is delivered once deliveredThrough reaches it',
    () async {
      failNext = 1000;
      final pitwall = sender();
      await pitwall.init();

      final first = await pitwall.queue(
        device: 'tucson',
        values: const {'tucson_fli_vol': 47.5},
        connected: true,
      );
      final second = await pitwall.queue(
        device: 'tucson',
        values: const {},
        connected: false,
      );
      await pitwall.flush();
      expect(pitwall.status.value.deliveredThrough, lessThan(first));
      expect(pitwall.status.value.queued, 2);

      failNext = 0;
      await pitwall.flush();
      expect(pitwall.status.value.deliveredThrough, second);
      expect(received.map((p) => p['seq']), [first, second]);
      pitwall.dispose();
    },
  );

  test('what was delivered survives a restart', () async {
    final first = sender();
    await first.init();
    await sendFuel(first, 47.5);
    failNext = 1000;
    await sendFuel(first, 47);
    first.dispose();

    final second = sender();
    await second.init();
    // Its first attempt, which fails too.
    await Future<void>.delayed(Duration.zero);
    expect(second.status.value.deliveredThrough, 1);
    expect(second.status.value.queued, 1);
    second.dispose();
  });

  test(
    'readings dropped from a full queue don\'t count as delivered',
    () async {
      failNext = 1000;
      final pitwall = sender();
      await pitwall.init();

      for (var i = 0; i <= WebhookSender.maxQueued; i++) {
        await pitwall.queue(
          device: 'tucson',
          values: const {},
          connected: true,
        );
      }

      expect(pitwall.status.value.queued, WebhookSender.maxQueued);
      expect(pitwall.status.value.deliveredThrough, 0);
      pitwall.dispose();
    },
  );

  test('queueing starts delivery without being asked', () async {
    final pitwall = sender();
    await pitwall.init();

    await pitwall.queue(device: 'tucson', values: const {}, connected: false);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(received.single['connected'], isFalse);
    pitwall.dispose();
  });

  test(
    'a reading dropped while another is posted isn\'t marked delivered',
    () async {
      // The first post answers when told to; the ones after it never do.
      final posted = Completer<http.Response>();
      var requests = 0;
      final pitwall = sender(
        client: MockClient(
          (request) => requests++ == 0
              ? posted.future
              : Completer<http.Response>().future,
        ),
      );
      await pitwall.init();
      for (var i = 0; i < WebhookSender.maxQueued; i++) {
        await pitwall.queue(
          device: 'tucson',
          values: const {},
          connected: true,
        );
      }

      // Reading 1 is being posted; one more pushes it out of the full queue.
      await pitwall.queue(device: 'tucson', values: const {}, connected: true);
      posted.complete(http.Response('', 200));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Only reading 1 went out: reading 2, never posted, is still queued.
      expect(pitwall.status.value.deliveredThrough, 1);
      expect(pitwall.status.value.queued, WebhookSender.maxQueued);
      pitwall.dispose();
    },
  );
}
