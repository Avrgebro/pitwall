import '../../core/webhook/delivery_status.dart';
import '../../core/webhook/webhook_target.dart';
import '../../core/format/formatters.dart';
import '../common/delivery_text.dart';

/// The one-line state shown under each row of the Settings overview.
abstract final class SettingsSummary {
  /// "Not set yet", "Nothing sent yet", "Last sent 2 min ago", or the
  /// problem.
  static ({String text, bool problem}) webhook(
    WebhookTarget webhook,
    DeliveryStatus status,
    DateTime now,
  ) {
    if (!webhook.hasUrl) return (text: 'Not set yet', problem: true);
    final error = status.lastError;
    if (error != null && error.kind.needsUser) {
      return (text: DeliveryText.error(error).title, problem: true);
    }
    final lastSuccess = status.lastSuccess;
    return (
      text: lastSuccess == null
          ? 'Nothing sent yet'
          : 'Last sent ${Formatters.ago(lastSuccess, now)}',
      problem: false,
    );
  }

  /// "All set" or "1 needs fixing".
  static ({String text, bool problem}) checks(int missing) => missing == 0
      ? (text: 'All set', problem: false)
      : (text: '$missing needs fixing', problem: true);
}
