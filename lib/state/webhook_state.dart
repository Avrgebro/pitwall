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

  /// What the form shows. Typing changes only this; [WebhookNotifier.save]
  /// keeps the parts that can be used, so a half-typed URL or token never
  /// replaces a working one or receives readings.
  final WebhookTarget draft;

  /// The last test send, of [saved]. Any edit clears it.
  final ({TestResult result, DateTime at})? lastTest;

  bool get hasUrl => saved.hasUrl;

  /// Whether the draft has a URL that saving would keep.
  bool get draftHasUrl => draft.hasUrl && draft.urlProblem == null;

  /// A test saves the draft first, so the result says what readings get.
  bool get canTest => draft.isUsable;

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

  /// Only read after the saved webhook has loaded (every edit awaits
  /// [future] first), so an early edit can't start from nothing and save
  /// over it.
  WebhookSettings get _current => state.requireValue;

  /// Changes the URL being typed; see [save].
  Future<void> editUrl(String text) async {
    await future;
    _setDraft(_current.draft.copyWith(url: text.trim()));
  }

  /// Changes the credentials. Picking another kind applies at once, like
  /// any choice; typing in their fields waits for [save].
  Future<void> editAuth(WebhookAuth auth) async {
    await future;
    final typeChanged = auth.type != _current.draft.auth.type;
    _setDraft(_current.draft.copyWith(auth: auth));
    if (typeChanged) await save();
  }

  /// Saves the parts of the draft that can be used: a valid URL, or none to
  /// remove it, and complete credentials. Called when typing is done: on
  /// Done, leaving the form, going back, or before a test.
  Future<void> save() async {
    // The last save comes as a form goes, which can be as the app closes,
    // before or while the saved webhook loads.
    if (!ref.mounted) return;
    await future;
    if (!ref.mounted) return;
    final current = _current;
    final draft = current.draft;
    final saved = current.saved.copyWith(
      url: draft.urlProblem == null ? draft.url : null,
      auth: draft.auth.problem == null ? draft.auth : null,
    );
    if (saved == current.saved) return;
    state = AsyncData(WebhookSettings(saved: saved, draft: draft));
    await ref.read(settingsStoreProvider).saveWebhook(saved);
    // A fixed URL or token should deliver what's queued without waiting
    // for the next retry; saving doesn't wait for it.
    unawaited(ref.read(webhookSenderProvider).flush());
  }

  /// Saves the draft and sends a test reading to it.
  Future<void> sendTest() async {
    await future;
    if (!_current.canTest) return;
    await save();
    final tested = _current.saved;
    final result = await ref.read(webhookSenderProvider).sendTest(tested);
    // An edit while it was on its way makes the result stale.
    if (_current.saved != tested || _current.draft != tested) return;
    state = AsyncData(
      WebhookSettings(
        saved: tested,
        draft: tested,
        lastTest: (result: result, at: DateTime.now()),
      ),
    );
  }

  /// Any edit makes the last test stale.
  void _setDraft(WebhookTarget draft) {
    if (draft == _current.draft) return;
    state = AsyncData(WebhookSettings(saved: _current.saved, draft: draft));
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
