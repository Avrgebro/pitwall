import 'package:material_ui/material_ui.dart';

import '../../../core/webhook/webhook_auth.dart';
import '../../../ui/ui.dart';
import '../delivery_text.dart';

/// Picks the authentication type and edits its credentials.
class AuthEditor extends StatefulWidget {
  const AuthEditor({
    super.key,
    required this.auth,
    required this.problem,
    required this.onChanged,
  });

  final WebhookAuth auth;
  final AuthProblem? problem;
  final ValueChanged<WebhookAuth> onChanged;

  @override
  State<AuthEditor> createState() => _AuthEditorState();
}

class _AuthEditorState extends State<AuthEditor> {
  late final _token = TextEditingController(text: widget.auth.token);
  late final _username = TextEditingController(text: widget.auth.username);
  late final _password = TextEditingController(text: widget.auth.password);
  late final _headerName = TextEditingController(text: widget.auth.headerName);
  late final _headerValue = TextEditingController(
    text: widget.auth.headerValue,
  );

  @override
  void dispose() {
    for (final controller in [
      _token,
      _username,
      _password,
      _headerName,
      _headerValue,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  WebhookAuth get _auth => widget.auth;

  @override
  Widget build(BuildContext context) {
    final type = _auth.type;
    final error = context.tone(StatusTone.error).accent;
    Widget gap() => const SizedBox(height: Insets.m);

    return Padding(
      padding: const EdgeInsets.only(top: Insets.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<WebhookAuthType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final option in WebhookAuthType.values)
                DropdownMenuItem(
                  value: option,
                  child: Text(DeliveryText.authType(option)),
                ),
            ],
            onChanged: (value) => widget.onChanged(_auth.copyWith(type: value)),
          ),
          if (type == WebhookAuthType.none) ...[
            gap(),
            const InfoNote(
              padding: EdgeInsets.zero,
              text: TextSpan(
                text:
                    'Home Assistant webhooks don\'t need it: the URL is the '
                    'secret.',
              ),
            ),
          ],
          if (type == WebhookAuthType.bearer) ...[
            gap(),
            SecretTextField(
              controller: _token,
              label: 'Token',
              onChanged: (text) =>
                  widget.onChanged(_auth.copyWith(token: text.trim())),
            ),
          ],
          if (type == WebhookAuthType.basic) ...[
            gap(),
            TextField(
              controller: _username,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Username'),
              onChanged: (text) =>
                  widget.onChanged(_auth.copyWith(username: text)),
            ),
            gap(),
            SecretTextField(
              controller: _password,
              label: 'Password',
              onChanged: (text) =>
                  widget.onChanged(_auth.copyWith(password: text)),
            ),
          ],
          if (type == WebhookAuthType.header) ...[
            gap(),
            TextField(
              controller: _headerName,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Header name',
                hintText: 'X-API-Key',
              ),
              onChanged: (text) =>
                  widget.onChanged(_auth.copyWith(headerName: text.trim())),
            ),
            gap(),
            SecretTextField(
              controller: _headerValue,
              label: 'Header value',
              onChanged: (text) =>
                  widget.onChanged(_auth.copyWith(headerValue: text)),
            ),
          ],
          if (widget.problem case final problem?
              when type != WebhookAuthType.none) ...[
            const SizedBox(height: Insets.s),
            Text(
              DeliveryText.authProblem(problem),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: error),
            ),
          ],
        ],
      ),
    );
  }
}
