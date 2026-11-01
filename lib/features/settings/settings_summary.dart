import '../../core/settings/settings.dart';
import '../../core/webhook/delivery_status.dart';
import '../../state/webhook_state.dart';
import '../../ui/format/formatters.dart';
import '../common/delivery_text.dart';

/// The one-line state shown under each row of the Settings overview.
abstract final class SettingsSummary {
  /// "Not set yet", "Set · last sent 2 min ago", or the problem.
  static ({String text, bool problem}) webhook(
    WebhookConfig config,
    DeliveryStatus status,
    DateTime now,
  ) {
    if (!config.hasUrl) return (text: 'Not set yet', problem: true);
    final error = status.lastError;
    if (error != null && !error.isTransient) {
      return (text: DeliveryText.error(error).title, problem: true);
    }
    final lastSuccess = status.lastSuccess;
    return (
      text: lastSuccess == null
          ? 'Set · nothing sent yet'
          : 'Set · last sent ${Formatters.ago(lastSuccess, now)}',
      problem: false,
    );
  }

  /// "When TUCSON BT connects", or what's missing.
  static ({String text, bool problem}) wake(AppSettings settings) =>
      switch (settings.wakeTrigger) {
        WakeTrigger.carBluetooth => switch (settings.headUnitName) {
          final name? => (text: 'When $name connects', problem: false),
          null => (text: 'Choose your car\'s Bluetooth', problem: true),
        },
        WakeTrigger.drivingDetection => (
          text: 'When driving is detected (not available yet)',
          problem: true,
        ),
      };

  /// "All set" or "1 needs fixing".
  static ({String text, bool problem}) checks(int missing) => missing == 0
      ? (text: 'All set', problem: false)
      : (text: '$missing needs fixing', problem: true);
}
