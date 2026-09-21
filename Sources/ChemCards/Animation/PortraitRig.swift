import SwiftUI

/// 立绘情绪。事件驱动，座位视图按最近一次事件切换
enum RigMood: Equatable {
    case idle
    case play
    case pressed
    case draw
    case win

    var scale: CGFloat {
        switch self {
        case .idle: return 1.0
        case .play: return 1.06
        case .pressed: return 0.95
        case .draw: return 1.02
        case .win: return 1.12
        }
    }

    var tilt: Double {
        switch self {
        case .idle: return 0
        case .play: return -2.5
        case .pressed: return 3.5
        case .draw: return -1
        case .win: return -4
        }
    }

    var blush: Double {
        switch self {
        case .idle, .draw: return 0.18
        case .play: return 0.42
        case .pressed: return 0.5
        case .win: return 0.65
        }
    }
}

/// 一帧的形变参数，全部由时间函数算出，没有独立动画循环
struct RigParameters: Equatable {
    var breath: CGFloat = 0
    var bob: CGFloat = 0
    var sway: CGFloat = 0
    var blinking = false
    var mouth = 0
    var hairSway: CGFloat = 0
    var scale: CGFloat = 1
    var tilt: Double = 0
    var blushOpacity: Double = 0.18
}

enum RigDriver {

    /// 纯函数：时间 + 情绪 → 形参。时钟由最外层的叶子 TimelineView 提供，
    /// 每帧只有立绘这一子树重算，牌桌其余部分不参与
    static func parameters(character: CharacterID,
                           mood: RigMood,
                           time: Double,
                           talking: Bool,
                           motion: Bool) -> RigParameters {
        let spec = CharacterSpec(character)
        guard motion else { return RigParameters(scale: mood.scale, tilt: 0, blushOpacity: mood.blush) }

        let t = time + spec.phase
        var params = RigParameters()
        params.breath = CGFloat(sin(t * 1.35))
        params.bob = CGFloat(sin(t * 1.35) * 1.6)
        params.sway = CGFloat(sin(t * 0.52) * 2.2)
        params.hairSway = CGFloat(sin(t * 0.9 + 0.7) * 3.0)

        // 眨眼：周期与角色绑定，闭眼只持续 120ms
        let cycle = t.truncatingRemainder(dividingBy: spec.blinkPeriod)
        params.blinking = cycle < 0.12

        // 说话时口型 4 帧循环，安静时闭合成一条微笑
        params.mouth = talking ? Int(t * 9.0) % 4 : 0

        params.scale = mood.scale
        params.tilt = mood.tilt
        params.blushOpacity = mood.blush
        return params
    }
}

/// 伪 Live2D 立绘：有分层素材就分层驱动，只有 base 就整体变换，什么都没有就画程序化 Q 版头像
struct PortraitRig: View {
    let character: CharacterID
    var mood: RigMood = .idle
    var talking = false
    var size: CGFloat
    var time: Double
    var reduceMotion = false

