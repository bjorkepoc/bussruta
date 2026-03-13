# Hosted LAN Testing On Android Emulators

## Why join fails by default

- Each Android emulator runs behind its own virtual router/NAT.
- Inside each emulator, host discovery/host address often resolves to `10.0.2.15`.
- That address is local to each emulator instance, so emulator B cannot reach emulator A at `10.0.2.15:<port>`.

Result:
- LAN discovery is unreliable between emulators.
- Direct join with host-emulator `10.0.2.15` usually fails with host-unavailable errors.

## Recommended emulator workflow

Assume:
- Host emulator: `emulator-5554`
- Join emulator: `emulator-5556`
- Hosted session TCP port: `45879`

1. Start hosting on emulator A.
2. On host machine, forward host TCP port to host emulator:

```powershell
adb -s emulator-5554 forward tcp:45879 tcp:45879
```

3. On emulator B, join manually with:
- Host address: `10.0.2.2`
- Port: `45879` (auto/default in app)
- Same session PIN shown by host

4. If needed, clear forwarding after testing:

```powershell
adb -s emulator-5554 forward --remove tcp:45879
```

## Real-device expectation

- On two physical phones on the same Wi-Fi, use LAN discovery or host-address + PIN directly.
- The `10.0.2.2` workflow is emulator-specific and not needed on real LAN devices.
