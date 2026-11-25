// Every free Jiggicon in a window. Tap one to play its motion and sound.
//   swift run JiggiconsDemo
//   swift run JiggiconsDemo --render <folder>   writes PNG frames of a few icons
import AppKit
import Jiggicons
import SwiftUI

struct DemoView: View {
    @State private var variant: JiggiconVariant = .outline
    @State private var sound = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Picker("Style", selection: $variant) {
                    ForEach(JiggiconVariant.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                Toggle("Sound", isOn: $sound)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 20) {
                    ForEach(Jiggicons.all, id: \.self) { entry in
                        VStack(spacing: 8) {
                            JiggIcon(entry.id, variant: variant, size: 40, sound: sound, label: entry.name)
                            Text(entry.id).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 520)
    }
}

struct DemoApp: App {
    var body: some Scene {
        WindowGroup("Jiggicons") { DemoView() }
    }
}

@available(macOS 13, *)
@MainActor
func render(to folder: URL) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let ink = Color(red: 0.09, green: 0.09, blue: 0.09)
    let shots: [(String, JiggiconVariant, Double?)] = [
        ("bell", .outline, nil), ("bell", .outline, 0.12), ("bell", .outline, 0.3), ("bell", .duotone, nil),
        ("heart", .glass, nil), ("heart", .glass, 0.15), ("windmill", .glass, nil), ("camera", .glass, nil),
        ("rocket", .solid, nil), ("rocket", .solid, 0.3), ("camera", .duotone, nil), ("gift", .solid, 0.2),
    ]
    let sheet = VStack(spacing: 0) {
        ForEach(0..<3) { row in
            HStack(spacing: 0) {
                ForEach(0..<4) { column in
                    let (name, variant, time) = shots[row * 4 + column]
                    if let icon = Jiggicons.icon(named: name) {
                        JiggiconFrame(icon: icon, variant: variant, color: ink, seconds: time)
                            .frame(width: 128, height: 128).padding(16)
                    }
                }
            }
        }
    }.background(Color.white)
    let renderer = ImageRenderer(content: sheet)
    renderer.scale = 1
    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    let file = folder.appendingPathComponent("sheet.png")
    try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: file)
    print("wrote", file.path)
}

// Icons the CLI added (`npx jiggicons add <icon> --format swift`), in all four
// styles at rest and mid-motion:
//   swift run JiggiconsDemo --render <folder> --added <the CLI's folder> --icons search,shopping-bag
@available(macOS 13, *)
@MainActor
func renderAdded(_ names: [String], from added: URL, to folder: URL) throws {
    Jiggicons.register(folder: added)
    let ink = Color(red: 0.09, green: 0.09, blue: 0.09)
    let sheet = VStack(spacing: 0) {
        ForEach(names, id: \.self) { name in
            HStack(spacing: 0) {
                ForEach(JiggiconVariant.allCases, id: \.self) { variant in
                    ForEach([nil, 0.15] as [Double?], id: \.self) { time in
                        if let icon = Jiggicons.icon(named: name) {
                            JiggiconFrame(icon: icon, variant: variant, color: ink, seconds: time)
                                .frame(width: 96, height: 96).padding(12)
                        }
                    }
                }
            }
        }
    }.background(Color.white)
    let renderer = ImageRenderer(content: sheet)
    renderer.scale = 1
    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    let file = folder.appendingPathComponent("added.png")
    try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: file)
    print("wrote", file.path)
}

let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--render"), index + 1 < arguments.count {
    if #available(macOS 13, *) {
        try MainActor.assumeIsolated {
            let folder = URL(fileURLWithPath: arguments[index + 1])
            try render(to: folder)
            if let added = arguments.firstIndex(of: "--added"), added + 1 < arguments.count,
               let icons = arguments.firstIndex(of: "--icons"), icons + 1 < arguments.count {
                try renderAdded(arguments[icons + 1].split(separator: ",").map(String.init),
                                from: URL(fileURLWithPath: arguments[added + 1]), to: folder)
            }
        }
    } else {
        print("Rendering frames needs macOS 13")
    }
} else {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
    DemoApp.main()
}
