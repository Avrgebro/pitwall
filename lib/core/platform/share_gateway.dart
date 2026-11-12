import 'messages.g.dart';

/// Android's share sheet, behind an interface so screens can be tested
/// without a phone. Backed by `ShareChannel.kt`.
abstract interface class ShareGateway {
  /// Offers [text] to the apps that take it, titled [subject].
  Future<void> shareText({required String subject, required String text});
}

class AndroidShareGateway implements ShareGateway {
  const AndroidShareGateway();

  @override
  Future<void> shareText({required String subject, required String text}) =>
      ShareApi().shareText(subject, text);
}
