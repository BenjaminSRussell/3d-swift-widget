import Foundation
import AVFoundation
import simd

/// Phase 29.1: Spatial Soundscape Engine
/// Provides binaural 3D audio for terrain interactions.
public final class AcousticRenderer {
    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    
    // Pool of players for polyphony
    private var players: [AVAudioPlayerNode] = []
    private let maxPlayers = 16
    
    public init() {
        setupEngine()
    }
    
    private func setupEngine() {
        engine.attach(environment)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
        
        // Configure for headphones (binaural)
        environment.renderingAlgorithm = .HRTF
        environment.reverbParameters.loadFactoryReverbPreset(.mediumHall)
        environment.reverbParameters.enable = true
        
        for _ in 0..<maxPlayers {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: environment, format: nil)
            players.append(player)
        }
        
        do {
            try engine.start()
        } catch {
            print("Failed to start Acoustic Engine: \(error)")
        }
    }
    
    /// Play a spatialized sound pulse at a 3D location
    public func playPulse(at position: SIMD3<Float>, intensity: Float) {
        guard let player = players.first(where: { !$0.isPlaying }) else { return }
        
        // Map 3D coordinates to Audio coordinates
        // Audio: X is left/right, Y is up, Z is in/out
        player.position = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
        
        // Load a simple procedural pulse or a sine wave
        // For this over-engineered demo, we'll assume a "Pulse" sound resource exists or generate one
        generateAndPlayPulse(on: player, intensity: intensity)
    }
    
    private func generateAndPlayPulse(on player: AVAudioPlayerNode, intensity: Float) {
        let sampleRate: Double = 44100
        let duration: Double = 0.2
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        let channels = buffer.floatChannelData![0]
        
        // Sine wave with decay
        let freq: Float = 440.0 + (intensity * 880.0) // Pitch shifts with intensity
        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            let envelope = exp(-t * 15.0) // Quick decay
            channels[i] = sin(2.0 * Float.pi * freq * t) * envelope * 0.5
        }
        
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
    }
    
    public func updateReverb(complexity: Float) {
        // High complexity = More reverb (Dampening)
        environment.reverbParameters.level = -20.0 + (complexity * 20.0)
    }
}