    var body: some View {
        let params = RigDriver.parameters(character: character,
                                          mood: mood,
                                          time: time,
                                          talking: talking,
                                          motion: !reduceMotion)
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(LinearGradient(colors: [CharacterSpec(character).accent.opacity(0.30),
                                              SwiftUI.Color(white: 0.08)],
                                     startPoint: .top, endPoint: .bottom))

            if AssetLoader.portrait(character) != nil {
                layeredPortrait(params: params)
            } else {
                ProceduralFace(character: character, params: params, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .strokeBorder(CharacterSpec(character).accent.opacity(0.55), lineWidth: 1.2)
        )
    }

    private func layeredPortrait(params: RigParameters) -> some View {
        let layers = AssetLoader.availableLayers(character)
        return ZStack {
            layer("base", params: params, scale: 1 + params.breath * 0.010)
            if layers.contains("sleeve_l") {
                layer("sleeve_l", params: params, scale: 1).offset(x: params.hairSway * 0.6, y: params.hairSway * 0.2)
            }
            if layers.contains("sleeve_r") {
                layer("sleeve_r", params: params, scale: 1).offset(x: -params.hairSway * 0.6, y: params.hairSway * 0.2)
            }
            if layers.contains("hair_front") {
                layer("hair_front", params: params, scale: 1).offset(x: params.hairSway, y: params.bob * 0.4)
            }
            if layers.contains("eyes_open") || layers.contains("eyes_close") {
                layer(params.blinking ? "eyes_close" : "eyes_open", params: params, scale: 1)
            }
            if layers.contains("mouth_0") {
                layer("mouth_\(params.mouth % max(1, mouthCount(layers)))", params: params, scale: 1)
            }
            if layers.contains("blush") {
                layer("blush", params: params, scale: 1).opacity(params.blushOpacity)
            }
        }
    }

    private func mouthCount(_ layers: Set<String>) -> Int {
        (0..<4).filter { layers.contains("mouth_\($0)") }.count
    }

    @ViewBuilder
    private func layer(_ name: String, params: RigParameters, scale: CGFloat) -> some View {
        if let image = AssetLoader.portrait(character, layer: name) {
            image
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .scaleEffect(scale)
                .rotationEffect(.degrees(params.tilt * 0.4))
                .offset(x: params.sway * 0.5, y: params.bob * 0.5)
        }
    }
}

/// 程序化 Q 版头像：无素材也能演出呼吸、眨眼、说话口型和情绪
struct ProceduralFace: View {
    let character: CharacterID
    let params: RigParameters
    var size: CGFloat

    var body: some View {
        Canvas { context, box in
            let spec = CharacterSpec(character)
            let u = min(box.width, box.height)
            let center = CGPoint(x: box.width / 2 + params.sway,
                                 y: box.height / 2 + params.bob)
            let k = u * 0.5 * params.scale
            let head = CGSize(width: k * 0.74, height: k * 0.72)
            let headCenter = CGPoint(x: center.x, y: center.y - k * 0.08)

            drawShoulders(context, center: center, head: head, spec: spec)
            drawBackHair(context, center: headCenter, head: head, spec: spec)
            drawHead(context, center: headCenter, head: head, params: params)
            drawFringe(context, center: headCenter, head: head, params: params, spec: spec)
            drawEyes(context, center: headCenter, head: head, params: params, spec: spec)
            drawMouth(context, center: headCenter, head: head, params: params)
            drawBlush(context, center: headCenter, head: head, params: params)
            drawAccessory(context, center: headCenter, head: head, spec: spec)
        }
        .frame(width: size, height: size)
    }

    private func ellipse(_ center: CGPoint, _ size: CGSize) -> Path {
        Path(ellipseIn: CGRect(x: center.x - size.width / 2,
                               y: center.y - size.height / 2,
                               width: size.width, height: size.height))
    }

