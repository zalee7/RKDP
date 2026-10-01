import Foundation

// Generates build output only; never replaces the normal app's source plists.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func readPlist(_ path: String) throws -> [String: Any] {
    let data = try Data(contentsOf: root.appendingPathComponent(path))
    guard let value = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        throw CocoaError(.propertyListReadCorrupt)
    }
    return value
}
let config = try readPlist(".firebase/puzzlepartytest/GoogleService-Info.plist")
guard config["PROJECT_ID"] as? String == "puzzlepartytest",
      config["BUNDLE_ID"] as? String == "com.rkdp.app",
      config["GOOGLE_APP_ID"] as? String == "1:511207188211:ios:0d3c081c9984ab1a977986" else {
    fatalError("Refusing non-test Firebase configuration")
}
var info = try readPlist("RKDP/SupportingFiles/Info.plist")
let ranked = CommandLine.arguments.contains("--ranked")
let social = ranked || CommandLine.arguments.contains("--social")
info["CFBundleDisplayName"] = ranked ? "PP Ranked Test" : social ? "PP Social Test" : "PP Purchase Test"
info["PPTestFirebase"] = config.filter { ["PROJECT_ID", "BUNDLE_ID", "GOOGLE_APP_ID", "GCM_SENDER_ID", "API_KEY"].contains($0.key) }
info["FirebaseMessagingAutoInitEnabled"] = false
info.removeValue(forKey: "CFBundleURLTypes")
info.removeValue(forKey: "UIBackgroundModes")
let destination = root.appendingPathComponent(".firebase/puzzlepartytest/\(ranked ? "RankedTest" : social ? "SocialTest" : "PurchaseTest")-Info.plist")
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: destination, options: .atomic)
print("Prepared isolated \(social ? "social" : "purchase")-test build configuration.")
