import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/webhook/delivery_status.dart';
import '../core/webhook/webhook_auth.dart';
import '../core/webhook/webhook_target.dart';
import 'infrastructure.dart';

/// The webhook as saved, as being edited, and its last test.
@immutable
class WebhookSettings {
  const WebhookSettings({
    this.saved = WebhookTarget.none,
    WebhookTarget? draft,
    this.lastTest,
  }) : draft = draft ?? saved;

  /// What readings are sent to.
  final WebhookTarget saved;

  /// What the form shows. A part that can't be used yet, such as a
  /// half-typed URL or token, stays here unsaved, so it never replaces a
  /// working one.
  final WebhookTarget draft;

  /// The last test send, of [saved]. Any edit clears it.
  final ({TestResult result, DateTime at})? lastTest;

  bool get hasUrl => saved.hasUrl;

  /// Only what's saved is tested, so the result says what readings get.
  bool get canTest => draft == saved && saved.isUsable;

  bool get testPassed => lastTest?.result.succeeded ?? false;
}

final webhookProvider = AsyncNotifierProvider<WebhookNotifier, WebhookSettings>(
  WebhookNotifier.new,
);

class WebhookNotifier extends AsyncNotifier<WebhookSettings> {
  @override
  Future<WebhookSettings> build() async => WebhookSettings(
    saved: await ref.read(settingsStoreProvider).loadWebhook(),
  );

  WebhookSettings get _current => state.value ?? const WebhookSettings();

  /// Edits the URL; it's saved once valid, or empty to remove it.
  Future<void> editUrl(String text) async {
    final current = _current;
    final draft = current.draft.copyWith(url: text.trim());
    await _edit(
      draft: draft,
      saved: draft.urlProblem == null
          ? current.saved.copyWith(url: draft.url)
          : current.saved,
    );
  }

  /// Edits the credentials; they're saved once usable.
  Future<void> editAuth(WebhookAuth auth) async {
    final current = _current;
    await _edit(
      draft: current.draft.copyWith(auth: auth),
      saved: auth.problem == null
          ? current.saved.copyWith(auth: auth)
          : current.saved,
    );
  }

  /// Sends a test reading to the saved webhook.
  Future<void> sendTest() async {
    final tested = _current;
    if (!tested.canTest) return;
    final result = await ref.read(webhookSenderProvider).sendTest(tested.saved);
    // An edit while it was on its way makes the result stale.
    if (_current.saved != tested.saved) return;
    state = AsyncData(
      WebhookSettings(
        saved: tested.saved,
        draft: _current.draft,
        lastTest: (result: result, at: DateTime.now()),
      ),
    );
  }

  Future<void> _edit({
    required WebhookTarget draft,
    required WebhookTarget saved,
  }) async {
    final changed = saved != _current.saved;
    state = AsyncData(WebhookSettings(saved: saved, draft: draft));
    if (!changed) return;
    await ref.read(settingsStoreProvider).saveWebhook(saved);
    // A fixed URL or token should deliver what's queued without waiting
    // for the next retry; the edit doesn't wait for it.
    unawaited(ref.read(webhookSenderProvider).flush());
  }
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
