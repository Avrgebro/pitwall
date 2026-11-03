import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';
import 'package:pitwall/core/webhook/webhook_target.dart';
import 'package:pitwall/state/webhook_state.dart';

import '../core/settings/fake_settings_store.dart';
import '../helpers/fakes.dart';

void main() {
  const working = WebhookTarget('https://example.com/api/webhook/abc');

  Future<(ProviderContainer, FakeSettingsStore)> start() async {
    final store = FakeSettingsStore()..webhook = working;
    final container = ProviderContainer(overrides: testOverrides(store: store));
    addTearDown(container.dispose);
    await container.read(webhookProvider.future);
    return (container, store);
  }

  test(
    'typing changes only the draft; saving keeps what can be used',
    () async {
      final (container, store) = await start();
      final webhook = container.read(webhookProvider.notifier);

      await webhook.editUrl('https://exa');
      expect(store.webhook, working);
      expect(container.read(webhookProvider).requireValue.saved, working);

      await webhook.editUrl('example.com/half');
      await webhook.save();
      // Not a usable URL, so the working one stays.
      final state = container.read(webhookProvider).requireValue;
      expect(
        state.draft.problem,
        const BadWebhookUrl(WebhookUrlProblem.incomplete),
      );
      expect(state.saved, working);
      expect(store.webhook, working);

      await webhook.editUrl('https://example.com/api/webhook/new');
      await webhook.save();
      expect(store.webhook.url, 'https://example.com/api/webhook/new');
    },
  );

  test('picking a kind of credentials applies; typing waits', () async {
    final (container, store) = await start();
    final webhook = container.read(webhookProvider.notifier);

    // A bearer token with nothing typed yet can't be used, so nothing saves.
    await webhook.editAuth(const WebhookAuth(type: WebhookAuthType.bearer));
    expect(store.webhook.auth, WebhookAuth.none);

    const auth = WebhookAuth(type: WebhookAuthType.bearer, token: 'abc');
    await webhook.editAuth(auth);
    expect(store.webhook.auth, WebhookAuth.none);
    await webhook.save();
    expect(store.webhook.auth, auth);

    await webhook.editAuth(WebhookAuth.none);
    expect(store.webhook.auth, WebhookAuth.none);
  });

  test('a test saves the draft, and an edit makes it stale', () async {
    final (container, store) = await start();
    final webhook = container.read(webhookProvider.notifier);

    await webhook.editUrl('https://example.com/api/webhook/typed');
    expect(container.read(webhookProvider).requireValue.canTest, isTrue);
    await webhook.sendTest();
    expect(store.webhook.url, 'https://example.com/api/webhook/typed');
    expect(container.read(webhookProvider).requireValue.lastTest, isNotNull);

    await webhook.editUrl('https://example.com/api/webhook/other');
    expect(container.read(webhookProvider).requireValue.lastTest, isNull);
  });

  test('an edit before the saved webhook loads doesn\'t erase it', () async {
    final store = FakeSettingsStore()
      ..webhook = const WebhookTarget(
        'https://example.com/api/webhook/abc',
        WebhookAuth(type: WebhookAuthType.bearer, token: 'secret'),
      );
    final container = ProviderContainer(overrides: testOverrides(store: store));
    addTearDown(container.dispose);
    final webhook = container.read(webhookProvider.notifier);

    // Straight away, before loading has finished.
    await webhook.editUrl('https://example.com/api/webhook/new');
    await webhook.save();

    expect(store.webhook.url, 'https://example.com/api/webhook/new');
    expect(store.webhook.auth.token, 'secret');
  });
}
