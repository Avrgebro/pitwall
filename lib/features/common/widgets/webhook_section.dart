import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/webhook/delivery_status.dart';
import '../../../core/webhook/webhook_auth.dart';
import '../../../state/webhook_state.dart';
import '../../../ui/ui.dart';
import '../delivery_text.dart';
import 'auth_editor.dart';

/// The webhook URL, its optional authentication and a test send. Also used
/// in first-run setup.
class WebhookSection extends ConsumerStatefulWidget {
  const WebhookSection({super.key, this.onTested});

  /// Called after each test send, with whether it worked.
  final ValueChanged<bool>? onTested;

  @override
  ConsumerState<WebhookSection> createState() => _WebhookSectionState();
}

class _WebhookSectionState extends ConsumerState<WebhookSection> {
  final _url = TextEditingController();
  WebhookAuth _auth = WebhookAuth.none;
  String? _urlProblem;
  AuthProblem? _authProblem;
  bool _authOpen = false;
  bool _testing = false;
  ({TestResult result, DateTime at})? _test;
  bool _loaded = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _load(WebhookConfig config) {
    if (_loaded) return;
    _loaded = true;
    _url.text = config.url;
    _auth = config.auth;
    _authOpen = config.auth.type != WebhookAuthType.none;
  }

  Future<void> _urlChanged(String text) async {
    final problem = await ref.read(webhookConfigProvider.notifier).setUrl(text);
    if (!mounted) return;
    setState(() {
      _urlProblem = problem == null ? null : DeliveryText.urlProblem(problem);
      _test = null;
    });
  }

  Future<void> _authChanged(WebhookAuth auth) async {
    setState(() {
      _auth = auth;
      _test = null;
    });
    final problem = await ref
        .read(webhookConfigProvider.notifier)
        .setAuth(auth);
    if (mounted) setState(() => _authProblem = problem);
  }

  Future<void> _sendTest() async {
    setState(() => _testing = true);
    final result = await ref
        .read(webhookConfigProvider.notifier)
        .sendTest(_url.text, _auth);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _test = (result: result, at: DateTime.now());
    });
    widget.onTested?.call(result.succeeded);
  }

  bool get _canTest =>
      !_testing &&
      _url.text.trim().isNotEmpty &&
      _urlProblem == null &&
      _auth.problem == null;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(webhookConfigProvider);
    if (config.value case final value?) _load(value);
    final insecure = _url.text.trim().startsWith('http://');
    final mono = Theme.of(context).textTheme.mono;

    return ContentCard(
      padding: Insets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecretTextField(
            controller: _url,
            label: 'Webhook URL',
            keyboardType: TextInputType.url,
            helperText: 'Stored securely on this phone',
            errorText: _urlProblem,
            multilineWhenShown: true,
            onChanged: _urlChanged,
            warning: insecure
                ? TextSpan(
                    children: [
                      TextSpan(
                        text: _auth.type == WebhookAuthType.none
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
          const SizedBox(height: Insets.s),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Symbols.key_rounded),
            title: const Text('Authentication'),
            subtitle: Text(DeliveryText.authType(_auth.type)),
            trailing: Icon(_authOpen ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _authOpen = !_authOpen),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _authOpen
                ? AuthEditor(
                    auth: _auth,
                    problem: _authProblem,
                    onChanged: _authChanged,
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: Insets.m),
          FilledButton.icon(
            onPressed: _canTest ? _sendTest : null,
            icon: _testing
                ? const SizedBox.square(
                    dimension: Sizes.iconSmall,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.send_rounded),
            label: const Text('Send test'),
          ),
          if (_test case (:final result, :final at)) ...[
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
                    '${Formatters.elapsed(result.elapsed)} · '
                    '${Formatters.clock(at)}',
              ),
          ],
        ],
      ),
    );
  }
}
