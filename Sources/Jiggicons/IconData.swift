// The icon data the Jiggicons build writes for native platforms: a normalized
// drawing per variant (paths with only M, L, C and Z, already-resolved
// styles, gradients, masks and blur) and the spring motion baked into poses
// at 60 frames a second. See tools/mobile-drawing.mjs.
import Foundation
@preconcurrency import CoreGraphics

public enum JiggiconVariant: String, CaseIterable, Sendable {
    case outline, solid, duotone, glass
}

public struct JiggiconData: Decodable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    /// Length of the motion in milliseconds.
    public let ms: Double
    let fps: Double
    let variants: [String: Drawing]
    let motion: [String: [LayerPoses]]

    public var availableVariants: [JiggiconVariant] {
        JiggiconVariant.allCases.filter { variants[$0.rawValue] != nil }
    }

    func drawing(for variant: JiggiconVariant) -> Drawing? {
        variants[variant.rawValue] ?? availableVariants.first.flatMap { variants[$0.rawValue] }
    }

    func soundKey(for variant: JiggiconVariant) -> String? {
        drawing(for: variant)?.sound
    }
}

struct Drawing: Decodable, Sendable {
    let nodes: [Node]
    let gradients: [Gradient]
    let masks: [[Node]]
    let motion: String
    let sound: String?
}

struct Gradient: Decodable, Sendable {
    let x1: Double, y1: Double, x2: Double, y2: Double
    /// [offset, "#rrggbb", opacity]
    let stops: [Stop]

    struct Stop: Decodable, Sendable {
        let offset: Double
        let color: RGB
        let opacity: Double

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            offset = try container.decode(Double.self)
            color = try RGB(hex: container.decode(String.self))
            opacity = try container.decode(Double.self)
        }
    }
}

struct RGB: Sendable, Equatable {
    let red: Double, green: Double, blue: Double

    init(hex: String) throws {
        guard hex.count == 7, hex.first == "#", let value = UInt32(hex.dropFirst(), radix: 16) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Bad colour \(hex)"))
        }
        red = Double((value >> 16) & 0xff) / 255
        green = Double((value >> 8) & 0xff) / 255
        blue = Double(value & 0xff) / 255
    }
}

enum Paint: Sendable, Equatable {
    case current
    case color(RGB)
    case gradient(Int)

    init(_ text: String) throws {
        if text == "c" { self = .current }
        else if text.hasPrefix("@"), let index = Int(text.dropFirst()) { self = .gradient(index) }
        else { self = .color(try RGB(hex: text)) }
    }
}

enum Node: Decodable, Sendable {
    case group(Group)
    case path(PathNode)

    private enum Keys: String, CodingKey { case g, d }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        if container.contains(.g) { self = .group(try Group(from: decoder)) }
        else { self = .path(try PathNode(from: decoder)) }
    }
}

struct Group: Decodable, Sendable {
    let children: [Node]
    let layer: Int?
    let origin: CGPoint
    let mask: Int?
    let blur: Double?
    let opacity: Double?

    private enum Keys: String, CodingKey { case g, layer, origin, mask, blur, opacity }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        children = try container.decode([Node].self, forKey: .g)
        layer = try container.decodeIfPresent(Int.self, forKey: .layer)
        let point = try container.decodeIfPresent([Double].self, forKey: .origin) ?? [12, 12]
        origin = CGPoint(x: point[0], y: point[1])
        mask = try container.decodeIfPresent(Int.self, forKey: .mask)
        blur = try container.decodeIfPresent(Double.self, forKey: .blur)
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity)
    }
}

struct PathNode: Decodable, Sendable {
    let path: CGPath
    let fill: Paint?
    let evenOdd: Bool
    let fillOpacity: Double
    let stroke: Paint?
    let strokeWidth: Double
    let cap: CGLineCap
    let join: CGLineJoin

