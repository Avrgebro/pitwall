/// A made-up profile in OBDb's signal-set format, written for these tests.
/// It doesn't describe a real car.
const testProfileJson = '''
{
  "commands": [
    {
      "hdr": "7A0", "rax": "7A8", "cmd": {"22": "1234"}, "freq": 1,
      "signals": [
        {"id": "TEST_FUEL_VOL", "path": "Fuel", "name": "Fuel volume",
         "suggestedMetric": "fuelTankLevel",
         "fmt": {"bix": 8, "len": 8, "div": 2, "nullmax": 127.5, "unit": "liters"}},
        {"id": "TEST_ODO_MI", "path": "Trips", "name": "Odometer, imperial",
         "suggestedMetric": "odometer",
         "fmt": {"bix": 16, "len": 24, "nullmin": 0, "unit": "miles"}}
      ]
    },
    {
      "hdr": "7E0", "rax": "7E8", "cmd": {"22": "0042"}, "filter": {"to": 2019},
      "signals": [
        {"id": "TEST_OLD_ONLY", "name": "Older cars only",
         "fmt": {"bix": 0, "len": 8, "unit": "scalar"}}
      ]
    },
    {"hdr": "7E0", "rax": "7E8", "cmd": {"2E": "1234"},
     "signals": [{"id": "TEST_WRITE", "name": "Write", "fmt": {"len": 8, "unit": "scalar"}}]},
    {"hdr": "7E0", "rax": "7E8", "cmd": {"31": "0101"},
     "signals": [{"id": "TEST_ROUTINE", "name": "Routine", "fmt": {"len": 8, "unit": "scalar"}}]},
    {"hdr": "7E0", "rax": "7E8", "cmd": {"11": "01"},
     "signals": [{"id": "TEST_RESET", "name": "Reset", "fmt": {"len": 8, "unit": "scalar"}}]},
    {"hdr": "18DA10F1", "cmd": {"22": "0001"},
     "signals": [{"id": "TEST_29BIT", "name": "29-bit", "fmt": {"len": 8, "unit": "scalar"}}]},
    {"hdr": "7E0", "rax": "7E8", "cmd": {"22": "0100"}, "fcm1": true,
     "signals": [{"id": "TEST_FCM1", "name": "Flow control", "fmt": {"len": 8, "unit": "scalar"}}]}
  ]
}
''';
