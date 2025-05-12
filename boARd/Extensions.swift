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