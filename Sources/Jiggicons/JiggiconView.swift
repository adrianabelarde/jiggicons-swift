import SwiftUI

public enum JiggiconTrigger: Sendable {
    /// Plays when tapped (also inside a Button, alongside its action).
    case tap
    /// Plays once when the icon appears.
    case appear
    /// Plays only when `playWhen` changes.
    case none
}

/// An animated Jiggicon. Plays its spring motion, and with `sound: true` its
/// spatial sound, when tapped (or on appear, or when `playWhen` changes).
///
///     JiggIcon("bell", variant: .solid, size: 32, sound: true)
///
/// The colour follows `.foregroundStyle` unless you pass `color`. Glass keeps
/// its own frosted greys.
public struct JiggIcon: View {
    let icon: JiggiconData?
    let variant: JiggiconVariant
    let size: CGFloat
    let color: Color?
    let sound: Bool
    let volume: Double
    let trigger: JiggiconTrigger
    let label: String?
    let playWhen: AnyHashable?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    @State private var run = 0

    /// A free icon bundled with this package, by id ("bell", "music-note-2").
    public init(_ name: String, variant: JiggiconVariant = .outline, size: CGFloat = 24, color: Color? = nil,
                sound: Bool = false, volume: Double = 1, trigger: JiggiconTrigger = .tap,
                label: String? = nil, playWhen: AnyHashable? = nil) {
        self.init(icon: Jiggicons.icon(named: name), variant: variant, size: size, color: color, sound: sound,
                  volume: volume, trigger: trigger, label: label, playWhen: playWhen)
    }

    /// Any icon in the Jiggicons mobile format (see `Jiggicons.load(contentsOf:)`).
    public init(icon: JiggiconData?, variant: JiggiconVariant = .outline, size: CGFloat = 24, color: Color? = nil,
                sound: Bool = false, volume: Double = 1, trigger: JiggiconTrigger = .tap,
                label: String? = nil, playWhen: AnyHashable? = nil) {
        self.icon = icon
        self.variant = variant
        self.size = size
        self.color = color
        self.sound = sound
        self.volume = volume
        self.trigger = trigger
        self.label = label
        self.playWhen = playWhen
    }

    public var body: some View {
        content
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { if trigger == .tap { play() } })
            .onAppear {
                guard let icon else { return }
                if sound { JiggiconsAudio.shared.preload(icon, variant: variant) }
                if trigger == .appear { play() }
            }
            .onChange(of: playWhen) { _ in play() }
            .modifier(Label(label: label))
    }

    @ViewBuilder private var content: some View {
        if let icon, let start {
            TimelineView(.animation) { timeline in
                JiggiconFrame(icon: icon, variant: variant, color: color,
                              seconds: timeline.date.timeIntervalSince(start))
            }
        } else if let icon {
            JiggiconFrame(icon: icon, variant: variant, color: color, seconds: nil)
        } else {
            Color.clear
        }
    }

    private func play() {
        guard let icon else { return }
        if sound { JiggiconsAudio.shared.play(icon, variant: variant, volume: volume) }
        guard !reduceMotion else { return }
        run += 1
        let current = run
        start = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + icon.ms / 1000 + 0.05) {
            if run == current { start = nil }
        }
    }

    private struct Label: ViewModifier {
        let label: String?
        func body(content: Content) -> some View {
            if let label {
                content.accessibilityElement().accessibilityLabel(Text(label)).accessibilityAddTraits(.isImage)
            } else {
                content.accessibilityHidden(true)
            }
        }
    }
}

/// One still frame of an icon: its rest pose (`seconds: nil`) or the pose
/// `seconds` into its motion. Fills the space it is given.
public struct JiggiconFrame: View {
    let icon: JiggiconData
    let variant: JiggiconVariant
    let color: Color?
    let seconds: Double?

    public init(icon: JiggiconData, variant: JiggiconVariant = .outline, color: Color? = nil, seconds: Double? = nil) {
        self.icon = icon
        self.variant = variant
        self.color = color
        self.seconds = seconds
    }

    public var body: some View {
        Canvas { context, size in
            JiggiconRenderer(icon: icon, variant: variant, color: color, seconds: seconds)
                .draw(in: &context, size: size)
        }
    }
}
