import SwiftUI

struct StickDuelerAvatarView: View {
    var style: AvatarStyle
    var size: CGFloat = 56
    var initials: String? = nil

    private var lineWidth: CGFloat { max(2, size * 0.055) }
    private var scale: CGFloat { size / 100 }

    var body: some View {
        ZStack {
            auraView
            Circle()
                .fill(AppTheme.brandGradient.opacity(0.76))
                .overlay(Circle().stroke(Color.white.opacity(0.32), lineWidth: max(1, size * 0.025)))
            dueler
        }
        .frame(width: size, height: size)
        .shadow(color: auraColor.opacity(style.aura == "avatar_aura_none" ? 0.22 : 0.55), radius: size * 0.16)
        .accessibilityLabel("Stick Dueler avatar")
    }

    private var dueler: some View {
        ZStack {
            outfitBack
            bodyLines
            outfitFront
            face
            headwear
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var auraView: some View {
        switch style.aura {
        case "avatar_aura_teal":
            Circle().fill(AppTheme.teal.opacity(0.25)).blur(radius: size * 0.12)
        case "avatar_aura_pink":
            Circle().fill(AppTheme.hotPink.opacity(0.28)).blur(radius: size * 0.12)
        case "avatar_aura_crown":
            Circle().fill(AppTheme.crownGold.opacity(0.26)).blur(radius: size * 0.14)
        case "avatar_aura_storm":
            Circle().stroke(AppTheme.royalBlue.opacity(0.85), lineWidth: max(2, size * 0.045)).rotationEffect(.degrees(-14))
                .overlay(Circle().stroke(AppTheme.hotPink.opacity(0.75), lineWidth: max(1, size * 0.025)).scaleEffect(0.82))
        default:
            Circle().fill(Color.white.opacity(0.04))
        }
    }

    private var bodyLines: some View {
        Canvas { context, _ in
            var path = Path()
            let head = CGPoint(x: 50 * scale, y: 30 * scale)
            let neck = CGPoint(x: 50 * scale, y: 42 * scale)
            let hip = CGPoint(x: 50 * scale, y: 64 * scale)
            let leftHand = point(x: leftArmEnd.x, y: leftArmEnd.y)
            let rightHand = point(x: rightArmEnd.x, y: rightArmEnd.y)
            let leftFoot = point(x: leftLegEnd.x, y: leftLegEnd.y)
            let rightFoot = point(x: rightLegEnd.x, y: rightLegEnd.y)

            path.addEllipse(in: CGRect(x: head.x - 10 * scale, y: head.y - 10 * scale, width: 20 * scale, height: 20 * scale))
            path.move(to: neck)
            path.addLine(to: hip)
            path.move(to: CGPoint(x: 50 * scale, y: 47 * scale))
            path.addLine(to: leftHand)
            path.move(to: CGPoint(x: 50 * scale, y: 47 * scale))
            path.addLine(to: rightHand)
            path.move(to: hip)
            path.addLine(to: leftFoot)
            path.move(to: hip)
            path.addLine(to: rightFoot)

            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    @ViewBuilder
    private var face: some View {
        switch style.face {
        case "avatar_face_focused":
            faceText("• •", y: 28, size: 10)
            faceLine(y: 35, width: 9)
        case "avatar_face_wink":
            faceText("• -", y: 28, size: 10)
            faceText("⌣", y: 35, size: 10)
        case "avatar_face_shades":
            RoundedRectangle(cornerRadius: 2).fill(Color.black.opacity(0.82)).frame(width: 20 * scale, height: 6 * scale).offset(y: -20 * scale)
            faceText("⌣", y: 35, size: 10)
        case "avatar_face_gem":
            HStack(spacing: 4 * scale) {
                Diamond().fill(AppTheme.hotPink).frame(width: 5 * scale, height: 7 * scale)
                Diamond().fill(AppTheme.hotPink).frame(width: 5 * scale, height: 7 * scale)
            }
            .offset(y: -20 * scale)
            faceText("⌣", y: 35, size: 10)
        default:
            faceText("• •", y: 28, size: 10)
            faceText("⌣", y: 35, size: 10)
        }
    }

    @ViewBuilder
    private var headwear: some View {
        switch style.head {
        case "avatar_head_crown":
            CrownShape().fill(AppTheme.crownGold).frame(width: 27 * scale, height: 18 * scale).offset(y: -34 * scale)
                .overlay(Diamond().fill(AppTheme.hotPink).frame(width: 5 * scale, height: 8 * scale).offset(y: -31 * scale))
        case "avatar_head_headphones":
            Circle().trim(from: 0.55, to: 0.95).stroke(AppTheme.teal, lineWidth: lineWidth).frame(width: 30 * scale, height: 30 * scale).offset(y: -20 * scale)
            HStack(spacing: 19 * scale) {
                Capsule().fill(AppTheme.teal).frame(width: 5 * scale, height: 12 * scale)
                Capsule().fill(AppTheme.teal).frame(width: 5 * scale, height: 12 * scale)
            }.offset(y: -17 * scale)
        case "avatar_head_wizard":
            Triangle().fill(AppTheme.royalBlue).frame(width: 30 * scale, height: 28 * scale).offset(y: -38 * scale)
                .overlay(Circle().fill(AppTheme.crownGold).frame(width: 5 * scale, height: 5 * scale).offset(y: -47 * scale))
        case "avatar_head_lightning":
            LightningShape().fill(AppTheme.crownGold).frame(width: 23 * scale, height: 29 * scale).offset(x: 5 * scale, y: -32 * scale)
        case "avatar_head_halo":
            Ellipse().stroke(AppTheme.crownGold, lineWidth: lineWidth).frame(width: 31 * scale, height: 10 * scale).offset(y: -38 * scale)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var outfitBack: some View {
        if style.outfit == "avatar_outfit_cape" || style.outfit == "avatar_outfit_royal" {
            Triangle().fill(outfitColor.opacity(0.82)).frame(width: 43 * scale, height: 48 * scale).offset(y: 20 * scale)
        }
    }

    @ViewBuilder
    private var outfitFront: some View {
        switch style.outfit {
        case "avatar_outfit_hoodie":
            RoundedRectangle(cornerRadius: 7 * scale).stroke(outfitColor, lineWidth: lineWidth).frame(width: 26 * scale, height: 26 * scale).offset(y: 18 * scale)
        case "avatar_outfit_armor":
            ShieldShape().fill(outfitColor.opacity(0.9)).frame(width: 26 * scale, height: 31 * scale).offset(y: 19 * scale)
                .overlay(ShieldShape().stroke(Color.white.opacity(0.88), lineWidth: max(1, lineWidth * 0.55)).frame(width: 26 * scale, height: 31 * scale).offset(y: 19 * scale))
        case "avatar_outfit_neon":
            RoundedRectangle(cornerRadius: 5 * scale).stroke(AppTheme.hotPink, lineWidth: lineWidth).frame(width: 26 * scale, height: 29 * scale).offset(y: 18 * scale)
                .overlay(Rectangle().fill(AppTheme.teal).frame(width: 3 * scale, height: 28 * scale).offset(y: 18 * scale))
        case "avatar_outfit_royal":
            Diamond().fill(AppTheme.hotPink).frame(width: 10 * scale, height: 14 * scale).offset(y: 15 * scale)
        default:
            EmptyView()
        }
    }

    private var leftArmEnd: (x: CGFloat, y: CGFloat) {
        switch style.pose {
        case "avatar_pose_victory": return (31, 20)
        case "avatar_pose_thinking": return (39, 36)
        case "avatar_pose_ready": return (30, 55)
        case "avatar_pose_flex": return (31, 36)
        default: return (31, 55)
        }
    }

    private var rightArmEnd: (x: CGFloat, y: CGFloat) {
        switch style.pose {
        case "avatar_pose_victory": return (69, 20)
        case "avatar_pose_thinking": return (70, 55)
        case "avatar_pose_ready": return (70, 55)
        case "avatar_pose_flex": return (69, 36)
        default: return (69, 55)
        }
    }

    private var leftLegEnd: (x: CGFloat, y: CGFloat) { style.pose == "avatar_pose_ready" ? (34, 79) : (39, 82) }
    private var rightLegEnd: (x: CGFloat, y: CGFloat) { style.pose == "avatar_pose_ready" ? (66, 79) : (61, 82) }

    private var outfitColor: Color {
        switch style.outfit {
        case "avatar_outfit_hoodie": return AppTheme.teal
        case "avatar_outfit_cape": return AppTheme.hotPink
        case "avatar_outfit_armor": return AppTheme.royalBlue
        case "avatar_outfit_neon": return Color(hex: "7B42FF")
        case "avatar_outfit_royal": return AppTheme.crownGold
        default: return .white
        }
    }

    private var auraColor: Color {
        switch style.aura {
        case "avatar_aura_teal": return AppTheme.teal
        case "avatar_aura_pink": return AppTheme.hotPink
        case "avatar_aura_crown": return AppTheme.crownGold
        case "avatar_aura_storm": return AppTheme.royalBlue
        default: return AppTheme.accent
        }
    }

    private func point(x: CGFloat, y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }

    private func faceText(_ text: String, y: CGFloat, size fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: max(6, fontSize * scale), weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .offset(y: (y - 50) * scale)
    }

    private func faceLine(y: CGFloat, width: CGFloat) -> some View {
        Capsule().fill(.white).frame(width: width * scale, height: max(1, 2 * scale)).offset(y: (y - 50) * scale)
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.35))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.35))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct LightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.38))
        path.closeSubpath()
        return path
    }
}

private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.28), control1: CGPoint(x: rect.minX, y: rect.maxY * 0.82), control2: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.midY), control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.82))
        path.closeSubpath()
        return path
    }
}
