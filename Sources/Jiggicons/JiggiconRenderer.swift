import SwiftUI

/// Draws one frame of an icon into a SwiftUI GraphicsContext.
struct JiggiconRenderer {
    let icon: JiggiconData
    let variant: JiggiconVariant
    let color: Color?
    let seconds: Double?

    func draw(in context: inout GraphicsContext, size: CGSize) {
        guard let drawing = icon.drawing(for: variant) else { return }
        let side = min(size.width, size.height)
        var root = context
        root.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
        root.scaleBy(x: side / 24, y: side / 24)
        let poses = posesNow(drawing)
        let scene = Scene(drawing: drawing, poses: poses, color: color, scale: side / 24)
        scene.draw(drawing.nodes, in: root)
    }

    private func posesNow(_ drawing: Drawing) -> [Pose?] {
        guard let seconds, seconds >= 0, seconds * 1000 < icon.ms,
              let layers = icon.motion[drawing.motion] ?? icon.motion["outline"] else { return [] }
        return layers.map { $0.isStill ? nil : $0.pose(at: seconds, fps: icon.fps) }
    }

    private struct Scene {
        let drawing: Drawing
        let poses: [Pose?]
        let color: Color?
        let scale: CGFloat

        func draw(_ nodes: [Node], in context: GraphicsContext, mask: Bool = false) {
            for node in nodes {
                switch node {
                case .group(let group): draw(group, in: context, mask: mask)
                case .path(let path): draw(path, in: context, mask: mask)
                }
            }
        }

        private func draw(_ group: Group, in parent: GraphicsContext, mask: Bool) {
            var context = parent
            if let layer = group.layer, layer < poses.count, let pose = poses[layer] {
                context.concatenate(pose.transform(about: group.origin))
                context.opacity *= pose.o
            }
            if let opacity = group.opacity { context.opacity *= opacity }
            if let blur = group.blur {
                // The blur's radius is in the context's own units, which here
                // are the 24-unit artboard, like the SVG's standard deviation.
                context.addFilter(.blur(radius: blur))
            }
            if let index = group.mask, index < drawing.masks.count {
                let shapes = drawing.masks[index]
                context.drawLayer { layer in
                    draw(group.children, in: layer, mask: mask)
                    // Keep only what the mask's white shapes cover, minus its black ones.
                    var keep = layer
                    keep.blendMode = .destinationIn
                    keep.drawLayer { maskLayer in draw(shapes, in: maskLayer, mask: true) }
                }
            } else if group.blur != nil {
                context.drawLayer { layer in draw(group.children, in: layer, mask: mask) }
            } else {
                draw(group.children, in: context, mask: mask)
            }
        }

        private func draw(_ node: PathNode, in parent: GraphicsContext, mask: Bool) {
            var context = parent
            let path = Path(node.path)
            if mask {
                // Mask shapes: white keeps, black cuts.
                if case .color(let rgb) = node.fill, rgb.red < 0.5 { context.blendMode = .destinationOut }
                context.fill(path, with: .color(.white), style: FillStyle(eoFill: node.evenOdd))
                return
            }
            if let fill = node.fill {
                var filling = context
                filling.opacity *= node.fillOpacity
                filling.fill(path, with: shading(fill), style: FillStyle(eoFill: node.evenOdd))
            }
            if let stroke = node.stroke {
                context.stroke(path, with: shading(stroke),
                               style: StrokeStyle(lineWidth: node.strokeWidth, lineCap: node.cap, lineJoin: node.join))
            }
        }

        private func shading(_ paint: Paint) -> GraphicsContext.Shading {
            switch paint {
            case .current:
                return color.map { .color($0) } ?? .foreground
            case .color(let rgb):
                return .color(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
            case .gradient(let index):
                guard index < drawing.gradients.count else { return .color(.clear) }
                let gradient = drawing.gradients[index]
                let stops = gradient.stops.map {
                    SwiftUI.Gradient.Stop(color: Color(red: $0.color.red, green: $0.color.green, blue: $0.color.blue).opacity($0.opacity),
                                          location: $0.offset)
                }
                return .linearGradient(SwiftUI.Gradient(stops: stops),
                                       startPoint: CGPoint(x: gradient.x1, y: gradient.y1),
                                       endPoint: CGPoint(x: gradient.x2, y: gradient.y2))
            }
        }
    }
}
