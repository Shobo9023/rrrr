import SwiftUI
import AVFoundation
import MobileCoreServices
import UniformTypeIdentifiers
import UIKit

class MusicPlayerViewModel: NSObject, ObservableObject, UIDocumentPickerDelegate, AVAudioPlayerDelegate {
    @Published var playlists: [Playlist] = [
        Playlist(id: UUID(), name: "1", tracks: []),
        Playlist(id: UUID(), name: "2", tracks: []),
        Playlist(id: UUID(), name: "3", tracks: []),
        Playlist(id: UUID(), name: "4", tracks: [])
    ]
    @Published var currentTrack: Track?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval?
    @Published var isPlaying: Bool = false
    @Published var alertMessage: String = ""
    @Published var importedFileName: String = ""
    @Published var fileStatus: String = ""
    var selectedPlaylistIndex: Int? {
        didSet {
            updatePlaybackButtonsState()
        }
    }

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    override init() {
        super.init()
        configureAudioSession()
        loadPlaylists()
        restoreLastPlayedTrack()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func searchTracks(query: String) -> [Track] {
        guard !query.isEmpty else { return [] }
        return playlists.flatMap { $0.tracks }.filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    func playPause() {
        if let audioPlayer = audioPlayer, isPlaying {
            audioPlayer.pause()
            isPlaying = false
        } else if let audioPlayer = audioPlayer {
            audioPlayer.play()
            isPlaying = true
        } else if let currentTrack = currentTrack {
            playTrack(currentTrack)
        }
    }

    func playNext() {
        guard let selectedPlaylistIndex = selectedPlaylistIndex else { return }
        let playlist = playlists[selectedPlaylistIndex]

        if playlist.isLooping, let currentTrack = currentTrack {
            // Loop the same track
            playTrack(currentTrack)
        } else {
            guard let currentTrack = currentTrack,
                  let currentIndex = playlist.tracks.firstIndex(where: { $0.id == currentTrack.id }) else { return }
            var nextIndex = (currentIndex + 1) % playlist.tracks.count

            if playlist.isShuffling {
                repeat {
                    nextIndex = Int.random(in: 0..<playlist.tracks.count)
                } while nextIndex == currentIndex
            }

            playTrack(playlist.tracks[nextIndex])
        }
    }

    func playPrevious() {
        guard let currentTrack = currentTrack,
              let selectedPlaylistIndex = selectedPlaylistIndex,
              let currentIndex = playlists[selectedPlaylistIndex].tracks.firstIndex(where: { $0.id == currentTrack.id }) else { return }
        let previousIndex = (currentIndex - 1 + playlists[selectedPlaylistIndex].tracks.count) % playlists[selectedPlaylistIndex].tracks.count
        playTrack(playlists[selectedPlaylistIndex].tracks[previousIndex])
    }

    func playTrack(_ track: Track) {
        currentTrack = track
        let fileManager = FileManager.default
        let filePath = track.url.path

        if !fileManager.fileExists(atPath: filePath) {
            DispatchQueue.main.async {
                self.fileStatus = "File does not exist"
            }
            return
        }

        let asset = AVAsset(url: track.url)
        if !asset.isPlayable {
            DispatchQueue.main.async {
                self.fileStatus = "File is not playable"
            }
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            duration = audioPlayer?.duration
            isPlaying = true
            startTimer()
            saveLastPlayedTrack()
            DispatchQueue.main.async {
                self.fileStatus = "Playing track: \(track.title)"
            }
        } catch {
            DispatchQueue.main.async {
                self.fileStatus = "Error playing track: \(error.localizedDescription)"
            }
        }
    }

    func addTrack() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        UIApplication.shared.windows.first?.rootViewController?.present(documentPicker, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let index = selectedPlaylistIndex else { return }
        alertMessage = ""
        var addedTracks = [String]()
        var duplicateTracks = [String]()

        for url in urls {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let fileManager = FileManager.default
                    let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                    let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)

                    try moveFileToDocumentsDirectory(fileURL: url)

                    let track = Track(id: UUID(), title: url.lastPathComponent, url: destinationURL)

                    if self.playlists[index].addTrack(track) {
                        addedTracks.append(track.title)
                        self.importedFileName = track.title
                        self.fileStatus = "File imported successfully"
                    } else {
                        duplicateTracks.append(track.title)
                    }
                } catch {
                    self.fileStatus = "Error moving file: \(error.localizedDescription)"
                }
            } else {
                self.fileStatus = "Failed to access file"
            }
        }

