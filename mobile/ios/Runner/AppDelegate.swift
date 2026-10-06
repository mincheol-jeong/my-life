import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppInfoBridge") {
      FlutterMethodChannel(name: "com.mincheol.mylife/app_info", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          guard call.method == "getAppInfo" else { result(FlutterMethodNotImplemented); return }
          result(["version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                  "buildNumber": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""])
        }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PaymentImportBridge") {
      FlutterMethodChannel(name: "com.mincheol.mylife/payment_import", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          let defaults = UserDefaults.standard
          switch call.method {
          case "status":
            result(["enabled": defaults.bool(forKey: "payment_import_enabled"), "access": true,
                    "apps": [], "selected": []])
          case "configure":
            let arguments = call.arguments as? [String: Any] ?? [:]
            let enabled = arguments["enabled"] as? Bool ?? false
            defaults.set(enabled, forKey: "payment_import_enabled")
            if !enabled { defaults.removeObject(forKey: "payment_import_pending") }
            result(nil)
          case "pending": result(PaymentShortcutInbox.pending())
          case "acknowledge":
            let arguments = call.arguments as? [String: Any] ?? [:]
            let ids = arguments["ids"] as? [String] ?? []
            defaults.set(PaymentShortcutInbox.pending().filter { !ids.contains($0["id"] as? String ?? "") },
                         forKey: "payment_import_pending")
            result(nil)
          default: result(FlutterMethodNotImplemented)
          }
        }
    }
  }
}

enum PaymentShortcutInbox {
  static func pending() -> [[String: Any]] {
    let rows = UserDefaults.standard.array(forKey: "payment_import_pending") as? [[String: Any]] ?? []
    let cutoff = Date().timeIntervalSince1970 * 1000 - 7 * 24 * 60 * 60 * 1000
    return rows.filter { ($0["receivedAt"] as? Double ?? 0) >= cutoff }
  }

  static func receive(_ url: URL) {
    guard UserDefaults.standard.bool(forKey: "payment_import_enabled"),
          url.scheme == "mylife", url.host == "payment-import",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let text = components.queryItems?.first(where: { $0.name == "text" })?.value,
          !text.isEmpty, text.count <= 2000 else { return }
    let source = components.queryItems?.first(where: { $0.name == "source" })?.value ?? "shortcuts"
    let id = components.queryItems?.first(where: { $0.name == "id" })?.value ?? UUID().uuidString
    guard !source.isEmpty, source.count <= 120, !id.isEmpty, id.count <= 200 else { return }
    var rows = pending().filter { $0["id"] as? String != id }
    rows.append(["id": id, "source": source, "text": text,
                 "receivedAt": Int64(Date().timeIntervalSince1970 * 1000)])
    UserDefaults.standard.set(Array(rows.suffix(100)), forKey: "payment_import_pending")
  }
}
