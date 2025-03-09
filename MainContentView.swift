import SwiftUI

struct MainContentView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel
    @State private var selectedTab = 0
    @State private var selectedTracks = Set<UUID>()
    @State private var isSelecting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    // Search related states
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [Track] = []
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack {
                // Playback controls at the top
                PlaybackControlsView(viewModel: viewModel)

                // Picker to select a playlist
                Picker("Playlists", selection: $selectedTab) {
                    ForEach(0..<viewModel.playlists.count, id: \.self) { index in
                        if viewModel.playlists[index].tracks.contains(where: { $0.id == viewModel.currentTrack?.id }) {
                            Text("♪ \(viewModel.playlists[index].name)")
                                .font(.system(size: 24, weight: .bold))
                        } else {
                            Text("\(viewModel.playlists[index].name)")
                        }
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedTab) { newValue in
                    viewModel.selectedPlaylistIndex = newValue
                }

                // Content List
                if isSearching && !searchText.isEmpty {
                    // Search Results List
                    List {
                        ForEach(searchResults) { track in
                            TrackRow(track: track, viewModel: viewModel)
                        }
                    }
                } else {
                    // Regular Playlist List
                    if viewModel.playlists[selectedTab].tracks.isEmpty {
                        Spacer()
                        VStack {
                            Spacer()
                            Button(action: {
                                viewModel.selectedPlaylistIndex = selectedTab
                                viewModel.addTrack()
                            }) {
                                Text("Tap ➕ to add songs.")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            Spacer()
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(viewModel.playlists[selectedTab].tracks) { track in
                                HStack {
                                    Text(track.title)
                                        .foregroundColor(viewModel.currentTrack?.id == track.id ? .blue : .primary)
                                    Spacer()
                                    if selectedTracks.contains(track.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isSelecting {
                                        if selectedTracks.contains(track.id) {
                                            selectedTracks.remove(track.id)
                                            if selectedTracks.isEmpty {
                                                isSelecting = false
                                            }
                                        } else {
                                            selectedTracks.insert(track.id)
                                        }
                                    } else {
                                        viewModel.playTrack(track)
                                    }
                                }
                                .onLongPressGesture {
                                    isSelecting = true
                                    selectedTracks.insert(track.id)
                                }
                                .padding(.vertical, 4)
                                .background(selectedTracks.contains(track.id) ? Color.gray.opacity(0.3) : Color.clear)
                            }
                        }
                    }
                }

                // Selection controls
                if isSelecting {
                    HStack {
                        Button(action: {
                            if selectedTracks.count == viewModel.playlists[selectedTab].tracks.count {
                                selectedTracks.removeAll()
                                isSelecting = false
                            } else {
                                selectedTracks = Set(viewModel.playlists[selectedTab].tracks.map { $0.id })
                            }
                        }) {
                            Text(selectedTracks.count == viewModel.playlists[selectedTab].tracks.count ? "Deselect All" : "Select All")
                        }
                        Spacer()
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Text("Delete")
                        }
                        .alert(isPresented: $showDeleteConfirmation) {
                            Alert(
                                title: Text("Delete Tracks"),
                                message: Text("Are you sure you want to delete the selected tracks?"),
                                primaryButton: .destructive(Text("Yes")) {
                                    viewModel.deleteTracks(trackIDs: selectedTracks, from: selectedTab) {
                                        selectedTracks.removeAll()
                                        isSelecting = false
                                    }
                                },
                                secondaryButton: .cancel(Text("Cancel"))
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationBarItems(
                leading: HStack(spacing: 16) {
                    if isSearching {
                        HStack {
                            Button(action: {
                                isSearching = false
                                searchText = ""
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                Image(systemName: "xmark")
                            }
                            TextField("Search songs...", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isSearchFieldFocused)
                                .onChange(of: searchText) { newValue in
                                    searchResults = viewModel.searchTracks(query: newValue)
                                }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Share Button
                        Button(action: {
                            shareItems = viewModel.getURLsForTracks(trackIDs: selectedTracks, from: selectedTab)
                            showShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(selectedTracks.isEmpty)
                        
                        // Search Button
                        Button(action: {
                            isSearching.toggle()
                            if isSearching {
                                DispatchQueue.main.async {
                                    isSearchFieldFocused = true
                                }
                            } else {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                },
                trailing: isSearching ? nil : Button(action: {
                    viewModel.selectedPlaylistIndex = selectedTab
                    viewModel.addTrack()
                }) {
                    Image(systemName: "plus")
                }
            )
            .navigationTitle("")
            .navigationBarHidden(false)
            .overlay(
                Group {
                    if showAlert {
                        Text(alertMessage)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .transition(.opacity)
                            .zIndex(1)
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: showAlert)
            .onReceive(viewModel.$alertMessage) { message in
                if !message.isEmpty {
                    alertMessage = message
                    showAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showAlert = false
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: shareItems)
            }
            .onAppear {
                viewModel.restorePlaybackState()
            }
            .onChange(of: isSearching) { searching in
                if (!searching) {
                    searchText = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            })
        }
    }
}

// MARK: - Track Row View
struct TrackRow: View {
    let track: Track
    @ObservedObject var viewModel: MusicPlayerViewModel
    
    var body: some View {
        HStack {
            Text(track.title)
                .foregroundColor(viewModel.currentTrack?.id == track.id ? .blue : .primary)
            Spacer()
            Text(playlistName(for: track))
                .font(.caption)
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.playTrack(track)
        }
    }
    
    private func playlistName(for track: Track) -> String {
        if let playlist = viewModel.playlists.first(where: { $0.tracks.contains(where: { $0.id == track.id }) }) {
            return "Playlist: \(playlist.name)"
        }
        return ""
    }
}
