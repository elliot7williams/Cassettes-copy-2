//
//  ContentView.swift
//  Cassettes
//
//  Created by Elliot Williams on 2025-05-31.
//

import SwiftUI
import MediaPlayer
import CoreImage

struct CassettePlayerView: View {
    @StateObject private var musicManager = MusicManager()
    @State private var currentAlbum: MPMediaItemCollection?
    @State private var playbackState: PlaybackState = .stopped
    @State private var flipAngle: Double = 0
    @State private var isFlipped = false
    @State private var tapeOffset: CGFloat = 0
    @State private var reelSpeed: Double = 0
    @State private var perspectiveAngle: Double = 0
    @State private var vuMeterLevels: [CGFloat] = [0.3, 0.6, 0.8, 0.9, 0.7, 0.5, 0.4, 0.3]
    @State private var dominantColor: Color = .blue
    @State private var isPressed = false
    @State private var buttonPressTimer: Timer?
    @State private var showSearchPanel = false
    @State private var searchText = ""
    
    var filteredAlbums: [MPMediaItemCollection] {
        if searchText.isEmpty {
            return musicManager.albums
        } else {
            return musicManager.albums.filter { album in
                let title = album.representativeItem?.albumTitle ?? ""
                let artist = album.representativeItem?.albumArtist ?? ""
                return title.localizedCaseInsensitiveContains(searchText) || artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Player Header
                HStack {
                    Text("CASSETTE PLAYER")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(2)
                    
                    Spacer()
                    
                    // Battery indicator
                    HStack(spacing: 2) {
                        ForEach(0..<4) { i in
                            Rectangle()
                                .fill(i < 3 ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: 4, height: 10)
                                .cornerRadius(1)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            .frame(width: 24, height: 14)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .zIndex(1)
                
                // Cassette Player Section
                ZStack {
                    // Woodgrain player background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.4, green: 0.3, blue: 0.2),
                                    Color(red: 0.3, green: 0.2, blue: 0.1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .zIndex(1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.7, green: 0.6, blue: 0.5),
                                            Color(red: 0.2, green: 0.15, blue: 0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .shadow(color: .black.opacity(0.8), radius: 20, x: 0, y: 10)
                        .zIndex(1)
                    
                    // Player details
                    CassettePlayerControlsView(
                        currentAlbum: $currentAlbum,
                        playbackState: $playbackState,
                        vuMeterLevels: $vuMeterLevels,
                        dominantColor: $dominantColor,
                        showSearchPanel: $showSearchPanel
                    )
                    .zIndex(3)
                    
                    // Cassette tape
                    CassetteView(
                        album: currentAlbum,
                        isPlaying: playbackState == .playing,
                        flipAngle: $flipAngle,
                        isFlipped: $isFlipped,
                        tapeOffset: $tapeOffset,
                        reelSpeed: $reelSpeed,
                        perspectiveAngle: $perspectiveAngle,
                        dominantColor: $dominantColor
                    )
                    .offset(y: -20)
                    .zIndex(2)
                }
                .frame(height: 420)
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                
                // Clear separation area
                Color.clear.frame(height: 24)
                
                // Album list
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 20) {
                        ForEach(musicManager.albums, id: \.persistentID) { album in
                            AlbumCoverView(album: album, isSelected: currentAlbum?.persistentID == album.persistentID)
                                .onTapGesture {
                                    selectAlbum(album)
                                    showSearchPanel = false
                                }
                        }
                    }
                    .padding()
                }
                .frame(height: geometry.size.height * 0.45)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.15), .black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
            )
            .overlay(
                Group {
                    if showSearchPanel {
                        SearchPanelView(
                            searchText: $searchText,
                            onDismiss: { showSearchPanel = false }
                        )
                        .transition(.opacity)
                        .zIndex(10)
                    }
                }
            )
            .navigationTitle("Cassette Player")
            .onAppear {
                musicManager.requestAuthorization()
                startVUMeterAnimation()
            }
            .accentColor(.white)
            .zIndex(1)
        }
    }
    
    private func startVUMeterAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if playbackState == .playing {
                withAnimation(.linear(duration: 0.1)) {
                    vuMeterLevels = vuMeterLevels.map { _ in
                        CGFloat.random(in: 0.2...1.0)
                    }
                }
            }
        }
    }
    