    private enum Keys: String, CodingKey { case d, fill, rule, fo, stroke, sw, cap, join }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        path = try PathData.parse(container.decode(String.self, forKey: .d))
        fill = try container.decodeIfPresent(String.self, forKey: .fill).map(Paint.init)
        evenOdd = try container.decodeIfPresent(String.self, forKey: .rule) == "evenodd"
        fillOpacity = try container.decodeIfPresent(Double.self, forKey: .fo) ?? 1
        stroke = try container.decodeIfPresent(String.self, forKey: .stroke).map(Paint.init)
        strokeWidth = try container.decodeIfPresent(Double.self, forKey: .sw) ?? 1
        switch try container.decodeIfPresent(String.self, forKey: .cap) {
        case "round": cap = .round
        case "square": cap = .square
        default: cap = .butt
        }
        switch try container.decodeIfPresent(String.self, forKey: .join) {
        case "round": join = .round
        case "bevel": join = .bevel
        default: join = .miter
        }
    }
}

/// The pose components that move for one rig layer, sampled at `fps`.
struct LayerPoses: Decodable, Sendable {
    let x: [Double]?, y: [Double]?, r: [Double]?, sx: [Double]?, sy: [Double]?, o: [Double]?

    var isStill: Bool { x == nil && y == nil && r == nil && sx == nil && sy == nil && o == nil }
}

struct Pose: Equatable {
    var x = 0.0, y = 0.0, r = 0.0, sx = 1.0, sy = 1.0, o = 1.0

    /// Translate, rotate and scale about `origin`, as CSS applies them.
    func transform(about origin: CGPoint) -> CGAffineTransform {
        let angle = r * .pi / 180
        let a = cos(angle) * sx, b = sin(angle) * sx, c = -sin(angle) * sy, d = cos(angle) * sy
        return CGAffineTransform(a: a, b: b, c: c, d: d,
                                 tx: origin.x + x - (a * origin.x + c * origin.y),
                                 ty: origin.y + y - (b * origin.x + d * origin.y))
    }
}

extension LayerPoses {
    /// The pose `seconds` into the motion, interpolated between frames.
    func pose(at seconds: Double, fps: Double) -> Pose {
        func sample(_ values: [Double]?, _ rest: Double) -> Double {
            guard let values, !values.isEmpty else { return rest }
            let position = max(0, seconds * fps)
            let low = min(Int(position), values.count - 1)
            let high = min(low + 1, values.count - 1)
            let mix = position - Double(low)
            return values[low] + (values[high] - values[low]) * min(1, mix)
        }
        return Pose(x: sample(x, 0), y: sample(y, 0), r: sample(r, 0),
                    sx: sample(sx, 1), sy: sample(sy, 1), o: min(1, max(0, sample(o, 1))))
    }
}

/// Reads path data that uses only absolute M, L, C and Z.
enum PathData {
    static func parse(_ text: String) throws -> CGPath {
        let path = CGMutablePath()
        var numbers: [Double] = []
        var command: Character?
        var token = ""

        func flushNumber() throws {
            guard !token.isEmpty else { return }
            guard let value = Double(token) else { throw error("bad number \(token)") }
            numbers.append(value)
            token = ""
        }
        func flushCommand() throws {
            try flushNumber()
            guard let command else { return }
            switch command {
            case "M", "L":
                guard numbers.count == 2 else { throw error("\(command) needs 2 numbers") }
                let point = CGPoint(x: numbers[0], y: numbers[1])
                if command == "M" { path.move(to: point) } else { path.addLine(to: point) }
            case "C":
                guard numbers.count == 6 else { throw error("C needs 6 numbers") }
                path.addCurve(to: CGPoint(x: numbers[4], y: numbers[5]),
                              control1: CGPoint(x: numbers[0], y: numbers[1]),
                              control2: CGPoint(x: numbers[2], y: numbers[3]))
            case "Z":
                path.closeSubpath()
            default:
                throw error("unsupported command \(command)")
            }
            numbers.removeAll(keepingCapacity: true)
        }
        func error(_ message: String) -> Error {
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Path data: \(message)"))
        }

        for character in text {
            switch character {
            case "M", "L", "C", "Z":
                try flushCommand()
                command = character
            case " ", ",":
                try flushNumber()
            case "-":
                try flushNumber()
                token.append(character)
            default:
                token.append(character)
            }
        }
        try flushCommand()
        return path
    }
}
