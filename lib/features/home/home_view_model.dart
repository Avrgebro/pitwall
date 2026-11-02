import 'package:flutter/foundation.dart';

import '../../core/readings/last_values.dart';
import '../../core/readings/readings.dart';
import '../../core/session/car_state.dart';
import '../../core/settings/settings.dart';
import '../../core/vehicles/vehicle.dart';
import '../../core/webhook/delivery_status.dart';
import '../../state/session_state.dart';
import '../../ui/components/value_tile.dart';
import '../../ui/format/formatters.dart';
import '../../ui/theme/status_colors.dart';
import '../common/delivery_text.dart';
import '../common/value_display.dart';

enum HeroState { running, connecting, waiting }

enum HeroStatKind {
  adapter,
  adapterMissing,
  car,
  carOff,
  trip,
  lastConnected,
  lastReading,
}

enum DeliveryCardKind { healthy, queued, failing, noWebhook }

enum DeliveryStatKind { lastSent, failed, queued }

/// What the delivery card offers; it shows exactly these.
enum DeliveryAction { setWebhook, openSettings, retry }

@immutable
class HeroModel {
  const HeroModel({
    required this.state,
    required this.title,
    this.subtitle,
    required this.stats,
  });

  final HeroState state;
  final String title;

  /// What Pitwall is doing right now; none while it waits, as the state
  /// chip already says so.
  final String? subtitle;
  final List<({HeroStatKind kind, String label, String value})> stats;

  StatusTone get tone =>
      state == HeroState.running ? StatusTone.active : StatusTone.neutral;
}

@immutable
class DeliveryCardModel {
  const DeliveryCardModel({
    required this.kind,
    required this.title,
    this.message,
    required this.stats,
    this.actions = const {},
  });

  final DeliveryCardKind kind;
  final String title;

  /// What's going on, when the title doesn't say it all: none while
  /// healthy, an explanation when something's wrong.
  final String? message;
  final List<({DeliveryStatKind kind, String label, String value})> stats;
  final Set<DeliveryAction> actions;

  StatusTone get tone => switch (kind) {
    DeliveryCardKind.healthy => StatusTone.healthy,
    DeliveryCardKind.queued => StatusTone.warning,
    DeliveryCardKind.failing => StatusTone.error,
    DeliveryCardKind.noWebhook => StatusTone.warning,
  };

  /// Problems rise to the top, above the values.
  bool get isProblem => kind != DeliveryCardKind.healthy;
}

@immutable
class ValuesModel {
  const ValuesModel({
    required this.title,
    required this.meta,
    required this.tiles,
  });

  final String title;
  final String meta;
  final List<ValueTileData> tiles;
}

/// Everything Home shows for one vehicle, in words, worked out from the
/// app's state. Kept free of widgets so each state can be tested directly.
@immutable
class HomeViewModel {
  const HomeViewModel({
    required this.hero,
    required this.delivery,
    required this.values,
  });

  factory HomeViewModel.build({
    required Vehicle vehicle,
    required AppSettings settings,
    required SessionState session,
    required DeliveryStatus delivery,
    required bool hasWebhook,
    required List<ValueOption> options,
    required Map<String, LastValue> lastValues,
    required DateTime now,
  }) {
    final ownSession = session.vehicleId == vehicle.id;
    final connected = ownSession && session.isConnected;
    final card = _delivery(delivery, hasWebhook, now);
    final lastReading = lastValues.values
        .map((value) => value.readAt)
        .fold<DateTime?>(
          null,
          (newest, at) => newest == null || at.isAfter(newest) ? at : newest,
        );
    return HomeViewModel(
      hero: _hero(
        vehicle: vehicle,
        settings: settings,
        session: session,
        connected: connected,
        connecting: ownSession && session.phase == SessionPhase.connecting,
        deliveryHealthy: !card.isProblem,
        lastReading: lastReading,
        now: now,
      ),
      delivery: card,
      values: _values(
        vehicle: vehicle,
        lastValues: lastValues,
        newest: lastReading,
        status: delivery,
        options: options,
        now: now,
      ),
    );
  }

  final HeroModel hero;
  final DeliveryCardModel delivery;

  /// Null until a reading from this vehicle exists.
  final ValuesModel? values;

  static HeroModel _hero({
    required Vehicle vehicle,
    required AppSettings settings,
    required SessionState session,
    required bool connected,
    required bool connecting,
    required bool deliveryHealthy,
    required DateTime? lastReading,
    required DateTime now,
  }) {
    final every = Formatters.every(settings.interval);
    final lastConnected = (
      kind: HeroStatKind.lastConnected,
      label: 'Last connected',
      value: switch (vehicle.lastSeen) {
        final seen? => Formatters.ago(seen, now),
        null => 'Never',
      },
    );
    if (connected) {
      return HeroModel(
        state: HeroState.running,
        title: vehicle.name,
        subtitle: deliveryHealthy
            ? 'Sending a reading $every'
            : 'Reading the car $every',
        stats: [
          (kind: HeroStatKind.adapter, label: 'Adapter', value: 'Connected'),
          (
            kind: session.carState == CarState.off
                ? HeroStatKind.carOff
                : HeroStatKind.car,
            label: 'Car',
            value: _carState(session.carState),
          ),
          (
            kind: HeroStatKind.trip,
            label: 'Trip',
            value: Formatters.duration(now.difference(session.connectedAt!)),
          ),
        ],
      );
    }
    if (connecting) {
      return HeroModel(
        state: HeroState.connecting,
        title: vehicle.name,
        subtitle: 'Connecting to ${vehicle.adapterName ?? 'the adapter'}…',
        stats: [
          (kind: HeroStatKind.adapter, label: 'Adapter', value: 'Connecting'),
          (kind: HeroStatKind.car, label: 'Car', value: 'Checking'),
          lastConnected,
        ],
      );
    }
    return HeroModel(
      state: HeroState.waiting,
      title: vehicle.name,
      // Without a connection there's no telling whether the car is on, or
      // whether the adapter is near; only what was last heard from it.
      stats: [
        (
          kind: HeroStatKind.adapterMissing,
          label: 'Adapter',
          value: 'Not connected',
        ),
        lastConnected,
        if (lastReading != null)
          (
            kind: HeroStatKind.lastReading,
            label: 'Last reading',
            value: Formatters.ago(lastReading, now),
          ),
      ],
    );
  }

