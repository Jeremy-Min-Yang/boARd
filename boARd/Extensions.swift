import SwiftUI

// MARK: - CGPoint Extensions
extension CGPoint {
    func midpoint(to point: CGPoint) -> CGPoint {
        CGPoint(x: (self.x + point.x) / 2, y: (self.y + point.y) / 2)
    }
    func distance(to point: CGPoint) -> CGFloat {
        let dx = point.x - self.x
        let dy = point.y - self.y
        return sqrt(dx*dx + dy*dy)
    }
    func interpolated(to point: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: self.x + (point.x - self.x) * t, y: self.y + (point.y - self.y) * t)
    }
    func minimumDistance(toLineSegment start: CGPoint, end: CGPoint) -> CGFloat {
        let segmentLengthSq = start.distanceSquared(to: end)
        if segmentLengthSq == 0 { return self.distance(to: start) }
        let t = ((self.x - start.x) * (end.x - start.x) + (self.y - start.y) * (end.y - start.y)) / segmentLengthSq
        let clampedT = max(0, min(1, t))
        let closestPoint = CGPoint(
            x: start.x + clampedT * (end.x - start.x),
            y: start.y + clampedT * (end.y - start.y)
        )
        return self.distance(to: closestPoint)
    }
    func distanceSquared(to point: CGPoint) -> CGFloat {
        let dx = point.x - self.x
        let dy = point.y - self.y
        return dx*dx + dy*dy
    }
}

// MARK: - CGVector Extensions
extension CGVector {
    var length: CGFloat { sqrt(dx*dx + dy*dy) }
    var normalized: CGVector {
        let len = length
        return len > 0 ? CGVector(dx: dx/len, dy: dy/len) : CGVector(dx: 0, dy: 0)
    }
}

// MARK: - Color Extensions
extension Color {
    /// Serializes to a hex string `#RRGGBBAA` for storage.
    func toHexString() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
    }

    /// Restores a `Color` from a hex string (`#RRGGBBAA`) or a named color string.
    static func fromHexString(_ hex: String) -> Color {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        // Support legacy named color strings written before hex was implemented
        switch clean.lowercased() {
        case "black":  return .black
        case "white":  return .white
        case "red":    return .red
        case "blue":   return .blue
        case "green":  return .green
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        default: break
        }
        var hexDigits = clean.hasPrefix("#") ? String(clean.dropFirst()) : clean
        guard hexDigits.count == 8 else { return .black }
        var value: UInt64 = 0
        guard Scanner(string: hexDigits).scanHexInt64(&value) else { return .black }
        return Color(UIColor(
            red:   CGFloat((value >> 24) & 0xFF) / 255,
            green: CGFloat((value >> 16) & 0xFF) / 255,
            blue:  CGFloat((value >>  8) & 0xFF) / 255,
            alpha: CGFloat( value        & 0xFF) / 255
        ))
    }
}

// MARK: - View Extensions
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 