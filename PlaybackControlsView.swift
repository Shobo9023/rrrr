import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel

    var body: some View {
        VStack {
            Text(viewModel.currentTrack?.title ?? "Select Track")
                .font(.headline)
            
            // Timer display
            HStack {
                Text("\(formatTime(viewModel.currentTime)) / \(formatTime(viewModel.duration ?? 0))")
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)

            // Slider for seeking
            Slider(value: Binding(
                get: { viewModel.currentTime },
                set: { newValue in
                    viewModel.seek(to: newValue)
                }
            ), in: 0...(viewModel.duration ?? 1), step: viewModel.duration != nil ? viewModel.duration! / 540 : 1) // Adjusting step value for smoother seeking
            .accentColor(.blue)
            .padding(.horizontal)
            .padding(.top, -10) // Reduce the distance by using negative padding
            
            HStack {
                Button(action: {
                    viewModel.playlists[viewModel.selectedPlaylistIndex ?? 0].isShuffling.toggle()
                }) {
                    Image(systemName: viewModel.playlists[viewModel.selectedPlaylistIndex ?? 0].isShuffling ? "shuffle.circle.fill" : "shuffle.circle")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(viewModel.playlists[viewModel.selectedPlaylistIndex ?? 0].isShuffling ? .blue : .gray)
                }
                Spacer()
                Button(action: viewModel.playPrevious) {
                    Image(systemName: "backward.fill")
                }
                .disabled(viewModel.allTracks().isEmpty)
                Spacer()
                Button(action: viewModel.playPause) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(viewModel.allTracks().isEmpty)
                Spacer()
                Button(action: viewModel.playNext) {
                    Image(systemName: "forward.fill")
                }
                .disabled(viewModel.allTracks().isEmpty)
                Spacer()
                Button(action: {
                    viewModel.playlists[viewModel.selectedPlaylistIndex ?? 0].isLooping.toggle()
                }) {
                    Image(systemName: viewModel.playlists[viewModel.selectedPlaylistIndex ?? 0].isLooping ? "repeat.circle.fill" : "repeat.circle")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(viewModel.playlists[viewModel.selectedPlaylistIndex ?? 0].isLooping ? .blue : .gray)
                }
            }
        }
        .padding()
        .onAppear {
            setupSliderThumbImage()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func setupSliderThumbImage() {
        let thumbImage = UIImage(systemName: "circle.fill")?.resized(to: CGSize(width: 10, height: 10))
        UISlider.appearance().setThumbImage(thumbImage, for: .normal)
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
