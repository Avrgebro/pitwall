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

  test('a half-typed URL is shown but never replaces a working one', () async {
    final (container, store) = await start();
    final webhook = container.read(webhookProvider.notifier);

    await webhook.editUrl('https://exa');
    await webhook.editUrl('example.com/half');

    final state = container.read(webhookProvider).requireValue;
    expect(state.draft.url, 'example.com/half');
    expect(state.draft.urlProblem, WebhookUrlProblem.incomplete);
    expect(state.saved.url, 'https://exa');
    expect(store.webhook.url, 'https://exa');
    expect(state.canTest, isFalse);
  });

  test('incomplete credentials wait in the draft', () async {
    final (container, store) = await start();
    final webhook = container.read(webhookProvider.notifier);

    await webhook.editAuth(const WebhookAuth(type: WebhookAuthType.bearer));
    expect(store.webhook.auth, WebhookAuth.none);

    const auth = WebhookAuth(type: WebhookAuthType.bearer, token: 'abc');
    await webhook.editAuth(auth);
    expect(store.webhook.auth, auth);
    expect(container.read(webhookProvider).requireValue.canTest, isTrue);
  });

  test('the test result belongs to what was tested', () async {
    final (container, _) = await start();
    final webhook = container.read(webhookProvider.notifier);

    await webhook.sendTest();
    expect(container.read(webhookProvider).requireValue.lastTest, isNotNull);

    await webhook.editUrl('https://example.com/api/webhook/other');
    expect(container.read(webhookProvider).requireValue.lastTest, isNull);
  });
}
