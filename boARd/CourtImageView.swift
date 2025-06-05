import SwiftUI

struct CourtImageView: View {
    let courtType: CourtType
    let frame: CGRect
    var body: some View {
        ZStack {
            Color.black
            if courtType == .full {
                ZStack {
                    Image("fullcourt")
                        .resizable()
                        .scaledToFit()
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 3)
                                .allowsHitTesting(false)
                        )
                        .rotationEffect(Angle(degrees: 90))
                    Rectangle()
                        .stroke(Color.red, lineWidth: 3)
                        .allowsHitTesting(false)
                        .rotationEffect(Angle(degrees: 90))
                }
            } else {
                Image("halfcourt")
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        Rectangle()
                            .stroke(Color.black, lineWidth: 3)
                            .allowsHitTesting(false)
                    )
            }
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
    }
}

struct CourtBackgroundView: View {
    let courtType: CourtType
    let courtWidth: CGFloat
    let courtHeight: CGFloat
    var body: some View {
        Image(courtType.imageName)
            .resizable()
            .scaledToFit()
            .overlay(
                Rectangle()
                    .stroke(Color.black, lineWidth: 3)
                    .allowsHitTesting(false)
            )
            .rotationEffect((courtType == .full || courtType == .soccer) ? Angle(degrees: 90) : .zero)
            .frame(
                width: {
                    switch courtType {
                    case .full:
                        return courtWidth * 1.8
                    case .soccer:
                        return courtWidth * 1.7 // Adjusted for smaller display
                    case .football:
                        return courtWidth * 1.0 // User's preference
                    default: // .half or other types
                        return courtWidth * 1.0 // User's preference
                    }
                }(),
                height: {
                    switch courtType {
                    case .full:
                        return courtHeight * 1.7
                    case .soccer:
                        return courtHeight * 1.35 // Adjusted for smaller display
                    case .football:
                        return courtHeight * 0.95 // User's preference
                    default: // .half or other types
                        return courtHeight * 1.0 // User's preference
                    }
                }()
            )
            .clipped()
    }
} 