        if !addedTracks.isEmpty {
            self.alertMessage = "Added to Playlist \(self.playlists[index].name):\n" + addedTracks.joined(separator: "\n")
        }
        if !duplicateTracks.isEmpty {
            if !self.alertMessage.isEmpty { self.alertMessage += "\n\n" }
            self.alertMessage += "Duplicates not added:\n" + duplicateTracks.joined(separator: "\n")
        }

        self.savePlaylists()
    }

    func deleteTracks(trackIDs: Set<UUID>, from playlistIndex: Int, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                if let currentTrack = self.currentTrack, trackIDs.contains(currentTrack.id) {
                    self.stopPlayback()
                }
                self.playlists[playlistIndex].removeTracks(with: trackIDs)
                self.alertMessage = "Deleted \(trackIDs.count) track(s) from Playlist \(self.playlists[playlistIndex].name)"
                self.savePlaylists()
                completion()
            }
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentTrack = nil
        currentTime = 0
        duration = nil
        isPlaying = false
        DispatchQueue.main.async {
            self.updatePlaybackButtonsState()
        }
    }

    func getURLsForTracks(trackIDs: Set<UUID>, from playlistIndex: Int) -> [URL] {
        return playlists[playlistIndex].tracks.filter { trackIDs.contains($0.id) }.map { $0.url }
    }

    func seek(to time: TimeInterval) {
        guard let audioPlayer = audioPlayer else { return }
        DispatchQueue.main.async {
            self.audioPlayer?.currentTime = time
            self.currentTime = time
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentTime = self.audioPlayer?.currentTime ?? 0
            }
        }
    }

    func allTracks() -> [Track] {
        return playlists.flatMap { $0.tracks }
    }

    func updatePlaybackButtonsState() {
        // This will trigger the UI to update the enabled/disabled state of the buttons
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    private func savePlaylists() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(playlists) {
            UserDefaults.standard.set(encoded, forKey: "playlists")
        }
    }

    private func loadPlaylists() {
        if let savedPlaylists = UserDefaults.standard.data(forKey: "playlists") {
            let decoder = JSONDecoder()
            if let loadedPlaylists = try? decoder.decode([Playlist].self, from: savedPlaylists) {
                playlists = loadedPlaylists
            }
        }
    }

    private func saveLastPlayedTrack() {
        if let currentTrack = currentTrack {
            UserDefaults.standard.set(currentTrack.id.uuidString, forKey: "lastPlayedTrackID")
            UserDefaults.standard.set(currentTime, forKey: "lastPlayedTrackTime")
            UserDefaults.standard.set(isPlaying, forKey: "lastPlayedTrackIsPlaying")
        }
    }

    private func restoreLastPlayedTrack() {
        if let lastPlayedTrackID = UserDefaults.standard.string(forKey: "lastPlayedTrackID"),
           let lastPlayedTrackTime = UserDefaults.standard.object(forKey: "lastPlayedTrackTime") as? TimeInterval,
           let lastPlayedTrackIsPlaying = UserDefaults.standard.object(forKey: "lastPlayedTrackIsPlaying") as? Bool {
            for playlist in playlists {
                if let track = playlist.tracks.first(where: { $0.id.uuidString == lastPlayedTrackID }) {
                    currentTrack = track
                    currentTime = lastPlayedTrackTime
                    isPlaying = lastPlayedTrackIsPlaying
                    seek(to: currentTime)
                    break
                }
            }
        }
    }

    func restorePlaybackState() {
        if let currentTrack = currentTrack {
            playTrack(currentTrack)
            audioPlayer?.pause()
            isPlaying = false
        }
    }

    private func moveFileToDocumentsDirectory(fileURL: URL) throws {
        let fileManager = FileManager.default
        let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let destinationURL = documentsDirectory.appendingPathComponent(fileURL.lastPathComponent)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: fileURL, to: destinationURL)
    }

    private func downloadFileIfNeeded(_ url: URL, completion: @escaping (URL) -> Void) {
        let fileCoordinator = NSFileCoordinator()
        var error: NSError?
        fileCoordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &error) { (newURL) in
            completion(newURL)
        }
        if let error = error {
            DispatchQueue.main.async {
                self.fileStatus = "Error downloading file: \(error.localizedDescription)"
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playNext()
    }
}