    private func selectAlbum(_ album: MPMediaItemCollection) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Flip animation if changing album
        if currentAlbum?.persistentID != album.persistentID {
            withAnimation(.easeInOut(duration: 0.4)) {
                flipAngle = 180
                isFlipped.toggle()
                tapeOffset = 0
                reelSpeed = 0
            }
            
            // Extract dominant color from new album
            if let artwork = album.representativeItem?.artwork,
               let image = artwork.image(at: CGSize(width: 100, height: 100)) {
                extractDominantColor(from: image) { color in
                    dominantColor = color
                }
            }
            
            // Delay to show flip animation before changing album
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                currentAlbum = album
                playbackState = .playing
                withAnimation(.easeInOut(duration: 0.4)) {
                    flipAngle = 0
                }
                
                // Start tape animation
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    tapeOffset = -40
                }
                
                // Gradually increase reel speed
                withAnimation(.easeOut(duration: 1)) {
                    reelSpeed = 1
                }
                
                // Add perspective effect
                withAnimation(.easeInOut(duration: 0.3)) {
                    perspectiveAngle = 5
                }
            }
        } else {
            // Toggle play/pause for current album
            playbackState = (playbackState == .playing) ? .paused : .playing
            
            // Adjust reel speed based on playback state
            withAnimation(.easeInOut(duration: 0.3)) {
                reelSpeed = (playbackState == .playing) ? 1 : 0
            }
            
            // Start/stop tape animation
            if playbackState == .playing {
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    tapeOffset = -40
                }
            } else {
                withAnimation {
                    tapeOffset = 0
                }
            }
        }
    }
    
    private func extractDominantColor(from image: UIImage, completion: @escaping (Color) -> Void) {
        DispatchQueue.global().async {
            guard let ciImage = CIImage(image: image) else { return }
            
            // Use CIAreaAverage to get the average color of the image
            let params = [kCIInputImageKey: ciImage, kCIInputExtentKey: CIVector(cgRect: ciImage.extent)]
            guard let filter = CIFilter(name: "CIAreaAverage", parameters: params) else { return }
            guard let outputImage = filter.outputImage else { return }
            
            // Create a 1x1 bitmap
            var bitmap = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: nil)
            context.render(
                outputImage,
                toBitmap: &bitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: nil
            )
            
            DispatchQueue.main.async {
                completion(Color(
                    red: Double(bitmap[0]) / 255.0,
                    green: Double(bitmap[1]) / 255.0,
                    blue: Double(bitmap[2]) / 255.0
                ))
            }
        }
    }
}

struct CassettePlayerControlsView: View {
    @Binding var currentAlbum: MPMediaItemCollection?
    @Binding var playbackState: PlaybackState
    @Binding var vuMeterLevels: [CGFloat]
    @Binding var dominantColor: Color
    @Binding var showSearchPanel: Bool
    
    @State private var isPressed = false
    
    var body: some View {
        VStack {
            Spacer()
            
            // VU Meters
            HStack(spacing: 2) {
                ForEach(0..<vuMeterLevels.count, id: \.self) { index in
                    VStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        dominantColor.opacity(0.8),
                                        dominantColor,
                                        Color.white
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 6, height: 20 + CGFloat(50 * vuMeterLevels[index]))
                            .cornerRadius(1)
                            .shadow(color: dominantColor.opacity(0.5), radius: 3, x: 0, y: 0)
                    }
                    .frame(height: 70, alignment: .bottom)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
            .zIndex(3)
            
            // Player controls
            HStack(spacing: 20) {
                // Rewind button
                Button(action: {}) {
                    PlayerButton(icon: "backward.fill", size: 24, dominantColor: dominantColor)
                        .zIndex(5)
                }
                
                // Record button
                Button(action: {}) {
                    PlayerButton(icon: "circle.fill", size: 24, dominantColor: Color.red)
                        .zIndex(5)
                }
                
                // Play/Pause button
                Button(action: {
                    playbackState = (playbackState == .playing) ? .paused : .playing
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        dominantColor,
                                        dominantColor.opacity(0.7),
                                        dominantColor.opacity(0.5)
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 35
                                )
                            )
                            .frame(width: 70, height: 70)
                            .shadow(color: dominantColor.opacity(0.5), radius: 10, x: 0, y: 0)
                            .zIndex(5)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 70, height: 70)
                            .zIndex(5)
                        
                        Image(systemName: playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                            .zIndex(5)
                    }
                }
                
                // Stop button
                Button(action: {}) {
                    PlayerButton(icon: "stop.fill", size: 24, dominantColor: Color.red)
                        .zIndex(5)
                }
                
                // Fast forward button
                Button(action: {}) {
                    PlayerButton(icon: "forward.fill", size: 24, dominantColor: dominantColor)
                        .zIndex(5)
                }
            }
            .padding(.bottom, -20)
            .allowsHitTesting(true)
            .zIndex(5)
            