    private func drawShoulders(_ ctx: GraphicsContext, center: CGPoint, head: CGSize, spec: CharacterSpec) {
        let width = head.width * 1.9
        let rect = CGRect(x: center.x - width / 2, y: center.y + head.height * 0.66,
                          width: width, height: head.height * 1.4)
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: width * 0.45, height: width * 0.45))
        ctx.fill(path, with: .linearGradient(
            Gradient(colors: [spec.accent.opacity(0.95), spec.accent.opacity(0.45)]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        // 领口
        var collar = Path()
        collar.move(to: CGPoint(x: center.x - width * 0.16, y: rect.minY))
        collar.addLine(to: CGPoint(x: center.x, y: rect.minY + head.height * 0.34))
        collar.addLine(to: CGPoint(x: center.x + width * 0.16, y: rect.minY))
        collar.closeSubpath()
        ctx.fill(collar, with: .color(.white.opacity(0.85)))
    }

    private func drawBackHair(_ ctx: GraphicsContext, center: CGPoint, head: CGSize, spec: CharacterSpec) {
        ctx.fill(ellipse(center, CGSize(width: head.width * 1.16, height: head.height * 1.14)),
                 with: .color(spec.hairShade))
    }

    private func drawHead(_ ctx: GraphicsContext, center: CGPoint, head: CGSize, params: RigParameters) {
        ctx.fill(ellipse(center, head),
                 with: .radialGradient(Gradient(colors: [CharacterSpec.skin, CharacterSpec.skinShade]),
                                       center: CGPoint(x: center.x - head.width * 0.12, y: center.y - head.height * 0.16),
                                       startRadius: 1, endRadius: head.width))
    }

    private func drawFringe(_ ctx: GraphicsContext, center: CGPoint, head: CGSize, params: RigParameters, spec: CharacterSpec) {
        var fringe = Path()
        let r = head.width / 2
        fringe.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        let step = head.width / 3.4
        var x = center.x + r
        let y = center.y + head.height * 0.06
        for index in 0..<3 {
            let nextX = x - step
            fringe.addLine(to: CGPoint(x: nextX + step * 0.42,
                                       y: y + (index.isMultiple(of: 2) ? head.height * 0.20 : head.height * 0.05)))
            fringe.addLine(to: CGPoint(x: nextX, y: y))
            x = nextX
        }
        fringe.closeSubpath()
        ctx.fill(fringe, with: .linearGradient(Gradient(colors: [spec.hair, spec.hairShade]),
                                               startPoint: CGPoint(x: center.x, y: center.y - r),
                                               endPoint: CGPoint(x: center.x, y: center.y + r)))
    }

    private func drawEyes(_ ctx: GraphicsContext, center: CGPoint, head: CGSize, params: RigParameters, spec: CharacterSpec) {
        let dx = head.width * 0.20
        let eyeY = center.y + head.height * 0.12
        let eyeSize = CGSize(width: head.width * 0.15, height: params.blinking ? head.height * 0.015 : head.height * 0.23)
        for sign in [-1.0, 1.0] {
            let point = CGPoint(x: center.x + CGFloat(sign) * dx, y: eyeY)
            ctx.fill(ellipse(point, eyeSize), with: .color(spec.eye))
            if !params.blinking {
                ctx.fill(ellipse(CGPoint(x: point.x - eyeSize.width * 0.18, y: point.y - eyeSize.height * 0.26),
                                 CGSize(width: eyeSize.width * 0.42, height: eyeSize.height * 0.34)),
                         with: .color(.white.opacity(0.92)))
            }
            // 眉毛跟着情绪抬一点
            var brow = Path()
            brow.move(to: CGPoint(x: point.x - eyeSize.width * 0.62, y: point.y - eyeSize.height * 0.72))
            brow.addQuadCurve(to: CGPoint(x: point.x + eyeSize.width * 0.62, y: point.y - eyeSize.height * 0.70),
                              control: CGPoint(x: point.x, y: point.y - eyeSize.height * 0.98 - params.breath * 0.6))
            ctx.stroke(brow, with: .color(spec.hairShade), lineWidth: head.width * 0.026)
        }
    }

    private func drawMouth(_ ctx: GraphicsContext, center: CGPoint, head: CGSize, params: RigParameters) {
        let point = CGPoint(x: center.x, y: center.y + head.height * 0.36)
        let width = head.width * 0.22
        if params.mouth == 0 {
            var smile = Path()
            smile.move(to: CGPoint(x: point.x - width / 2, y: point.y))
            smile.addQuadCurve(to: CGPoint(x: point.x + width / 2, y: point.y),
                               control: CGPoint(x: point.x, y: point.y + width * 0.42))
            ctx.stroke(smile, with: .color(SwiftUI.Color(red: 0.72, green: 0.34, blue: 0.34)),
                       style: StrokeStyle(lineWidth: head.width * 0.028, lineCap: .round))
        } else {
            let open = head.height * 0.06 * CGFloat(params.mouth)
            ctx.fill(ellipse(point, CGSize(width: width, height: open)),
                     with: .color(SwiftUI.Color(red: 0.62, green: 0.26, blue: 0.28)))
        }
    }

    private func drawBlush(_ ctx: GraphicsContext, center: CGPoint, head: CGSize, params: RigParameters) {
        guard params.blushOpacity > 0.02 else { return }
        let dx = head.width * 0.31
        for sign in [-1.0, 1.0] {
            let spot = CGSize(width: head.width * 0.20, height: head.height * 0.11)
            ctx.fill(ellipse(CGPoint(x: center.x + CGFloat(sign) * dx, y: center.y + head.height * 0.20), spot),
                     with: .color(CharacterSpec.blush.opacity(params.blushOpacity)))
        }
    }

    private func drawAccessory(_ ctx: GraphicsContext, center: CGPoint, head: CGSize, spec: CharacterSpec) {
        let r = head.width / 2
        switch spec.hairStyle {
        case .ribbon:
            let knot = CGPoint(x: center.x + r * 0.92, y: center.y - r * 0.55)
            for sign in [-1.0, 1.0] {
                var wing = Path()
                wing.move(to: knot)
                wing.addLine(to: CGPoint(x: knot.x + CGFloat(sign) * r * 0.52, y: knot.y - r * 0.30))
                wing.addLine(to: CGPoint(x: knot.x + CGFloat(sign) * r * 0.52, y: knot.y + r * 0.30))
                wing.closeSubpath()
                ctx.fill(wing, with: .color(SwiftUI.Color(red: 0.94, green: 0.24, blue: 0.28)))
            }
            ctx.fill(ellipse(knot, CGSize(width: r * 0.26, height: r * 0.26)),
                     with: .color(SwiftUI.Color(red: 0.80, green: 0.16, blue: 0.20)))
        case .hat:
            let top = CGPoint(x: center.x, y: center.y - r * 1.02)
            var cone = Path()
            cone.move(to: CGPoint(x: top.x - r * 0.86, y: top.y + r * 0.10))
            cone.addLine(to: CGPoint(x: top.x + r * 0.10, y: top.y - r * 0.92))
            cone.addLine(to: CGPoint(x: top.x + r * 0.86, y: top.y + r * 0.10))
            cone.closeSubpath()
            ctx.fill(cone, with: .color(SwiftUI.Color(white: 0.13)))
            ctx.fill(ellipse(CGPoint(x: top.x, y: top.y + r * 0.10), CGSize(width: r * 2.05, height: r * 0.36)),
                     with: .color(.white.opacity(0.92)))
            ctx.fill(star(at: CGPoint(x: top.x + r * 0.02, y: top.y - r * 0.34), radius: r * 0.20),
                     with: .color(SwiftUI.Color(red: 0.98, green: 0.82, blue: 0.28)))
        case .sideBraid:
            let anchor = CGPoint(x: center.x - r * 0.95, y: center.y - r * 0.30)
            var braid = Path()
            braid.addRoundedRect(in: CGRect(x: anchor.x - r * 0.20, y: anchor.y, width: r * 0.40, height: r * 1.75),
                                 cornerSize: CGSize(width: r * 0.20, height: r * 0.20))
            ctx.fill(braid, with: .color(spec.hair))
            ctx.fill(ellipse(CGPoint(x: anchor.x, y: anchor.y + r * 1.78), CGSize(width: r * 0.34, height: r * 0.34)),
                     with: .color(spec.accent))
            ctx.fill(ellipse(anchor, CGSize(width: r * 0.30, height: r * 0.30)),
                     with: .color(SwiftUI.Color(red: 0.30, green: 0.75, blue: 0.60)))
        case .longBraid:
            let anchor = CGPoint(x: center.x + r * 0.98, y: center.y - r * 0.18)
            var braid = Path()
            braid.addRoundedRect(in: CGRect(x: anchor.x - r * 0.16, y: anchor.y, width: r * 0.34, height: r * 2.05),
                                 cornerSize: CGSize(width: r * 0.17, height: r * 0.17))
            ctx.fill(braid, with: .linearGradient(Gradient(colors: [spec.hair, spec.hairShade]),
                                                  startPoint: anchor,
                                                  endPoint: CGPoint(x: anchor.x, y: anchor.y + r * 2.0)))
            ctx.fill(ellipse(CGPoint(x: anchor.x + r * 0.02, y: anchor.y - r * 0.16),
                             CGSize(width: r * 0.30, height: r * 0.30)),
                     with: .color(SwiftUI.Color(red: 0.96, green: 0.80, blue: 0.30)))
        }
    }

    private func star(at center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for index in 0..<10 {
            let angle = Double(index) * .pi / 5 - .pi / 2
            let length = index.isMultiple(of: 2) ? radius : radius * 0.45
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * length,
                                y: center.y + CGFloat(sin(angle)) * length)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
