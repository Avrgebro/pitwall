import 'package:material_ui/material_ui.dart';

import '../../../core/webhook/webhook_auth.dart';
import '../../../ui/ui.dart';
import '../delivery_text.dart';

/// Picks the authentication type from a list of options; the selected one
/// opens its credential fields. Values typed for one type are kept when
/// switching to another and back. Each field shows its problem once the
/// user has edited it.
class AuthEditor extends StatefulWidget {
  const AuthEditor({super.key, required this.auth, required this.onChanged});

  final WebhookAuth auth;
  final ValueChanged<WebhookAuth> onChanged;

  @override
  State<AuthEditor> createState() => _AuthEditorState();
}

enum _Field { token, username, password, headerName, headerValue }

class _AuthEditorState extends State<AuthEditor> {
  late final _controllers = {
    _Field.token: TextEditingController(text: widget.auth.token),
    _Field.username: TextEditingController(text: widget.auth.username),
    _Field.password: TextEditingController(text: widget.auth.password),
    _Field.headerName: TextEditingController(text: widget.auth.headerName),
    _Field.headerValue: TextEditingController(text: widget.auth.headerValue),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  WebhookAuth get _auth => widget.auth;

  /// The field a problem is about.
  static _Field _fieldOf(AuthProblem problem, WebhookAuthType type) =>
      switch (problem) {
        AuthProblem.missingToken ||
        AuthProblem.tokenHasWhitespace => _Field.token,
        AuthProblem.missingUsername ||
        AuthProblem.usernameHasColon => _Field.username,
        AuthProblem.invalidHeaderName ||
        AuthProblem.reservedHeader => _Field.headerName,
        AuthProblem.missingHeaderValue => _Field.headerValue,
        AuthProblem.lineBreak => switch (type) {
          WebhookAuthType.basic => _Field.password,
          WebhookAuthType.header => _Field.headerValue,
          _ => _Field.token,
        },
      };

  /// A validator for [field]: the problem of the credentials with the
  /// field's text in them, if that problem is about this field.
  FormFieldValidator<String> _check(
    _Field field,
    WebhookAuth Function(String text) withText,
  ) => (text) {
    final candidate = withText(text ?? '');
    final problem = candidate.problem;
    if (problem == null || _fieldOf(problem, candidate.type) != field) {
      return null;
    }
    return DeliveryText.authProblem(problem);
  };

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: Insets.m);
    return RadioGroup<WebhookAuthType>(
      groupValue: _auth.type,
      onChanged: (type) {
        if (type != null) widget.onChanged(_auth.copyWith(type: type));
      },
      child: RowGroup(
        children: [
          ChoiceRow(
            value: WebhookAuthType.none,
            title: DeliveryText.authType(WebhookAuthType.none),
          ),
          ChoiceRow(
            value: WebhookAuthType.bearer,
            title: DeliveryText.authType(WebhookAuthType.bearer),
            subtitle: 'Sent in the Authorization header.',
            child: SecretTextField(
              controller: _controllers[_Field.token]!,
              label: 'Token',
              validator: _check(
                _Field.token,
                (text) => _auth.copyWith(token: text.trim()),
              ),
              onChanged: (text) =>
                  widget.onChanged(_auth.copyWith(token: text.trim())),
            ),
          ),
          ChoiceRow(
            value: WebhookAuthType.basic,
            title: DeliveryText.authType(WebhookAuthType.basic),
            subtitle: 'HTTP Basic authentication.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _controllers[_Field.username],
                  autocorrect: false,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _check(
                    _Field.username,
                    (text) => _auth.copyWith(username: text),
                  ),
                  decoration: const InputDecoration(labelText: 'Username'),
                  onChanged: (text) =>
                      widget.onChanged(_auth.copyWith(username: text)),
                ),
                gap,
                SecretTextField(
                  controller: _controllers[_Field.password]!,
                  label: 'Password',
                  validator: _check(
                    _Field.password,
                    (text) => _auth.copyWith(password: text),
                  ),
                  onChanged: (text) =>
                      widget.onChanged(_auth.copyWith(password: text)),
                ),
              ],
            ),
          ),
          ChoiceRow(
            value: WebhookAuthType.header,
            title: DeliveryText.authType(WebhookAuthType.header),
            subtitle: 'Your own header.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _controllers[_Field.headerName],
                  autocorrect: false,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _check(
                    _Field.headerName,
                    (text) => _auth.copyWith(headerName: text.trim()),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Header name',
                    hintText: 'X-API-Key',
                  ),
                  onChanged: (text) =>
                      widget.onChanged(_auth.copyWith(headerName: text.trim())),
                ),
                gap,
                SecretTextField(
                  controller: _controllers[_Field.headerValue]!,
                  label: 'Header value',
                  validator: _check(
                    _Field.headerValue,
                    (text) => _auth.copyWith(headerValue: text),
                  ),
                  onChanged: (text) =>
                      widget.onChanged(_auth.copyWith(headerValue: text)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