            // Additional controls
            HStack(spacing: 20) {
                PlayerButton(icon: "eject.fill", size: 20, dominantColor: dominantColor)
                    .zIndex(5)
                
                PlayerButton(icon: "speaker.wave.2.fill", size: 20, dominantColor: dominantColor)
                    .zIndex(5)
                
                PlayerButton(icon: "light.max", size: 20, dominantColor: dominantColor)
                    .zIndex(5)
                
                PlayerButton(icon: "repeat", size: 20, dominantColor: dominantColor)
                    .zIndex(5)
                
                // Add search button
                PlayerButton(icon: "magnifyingglass", size: 20, dominantColor: dominantColor)
                    .zIndex(5)
                    .onTapGesture {
                        showSearchPanel = true
                    }
            }
            .padding(.bottom, -40)
            .zIndex(5)
        }
    }
}

struct PlayerButton: View {
    let icon: String
    let size: CGFloat
    let dominantColor: Color
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Button background
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(white: 0.25),
                            Color(white: 0.15)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.2),
                                    Color.black.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.7), radius: 3, x: 2, y: 3)
            
            // Button icon
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .foregroundColor(dominantColor)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

struct CassetteView: View {
    let album: MPMediaItemCollection?
    let isPlaying: Bool
    
    @Binding var flipAngle: Double
    @Binding var isFlipped: Bool
    @Binding var tapeOffset: CGFloat
    @Binding var reelSpeed: Double
    @Binding var perspectiveAngle: Double
    @Binding var dominantColor: Color
    
    @State private var tapeStripes: [Color] = [.brown, .black, .brown, .black]
    @State private var reelRotation: Double = 0
    
    var body: some View {
        let artworkImage = album?.representativeItem?.artwork?.image(at: CGSize(width: 100, height: 100))
        
        return ZStack {
            // Cassette body with realistic plastic texture
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            dominantColor.opacity(0.9),
                            dominantColor.opacity(0.7),
                            dominantColor.opacity(0.9)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 240, height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.5),
                                    Color.black.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .modifier(PlasticTextureModifier())
                .rotation3DEffect(
                    .degrees(perspectiveAngle),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center
                )
                .shadow(color: .black.opacity(0.7), radius: 10, x: 0, y: 5)
            
            // Reflective highlight
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 240, height: 150)
                .offset(x: -20, y: -20)
            
            // Tape window frame
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(white: 0.9),
                            Color(white: 0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 184, height: 24)
                .overlay(
                    // Plastic shine effect
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .frame(width: 182, height: 22)
                )
                .offset(y: 15)
            
            // Tape window
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black.opacity(0.7))
                .frame(width: 180, height: 20)
                .overlay(
                    // Moving tape
                    HStack(spacing: 0) {
                        ForEach(0..<20) { index in
                            Rectangle()
                                .fill(tapeStripes[index % tapeStripes.count])
                                .frame(width: 10, height: 20)
                        }
                    }
                    .offset(x: tapeOffset)
                )
                .offset(y: 15)
            
            // Reels
            HStack(spacing: 120) {
                ReelView(isPlaying: isPlaying, speed: reelSpeed)
                ReelView(isPlaying: isPlaying, speed: reelSpeed)
            }
            .offset(y: -10)
            
            // Screws with realistic metallic texture
            HStack(spacing: 180) {
                ScrewView()
                ScrewView()
            }
            .offset(y: 50)
            
            // Label area
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(white: 0.95),
                            Color(white: 0.85)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 180, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(white: 0.7), lineWidth: 1)
                )
                .offset(y: -30)
            
            // Album info on label
            VStack(spacing: 2) {
                Text(album?.representativeItem?.albumTitle ?? "No Album")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                
                Text(album?.representativeItem?.albumArtist ?? "Unknown Artist")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.black.opacity(0.7))
            }
            .offset(y: -30)
            
            // Type indicator
            Text("TYPE I")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.black.opacity(0.7))
                .padding(4)
                .background(
                    Capsule()
                        .fill(Color(white: 0.9))
                        .opacity(0.8)
                )
                .offset(x: 70, y: 45)
        }
        .rotation3DEffect(
            .degrees(flipAngle),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center
        )
    }
}

