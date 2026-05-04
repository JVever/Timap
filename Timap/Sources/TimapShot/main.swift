// TimapShot — CLI that asks the running Timap.app to take a screenshot
// of its menu-bar popover and save it to a file. Returns the file path
// on stdout. Used by `make screenshot OUT=...`.
//
// Usage:  TimapShot [out-path]
//   default out-path: /tmp/timap-shot-<unix>.png
//
// Mechanics:
//   1. Post `com.timap.screenshot.request` distributed notification with
//      the desired output path in userInfo["path"].
//   2. Wait up to 5 seconds for either:
//        - `com.timap.screenshot.done`   (success — print path, exit 0)
//        - `com.timap.screenshot.failed` (failure — print reason, exit 1)
//        - timeout (Timap.app not running? — exit 2)

import Foundation

let argPath: String = {
    if CommandLine.arguments.count >= 2 {
        return CommandLine.arguments[1]
    }
    let ts = Int(Date().timeIntervalSince1970)
    return "/tmp/timap-shot-\(ts).png"
}()

let outPath = (argPath as NSString).expandingTildeInPath

// Make sure the parent directory exists.
let parent = (outPath as NSString).deletingLastPathComponent
if !FileManager.default.fileExists(atPath: parent) {
    try? FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
}
// Remove any stale file at the target path so we can detect the new write.
try? FileManager.default.removeItem(atPath: outPath)

let nc = DistributedNotificationCenter.default()
let group = DispatchGroup()
group.enter()

var resultExitCode: Int32 = 2
var resultMessage = "timeout — is Timap.app running?"

let doneObs = nc.addObserver(
    forName: Notification.Name("com.timap.screenshot.done"),
    object: nil,
    queue: .main
) { notif in
    let path = (notif.userInfo?["path"] as? String) ?? outPath
    resultExitCode = 0
    resultMessage = path
    group.leave()
}
let failObs = nc.addObserver(
    forName: Notification.Name("com.timap.screenshot.failed"),
    object: nil,
    queue: .main
) { notif in
    let reason = (notif.userInfo?["reason"] as? String) ?? "unknown"
    resultExitCode = 1
    resultMessage = "failed: \(reason)"
    group.leave()
}

// Post the request.
nc.postNotificationName(
    Notification.Name("com.timap.screenshot.request"),
    object: nil,
    userInfo: ["path": outPath],
    deliverImmediately: true
)

// Drive the run loop while we wait so notification observers can fire.
let deadline = Date().addingTimeInterval(5)
while resultExitCode == 2 && Date() < deadline {
    RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
}

nc.removeObserver(doneObs)
nc.removeObserver(failObs)

if resultExitCode == 0 {
    print(resultMessage)
} else {
    FileHandle.standardError.write((resultMessage + "\n").data(using: .utf8)!)
}
exit(resultExitCode)
