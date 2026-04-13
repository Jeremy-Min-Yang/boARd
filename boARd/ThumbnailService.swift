import Foundation
import UIKit
import SwiftUI

enum ThumbnailService {
	static func thumbnailsDirectoryURL() -> URL? {
		guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
		let dir = docs.appendingPathComponent("Thumbnails", isDirectory: true)
		if !FileManager.default.fileExists(atPath: dir.path) {
			try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
		}
		return dir
	}

	static func saveThumbnail(_ image: UIImage, forPlayId playId: UUID) -> String? {
		guard let dir = thumbnailsDirectoryURL() else { return nil }
		let filename = "\(playId.uuidString).png"
		let url = dir.appendingPathComponent(filename)
		guard let data = image.pngData() else { return nil }
		do {
			try data.write(to: url, options: .atomic)
			return filename
		} catch {
			print("Failed to write thumbnail: \(error)")
			return nil
		}
	}

	static func loadThumbnail(filename: String) -> UIImage? {
		guard let dir = thumbnailsDirectoryURL() else { return nil }
		let url = dir.appendingPathComponent(filename)
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		return UIImage(contentsOfFile: url.path)
	}

	static func generateThumbnail(for play: Models.SavedPlay, targetSize: CGSize = CGSize(width: 320, height: 180)) -> UIImage? {
		// Determine logical canvas from court type
		let boundary: DrawingBoundary = {
			switch play.courtTypeEnum {
			case .full: return DrawingBoundary.fullCourt
			case .half: return DrawingBoundary.halfCourt
			case .football: return DrawingBoundary.footballField
			case .soccer: return DrawingBoundary.soccerField
			}
		}()

		let logicalSize = CGSize(width: boundary.width, height: boundary.height)
		let scale = min(targetSize.width / logicalSize.width, targetSize.height / logicalSize.height)
		let outputSize = CGSize(width: logicalSize.width * scale, height: logicalSize.height * scale)

		let format = UIGraphicsImageRendererFormat()
		format.scale = 2.0
		let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)

		let image = renderer.image { ctx in
			UIColor.systemBackground.setFill()
			ctx.fill(CGRect(origin: .zero, size: outputSize))

			// Draw court background
			if let bg = UIImage(named: play.courtTypeEnum.imageName) {
				bg.draw(in: CGRect(origin: .zero, size: outputSize))
			}

			// Helper to map points
			func mapPoint(_ p: Models.PointData) -> CGPoint {
				return CGPoint(x: p.x * scale, y: p.y * scale)
			}

			// Draw paths
			for d in play.drawings {
				guard d.points.count > 0 else { continue }
				let path = UIBezierPath()
				let mapped = d.points.map(mapPoint)
				if let first = mapped.first {
					path.move(to: first)
					for p in mapped.dropFirst() {
						path.addLine(to: p)
					}
				}
				let lineWidth = max(2, d.lineWidth * scale)
				path.lineWidth = lineWidth
				(UIColor.black).setStroke()
				path.stroke()
			}

			// Draw players
			for p in play.players {
				let center = mapPoint(p.position)
				let radius: CGFloat = max(8, 10 * scale)
				let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
				let circle = UIBezierPath(ovalIn: rect)
				UIColor.systemGreen.setFill()
				circle.fill()
				// Number
				let numberString = "\(p.number)"
				let attrs: [NSAttributedString.Key: Any] = [
					.font: UIFont.systemFont(ofSize: max(8, 10 * scale), weight: .bold),
					.foregroundColor: UIColor.white
				]
				let size = numberString.size(withAttributes: attrs)
				let textRect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
				numberString.draw(in: textRect, withAttributes: attrs)
			}

			// Draw opponents
			for o in play.opponents {
				let center = mapPoint(o.position)
				let radius: CGFloat = max(8, 10 * scale)
				let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
				let circle = UIBezierPath(ovalIn: rect)
				UIColor.systemRed.setFill()
				circle.fill()
				let numberString = "\(o.number)"
				let attrs: [NSAttributedString.Key: Any] = [
					.font: UIFont.systemFont(ofSize: max(8, 10 * scale), weight: .bold),
					.foregroundColor: UIColor.white
				]
				let size = numberString.size(withAttributes: attrs)
				let textRect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
				numberString.draw(in: textRect, withAttributes: attrs)
			}

			// Draw balls
			for b in play.balls {
				let center = mapPoint(b.position)
				let radius: CGFloat = max(6, 8 * scale)
				let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
				let circle = UIBezierPath(ovalIn: rect)
				UIColor.brown.setFill()
				circle.fill()
			}
		}

		return image
	}
}


