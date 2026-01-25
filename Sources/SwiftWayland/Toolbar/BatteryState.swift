import NIOFileSystem
import RegexBuilder

struct SnapShot {
  let batteryPercent: Int
}

actor SystemState {

  init() {
    Task {
      await read()
    }
  }

  var batteryPercent: Int = 69

  private func read() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(1))
      await updateBatteryPercent()
    }
  }

  private func updateBatteryPercent() async {
    let charge_now: FilePath = "/sys/class/power_supply/macsmc-battery/charge_now"
    let charge_full: FilePath = "/sys/class/power_supply/macsmc-battery/charge_full"
    do {
      let cn = try await charge_now.getValue().replacing(/\s+/, with: "")
      let cf = try await charge_full.getValue().replacing(/\s+/, with: "")
      guard let now = Double(cn), let full = Double(cf) else {
        print("failed to parse battery info")
        return
      }
      let percent = Int((now / full) * 100.0)
      batteryPercent = percent
    } catch {
      print("failed to read battery info")
      return
    }
  }

  func view() -> SnapShot {
    SnapShot(batteryPercent: batteryPercent)
  }
}

extension FilePath {
  func getValue() async throws -> String {
    let fh = try await FileSystem.shared.openFile(forReadingAt: self)
    let buffer = try await fh.readToEnd(fromAbsoluteOffset: 0, maximumSizeAllowed: .bytes(.max))
    let value = String(buffer: buffer)
    try? await fh.close()
    return value
  }
}