struct PlasticTextureModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.05), location: 0.2),
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.05), location: 0.7),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .mask(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white.opacity(0.2), location: 0.2),
                                    .init(color: .white, location: 0.3),
                                    .init(color: .white, location: 0.7),
                                    .init(color: .white.opacity(0.2), location: 0.8),
                                    .init(color: .white, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
            )
    }
}

struct AlbumCoverView: View {
    let album: MPMediaItemCollection
    let isSelected: Bool
    
    var body: some View {
        VStack {
            ZStack {
                if let artwork = album.representativeItem?.artwork {
                    if let image = artwork.image(at: CGSize(width: 120, height: 120)) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 3)
                    } else {
                        placeholderArtwork
                    }
                } else {
                    placeholderArtwork
                }
                
                if isSelected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 45, y: -45)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                }
            }
            
            Text(album.representativeItem?.albumTitle ?? "Unknown Album")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 120)
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.2, opacity: 0.4))
        )
    }
    
    private var placeholderArtwork: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(white: 0.3), Color(white: 0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 120, height: 120)
            .cornerRadius(8)
            
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

struct ReelView: View {
    let isPlaying: Bool
    let speed: Double
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Reel outer ring - metallic
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(white: 0.8),
                            Color(white: 0.6),
                            Color(white: 0.4)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 2, x: 2, y: 2)
            
            // Reel inner circle
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(white: 0.3),
                            Color(white: 0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.5), lineWidth: 1)
                )
            
            // Reel spokes
            ForEach(0..<6) { index in
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(white: 0.7),
                                Color(white: 0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 20)
                    .offset(y: -10)
                    .rotationEffect(.degrees(Double(index) * 60))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
            
            // Reel indicator
            Rectangle()
                .fill(Color.white)
                .frame(width: 4, height: 15)
                .offset(y: -7.5)
                .rotationEffect(.degrees(rotation))
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .onChange(of: isPlaying) { playing in
            if playing && speed > 0 {
                withAnimation(.linear(duration: 2 / speed).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                withAnimation {
                    rotation = 0
                }
            }
        }
    }
}

struct ScrewView: View {
    var body: some View {
        ZStack {
            // Screw head
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(white: 0.7),
                            Color(white: 0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.3), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1)
            
            // Screw slot
            Rectangle()
                .fill(Color(white: 0.3))
                .frame(width: 1.5, height: 6)
                .rotationEffect(.degrees(45))
            
            Rectangle()
                .fill(Color(white: 0.3))
                .frame(width: 1.5, height: 6)
                .rotationEffect(.degrees(135))
        }
    }
}

enum PlaybackState {
    case playing, paused, stopped
}

class MusicManager: ObservableObject {
    @Published var albums = [MPMediaItemCollection]()
    
    func requestAuthorization() {
        MPMediaLibrary.requestAuthorization { status in
            if status == .authorized {
                self.fetchAlbums()
            }
        }
    }
    
    private func fetchAlbums() {
        let query = MPMediaQuery.albums()
        if let collections = query.collections {
            DispatchQueue.main.async {
                self.albums = collections
            }
        }
    }
}

struct SearchPanelView: View {
    @Binding var searchText: String
    var onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                TextField("Search albums...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .foregroundColor(.black)
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .shadow(radius: 5)
                
                Button(action: onDismiss) {
                    Text("Done")
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding(.top, 50)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            searchText = ""
        }
    }
}

struct CassettePlayerView_Previews: PreviewProvider {
    static var previews: some View {
        CassettePlayerView()
            .preferredColorScheme(.dark)
    }
}
