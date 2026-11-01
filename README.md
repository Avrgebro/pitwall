# Pitwall

Pitwall is a phone app that sends live data from your car to any webhook. It
reads the car through a cheap OBD-II Bluetooth adapter, such as an ELM327 or a
Vgate iCar Pro.

> **Status:** early development. Nothing works yet. Android comes first, then
> iOS.

## What it does

```
[car OBD-II port] ── adapter ──Bluetooth──▶ [phone] ──HTTPS POST──▶ [your webhook]
```

- **Starts on its own.** When the car is running and the adapter is in
  reach, Pitwall connects in the background, without being opened. It stops
  when the car is turned off.
- **Reads standard OBD-II values** on an interval (every minute by default),
  such as fuel level, speed, RPM, coolant temperature and battery voltage. It
  only sends values your car actually reports.
- **POSTs them as JSON** to a URL you choose. Home Assistant is the main
  target, but anything that accepts a POST works: Node-RED, n8n or your own
  server. Optional authentication: bearer token, username and password, or
  a custom header.
- **Keeps readings while offline** and sends them, in order, once the phone
  has signal again.

Example payload (not final yet):

```json
{
  "device": "my-car",
  "seq": 1284,
  "timestamp": "2026-10-31T19:40:00Z",
  "values": {
    "fuel_level_pct": 46.3,
    "speed_kmh": 52,
    "rpm": 1850,
    "coolant_temp_c": 89,
    "battery_v": 14.1
  },
  "connected": true
}
```

## Principles

- **No accounts, no cloud, no tracking.** Pitwall talks only to your adapter
  and to the URL you set.
- **Read-only.** It never sends commands that change anything in the car,
  and it doesn't read or clear trouble codes.
- **Set up once, then forget it.** Nothing to do while driving.

## Supported adapters

| | Android | iOS |
|---|---|---|
| Bluetooth LE adapters | Planned | Planned |
| Classic Bluetooth (serial) adapters | Planned | Not possible: iOS doesn't allow them |

Android needs version 12 or later.

## Building from source

Requires [Flutter](https://docs.flutter.dev/get-started/install) (stable
channel).

```sh
flutter pub get
flutter run
```

Bluetooth doesn't work in emulators or simulators. Use a real phone.

## License

[MIT](LICENSE)
