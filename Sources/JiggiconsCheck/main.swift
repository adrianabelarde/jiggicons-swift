// Checks the bundled icons and the drawing code without Xcode:
//   swift run JiggiconsCheck
import AVFoundation
import Foundation
import SwiftUI
@testable import Jiggicons

var failures = 0
var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures += 1; print("✗", message) }
}

// Every bundled icon decodes, has all four styles, a motion for each, and its sounds.
expect(Jiggicons.all.count == 80, "80 free icons are bundled (found \(Jiggicons.all.count))")
for entry in Jiggicons.all {
    guard let icon = Jiggicons.icon(named: entry.id) else { expect(false, "\(entry.id) loads"); continue }
    expect(icon.availableVariants == JiggiconVariant.allCases, "\(entry.id) has four styles")
    for variant in JiggiconVariant.allCases {
        guard let drawing = icon.drawing(for: variant) else { continue }
        expect(icon.motion[drawing.motion] != nil, "\(entry.id) \(variant) has motion")
        if let key = drawing.sound { expect(Jiggicons.soundURL(key) != nil, "\(entry.id) \(variant) sound \(key) is bundled") }
        else { expect(false, "\(entry.id) \(variant) has a sound") }
        // Every layer the drawing moves has poses that end at rest.
        for layers in icon.motion.values {
            for poses in layers {
                let end = poses.pose(at: icon.ms / 1000, fps: icon.fps)
                expect(abs(end.x) < 1e-9 && abs(end.y) < 1e-9 && abs(end.sx - 1) < 1e-9 && abs(end.o - 1) < 1e-9,
                       "\(entry.id) ends at rest")
                // A turn ends on a whole turn, or 360/n for an n-fold symmetric shape.
                let symmetric = (1...12).contains { n in
                    let unit = 360 / Double(n)
                    return abs(end.r / unit - (end.r / unit).rounded()) < 1e-6
                }
                expect(symmetric, "\(entry.id) turns end on a symmetric angle (\(end.r))")
            }
        }
    }
}
expect(Jiggicons.icon(named: "shopping-bag") == nil, "paid icons are not bundled")

// Path data.
let square = try PathData.parse("M1 1L3 1L3 3L1 3Z")
expect(square.boundingBox == CGRect(x: 1, y: 1, width: 2, height: 2), "a square path has the right bounds")
let curve = try PathData.parse("M0 0C0 -2 4 -2 4 0")
expect(abs(curve.boundingBoxOfPath.minY + 1.5) < 1e-9, "a cubic bulges to its true extreme")
expect((try? PathData.parse("M0 0Q1 1 2 2")) == nil, "only M, L, C and Z are accepted")

// Poses: the bell swings about its crown and the crown stays put.
if let bell = Jiggicons.icon(named: "bell"), let layers = bell.motion["outline"] {
    let swing = layers[0].pose(at: 0.12, fps: bell.fps)
    expect(abs(swing.r) > 5, "the bell swings (\(swing.r)°)")
    let crown = CGPoint(x: 12, y: 3.2).applying(swing.transform(about: CGPoint(x: 12, y: 3.2)))
    expect(abs(crown.x - 12) < 1e-9 && abs(crown.y - 3.2) < 1e-9, "rotation keeps its origin in place")
}

// Every bundled cue decodes, with the length its motion implies.
let sounds = Bundle.module.urls(forResourcesWithExtension: "m4a", subdirectory: "sounds") ?? []
expect(sounds.count == 220, "220 cues are bundled (found \(sounds.count))")
for url in sounds {
    let player = try? AVAudioPlayer(contentsOf: url)
    expect((player?.duration ?? 0) > 0.1 && (player?.duration ?? 9) < 2.5, "\(url.lastPathComponent) decodes (\(player?.duration ?? 0) s)")
    expect(player?.numberOfChannels == 2, "\(url.lastPathComponent) is stereo")
}

// Quick repeated taps play softer.
expect(JiggiconsAudio.gain(forInterval: 0.05) < 0.5 && JiggiconsAudio.gain(forInterval: 1) == 1, "quick taps are softer")

print(failures == 0 ? "✓ \(checks) checks passed" : "✗ \(failures) of \(checks) checks failed")
exit(failures == 0 ? 0 : 1)
