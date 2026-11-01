import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings.dart';
import '../core/webhook/delivery_status.dart';
import '../core/webhook/webhook_auth.dart';
import 'infrastructure.dart';

/// The saved webhook URL and credentials.
@immutable
class WebhookConfig {
  const WebhookConfig({this.url = '', this.auth = WebhookAuth.none});

  final String url;
  final WebhookAuth auth;

  bool get hasUrl => url.isNotEmpty;
}

final webhookConfigProvider =
    AsyncNotifierProvider<WebhookConfigNotifier, WebhookConfig>(
      WebhookConfigNotifier.new,
    );

class WebhookConfigNotifier extends AsyncNotifier<WebhookConfig> {
  @override
  Future<WebhookConfig> build() async {
    final store = ref.read(settingsStoreProvider);
    return WebhookConfig(
      url: await store.loadWebhookUrl() ?? '',
      auth: await store.loadWebhookAuth(),
    );
  }

  WebhookConfig get _current => state.value ?? const WebhookConfig();

  /// Saves [url] if it's valid or empty; returns why not otherwise.
  Future<WebhookUrlProblem?> setUrl(String url) async {
    final trimmed = url.trim();
    final problem = trimmed.isEmpty ? null : validateWebhookUrl(trimmed);
    if (problem != null) return problem;
    await ref.read(settingsStoreProvider).saveWebhookUrl(trimmed);
    state = AsyncData(WebhookConfig(url: trimmed, auth: _current.auth));
    _resumeDelivery();
    return null;
  }

  /// Saves [auth] if it's usable; returns why not otherwise. A half-typed
  /// token never replaces a working one.
  Future<AuthProblem?> setAuth(WebhookAuth auth) async {
    if (auth.problem case final problem?) return problem;
    await ref.read(settingsStoreProvider).saveWebhookAuth(auth);
    state = AsyncData(WebhookConfig(url: _current.url, auth: auth));
    _resumeDelivery();
    return null;
  }

  /// Sends a test reading to [url] with [auth], without saving either.
  Future<TestResult> sendTest(String url, WebhookAuth auth) =>
      ref.read(webhookSenderProvider).sendTest(WebhookTarget(url.trim(), auth));

  // A fixed URL or token should deliver what's queued without waiting for
  // the next retry.
  void _resumeDelivery() => ref.read(webhookSenderProvider).flush();
}

/// How delivery is going, updated as the sender works.
final deliveryStatusProvider =
    NotifierProvider<DeliveryStatusNotifier, DeliveryStatus>(
      DeliveryStatusNotifier.new,
    );

class DeliveryStatusNotifier extends Notifier<DeliveryStatus> {
  @override
  DeliveryStatus build() {
    final status = ref.watch(webhookSenderProvider).status;
    void update() => state = status.value;
    status.addListener(update);
    ref.onDispose(() => status.removeListener(update));
    return status.value;
  }

  /// Tries to deliver queued readings now instead of at the next retry.
  Future<void> retryNow() => ref.read(webhookSenderProvider).flush();
}
