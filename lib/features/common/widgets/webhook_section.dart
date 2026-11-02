import '../../../core/format/formatters.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/webhook/webhook_auth.dart';
import '../../../state/webhook_state.dart';
import '../../../ui/ui.dart';
import '../delivery_text.dart';
import 'auth_editor.dart';

/// The webhook URL, its optional authentication and a test send. Also used
/// in first-run setup. What's typed, saved and tested lives in
/// [webhookProvider], so it survives leaving the screen.
class WebhookSection extends ConsumerWidget {
  const WebhookSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(webhookProvider)) {
        AsyncData(:final value) => _WebhookForm(initialUrl: value.draft.url),
        AsyncError() => const InfoNote(
          icon: Icons.error_outline,
          tone: StatusTone.error,
          text: TextSpan(text: 'Couldn\'t read the saved webhook.'),
        ),
        _ => const LoadingIndicator(),
      };
}

class _WebhookForm extends ConsumerStatefulWidget {
  const _WebhookForm({required this.initialUrl});

  /// What the URL field starts with; the field reports every edit.
  final String initialUrl;

  @override
  ConsumerState<_WebhookForm> createState() => _WebhookFormState();
}

class _WebhookFormState extends ConsumerState<_WebhookForm> {
  late final _url = TextEditingController(text: widget.initialUrl);
  bool _testing = false;

  WebhookNotifier get _webhook => ref.read(webhookProvider.notifier);

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _sendTest() async {
    setState(() => _testing = true);
    await _webhook.sendTest();
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(webhookProvider).requireValue;
    final draft = settings.draft;
    final mono = Theme.of(context).textTheme.mono;

    // What's typed is saved once typing is done: on leaving the form
    // (Done on the keyboard does that) or leaving the page. Sending a test
    // saves first too.
    return PopScope(
      onPopInvokedWithResult: (_, _) => _webhook.save(),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) {
          if (!focused) _webhook.save();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContentCard(
              child: SecretTextField(
                controller: _url,
                label: 'Webhook URL',
                keyboardType: TextInputType.url,
                helperText: 'Stored securely on this phone',
                errorText: switch (draft.urlProblem) {
                  final problem? => DeliveryText.urlProblem(problem),
                  null => null,
                },
                multilineWhenShown: true,
                onChanged: _webhook.editUrl,
                warning: draft.isInsecure
                    ? TextSpan(
                        children: [
                          TextSpan(
                            text: draft.auth.type == WebhookAuthType.none
                                ? 'Not encrypted. Anyone on the same network can '
                                      'read your car\'s data. Use '
                                : 'Not encrypted. Anyone on the same network can '
                                      'read your car\'s data and credentials. Use ',
                          ),
                          TextSpan(
                            text: 'https://',
                            style: mono.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' if your server supports it.'),
                        ],
                      )
                    : null,
              ),
            ),
            const SectionHeader.icon(
              'Authentication',
              icon: Symbols.key_rounded,
            ),
            AuthEditor(auth: draft.auth, onChanged: _webhook.editAuth),
            const SizedBox(height: Insets.xl),
            GlassButton(
              onPressed: settings.canTest && !_testing ? _sendTest : null,
              icon: _testing
                  ? const SizedBox.square(
                      dimension: Sizes.iconSmall,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.send_rounded),
              child: const Text('Send test'),
            ),
            if (settings.lastTest case (:final result, :final at)) ...[
              const SizedBox(height: Insets.m),
              if (result.error case final error?)
                ResultBanner(
                  tone: StatusTone.error,
                  title: DeliveryText.error(error).title,
                  message: DeliveryText.error(error).message,
                )
              else
                ResultBanner(
                  tone: StatusTone.healthy,
                  title: 'Test reading delivered',
                  message:
                      'The server accepted it in '
                      '${Formatters.elapsed(result.elapsed)}, at '
                      '${Formatters.clock(at)}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}
