import Foundation
import SwiftUI
// No Firebase imports

public class SavedPlayService {
    static let shared = SavedPlayService()
    private init() {}
    
    // MARK: - Local Storage (Offline Mode)
    func savePlaysLocally(_ plays: [Models.SavedPlay]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(plays) {
            UserDefaults.standard.set(encoded, forKey: "savedPlays")
        }
    }

    func loadPlaysLocally() -> [Models.SavedPlay] {
        if let savedData = UserDefaults.standard.data(forKey: "savedPlays") {
            let decoder = JSONDecoder()
            if let loadedPlays = try? decoder.decode([Models.SavedPlay].self, from: savedData) {
                return loadedPlays
            }
        }
        return []
    }

    func savePlay(_ play: Models.SavedPlay) {
        var localPlays = self.loadPlaysLocally()
        if let idx = localPlays.firstIndex(where: { $0.id == play.id }) {
            localPlays[idx] = play
        } else {
            localPlays.append(play)
        }
        self.savePlaysLocally(localPlays)
    }

    func deletePlay(playID: String) {
        var localPlays = self.loadPlaysLocally()
        localPlays.removeAll { $0.id.uuidString == playID }
        self.savePlaysLocally(localPlays)
    }
} 
