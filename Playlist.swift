import Foundation

struct Playlist: Identifiable, Codable {
    var id: UUID
    var name: String
    var tracks: [Track]
    var isShuffling: Bool = false
    var isLooping: Bool = false

    mutating func addTrack(_ track: Track) -> Bool {
        if !tracks.contains(where: { $0.url == track.url }) {
            tracks.append(track)
            return true
        }
        return false
    }

    mutating func removeTracks(with ids: Set<UUID>) {
        tracks.removeAll { ids.contains($0.id) }
    }
}
//Model/Playlist.swift
//Model/Track.swift
//Utilities/AudioPlayer.swift
//View/ActivityView.swift
//View/MainContentView.swift
//View/PlaybackControlsView.swift
//ViewModel/MusicPlayerViewModel.swift
//MusicappforApp.swift