  static String _carState(CarState state) => switch (state) {
    CarState.engineRunning => 'Engine running',
    CarState.ignitionOn => 'Ignition on',
    CarState.off => 'Off',
    CarState.unknown => 'Checking',
  };

  static DeliveryCardModel _delivery(
    DeliveryStatus status,
    bool hasWebhook,
    DateTime now,
  ) {
    String count(int n) => n == 0 ? 'None' : '$n';
    final queued = status.queued;
    final error = status.lastError;
    final lastSuccess = status.lastSuccess;
    // The same three facts on every card that has sent or tried to.
    List<({DeliveryStatKind kind, String label, String value})> stats({
      String lastSentLabel = 'Last sent',
    }) => [
      (
        kind: DeliveryStatKind.lastSent,
        label: lastSentLabel,
        value: lastSuccess == null ? 'Never' : Formatters.ago(lastSuccess, now),
      ),
      (
        kind: DeliveryStatKind.failed,
        label: 'Failed',
        value: count(status.failedAttempts),
      ),
      (kind: DeliveryStatKind.queued, label: 'Queued', value: count(queued)),
    ];

    if (!hasWebhook) {
      return DeliveryCardModel(
        kind: DeliveryCardKind.noWebhook,
        title: 'No webhook yet',
        message: 'Readings have nowhere to go until you set one.',
        stats: [
          if (queued > 0)
            (
              kind: DeliveryStatKind.queued,
              label: 'Queued',
              value: count(queued),
            ),
        ],
        actions: const {DeliveryAction.setWebhook},
      );
    }

    if (error == null) {
      if (queued > 0) {
        return DeliveryCardModel(
          kind: DeliveryCardKind.queued,
          title: queued == 1 ? '1 reading waiting' : '$queued readings waiting',
          message: 'Sending now.',
          stats: stats(),
        );
      }
      return DeliveryCardModel(
        kind: DeliveryCardKind.healthy,
        title: status.latest == null ? 'Ready to send' : 'Delivery healthy',
        stats: stats(),
      );
    }

    // Retried on its own, so there's nothing to offer.
    if (error.isTransient) {
      final readings = queued == 1 ? '1 reading' : '$queued readings';
      return DeliveryCardModel(
        kind: DeliveryCardKind.queued,
        title: switch (error.kind) {
          DeliveryErrorKind.unreachable => 'No signal, $readings queued',
          DeliveryErrorKind.timeout => 'Server slow, $readings queued',
          _ => 'Server trouble, $readings queued',
        },
        message: error.kind == DeliveryErrorKind.unreachable
            ? 'They\'ll be sent automatically when the phone is back '
                  'online. Nothing to do.'
            : DeliveryText.error(error).message,
        stats: stats(),
      );
    }

    // Not retried on its own. Retry helps once the server side is fixed;
    // without a URL or complete credentials, only Settings can.
    final text = DeliveryText.error(error);
    final settingsOnly =
        error.kind == DeliveryErrorKind.noUrl ||
        error.kind == DeliveryErrorKind.authIncomplete;
    return DeliveryCardModel(
      kind: DeliveryCardKind.failing,
      title: text.title,
      message: text.message,
      stats: stats(lastSentLabel: 'Last success'),
      actions: {
        DeliveryAction.openSettings,
        if (!settingsOnly) DeliveryAction.retry,
      },
    );
  }

  /// The last value of each item the vehicle sends. Values read well
  /// before the newest, say ones the car stopped reporting as it switched
  /// off, say when they were read.
  static ValuesModel? _values({
    required Vehicle vehicle,
    required Map<String, LastValue> lastValues,
    required DateTime? newest,
    required DeliveryStatus status,
    required List<ValueOption> options,
    required DateTime now,
  }) {
    final keys = keysToSend(vehicle, options);
    final shown = {
      for (final MapEntry(:key, :value) in lastValues.entries)
        if (keys.contains(key)) key: value,
    };
    if (shown.isEmpty || newest == null) return null;
    final ago = Formatters.ago(newest, now);
    // The sender knows whether the newest reading went out, when it was
    // this car's.
    final reading = status.latest;
    final sent = reading?.device == vehicle.deviceId ? reading : null;
    return ValuesModel(
      title: switch (sent?.delivered) {
        true => 'Last values sent',
        false => 'Latest readings',
        null => 'Last values',
      },
      meta: switch ((sent?.delivered, status.lastError)) {
        (true, _) => 'Updated $ago',
        (null, _) => 'Read $ago',
        (false, null) => 'Read $ago, sending',
        (false, final error?) when error.isTransient =>
          'Read $ago, not sent yet',
        (false, _) => 'Read $ago, not delivered',
      },
      tiles: ValueDisplay.tiles(
        {for (final MapEntry(:key, :value) in shown.entries) key: value.value},
        options,
        notes: {
          for (final MapEntry(:key, :value) in shown.entries)
            if (newest.difference(value.readAt) >= _staleAfter)
              key: 'Read ${Formatters.ago(value.readAt, now)}',
        },
      ),
    );
  }

  /// A value at least this much older than the newest says when it was
  /// read.
  static const _staleAfter = Duration(minutes: 1);
}
