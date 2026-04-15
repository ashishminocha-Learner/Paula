import Accelerate
import AVFoundation
import Foundation

/// Extracts pitch (F0) and energy from an audio file using vDSP FFT.
/// Used to improve speaker diarization beyond pause heuristics.
struct AudioAnalyzer {

    // MARK: - Audio feature per segment

    struct SegmentFeatures: Sendable {
        let startTime: Double
        let endTime: Double
        let fundamentalHz: Float    // 0 if undetectable
        let rmsEnergy: Float        // 0–1 normalized
        var speakerIndex: Int = -1  // assigned by k-means
    }

    // MARK: - Public API

    /// Analyse a recording file and return per-segment features aligned to the transcript segments.
    func analyzeSegments(
        fileURL: URL,
        segments: [TranscribedSegment]
    ) async -> [SegmentFeatures] {
        guard let file = try? AVAudioFile(forReading: fileURL),
              let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: file.processingFormat.sampleRate,
                channels: 1,
                interleaved: false
              ) else { return [] }

        let sampleRate = Float(file.processingFormat.sampleRate)
        let totalFrames = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames),
              (try? file.read(into: buffer)) != nil,
              let channelData = buffer.floatChannelData?[0] else { return [] }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(totalFrames)))

        return segments.map { seg in
            let startFrame = Int(seg.startTime * Double(sampleRate))
            let endFrame   = min(Int(seg.endTime   * Double(sampleRate)), samples.count)
            guard startFrame < endFrame else {
                return SegmentFeatures(startTime: seg.startTime, endTime: seg.endTime,
                                       fundamentalHz: 0, rmsEnergy: 0)
            }
            let chunk = Array(samples[startFrame ..< endFrame])
            let pitch  = estimatePitch(samples: chunk, sampleRate: sampleRate)
            let energy = rms(samples: chunk)
            return SegmentFeatures(startTime: seg.startTime, endTime: seg.endTime,
                                   fundamentalHz: pitch, rmsEnergy: energy)
        }
    }

    // MARK: - K-means speaker clustering

    /// Cluster segments into `k` speakers using (pitch, energy) features.
    func clusterSpeakers(features: [SegmentFeatures], k: Int) -> [SegmentFeatures] {
        guard !features.isEmpty, k > 1 else {
            return features.map { var f = $0; f.speakerIndex = 0; return f }
        }

        // Normalise features
        let pitches  = features.map { $0.fundamentalHz }
        let energies = features.map { $0.rmsEnergy }
        let maxPitch  = pitches.max() ?? 1
        let maxEnergy = energies.max() ?? 1

        let points = features.map { feat -> (Float, Float) in
            let p = maxPitch  > 0 ? feat.fundamentalHz / maxPitch  : 0
            let e = maxEnergy > 0 ? feat.rmsEnergy     / maxEnergy : 0
            return (p, e)
        }

        // Initialise centroids evenly spaced along pitch axis
        var centroids: [(Float, Float)] = (0 ..< k).map { i in
            (Float(i) / Float(k - 1), 0.5)
        }

        // Iterate k-means (max 20 rounds)
        var assignments = Array(repeating: 0, count: features.count)
        for _ in 0 ..< 20 {
            var changed = false
            for i in 0 ..< points.count {
                let best = closestCentroid(point: points[i], centroids: centroids)
                if best != assignments[i] { changed = true; assignments[i] = best }
            }
            if !changed { break }
            // Recompute centroids
            for c in 0 ..< k {
                let group = zip(points, assignments).filter { $0.1 == c }.map { $0.0 }
                if group.isEmpty { continue }
                centroids[c] = (
                    group.map(\.0).reduce(0, +) / Float(group.count),
                    group.map(\.1).reduce(0, +) / Float(group.count)
                )
            }
        }

        return zip(features, assignments).map { feat, idx in
            var f = feat; f.speakerIndex = idx; return f
        }
    }

    // MARK: - Private helpers

    /// Estimate fundamental frequency using autocorrelation.
    private func estimatePitch(samples: [Float], sampleRate: Float) -> Float {
        let minHz: Float = 80    // lower bound (bass voice)
        let maxHz: Float = 300   // upper bound (high soprano)
        let minLag = Int(sampleRate / maxHz)
        let maxLag = Int(sampleRate / minHz)

        guard samples.count > maxLag * 2 else { return 0 }

        let n = samples.count
        var autocorr = [Float](repeating: 0, count: maxLag + 1)
        for lag in minLag ... maxLag {
            var sum: Float = 0
            vDSP_dotpr(samples, 1, Array(samples[lag...]), 1, &sum, vDSP_Length(n - lag))
            autocorr[lag] = sum
        }

        // Find peak lag
        let searchRange = Array(autocorr[minLag ... maxLag])
        guard let peakIdx = searchRange.indices.max(by: { searchRange[$0] < searchRange[$1] }) else { return 0 }
        let peakLag = minLag + peakIdx

        // Reject if peak is very weak (unvoiced segment)
        let r0 = autocorr[0] > 0 ? autocorr[0] : 1
        let clarity = autocorr[peakLag] / r0
        guard clarity > 0.15 else { return 0 }

        return sampleRate / Float(peakLag)
    }

    /// RMS energy, normalised 0–1.
    private func rms(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var mean: Float = 0
        vDSP_measqv(samples, 1, &mean, vDSP_Length(samples.count))
        return min(1.0, sqrt(mean) * 10)   // × 10 to bring typical speech into 0–1 range
    }

    private func closestCentroid(point: (Float, Float), centroids: [(Float, Float)]) -> Int {
        centroids.indices.min(by: {
            dist(point, centroids[$0]) < dist(point, centroids[$1])
        }) ?? 0
    }

    private func dist(_ a: (Float, Float), _ b: (Float, Float)) -> Float {
        let dx = a.0 - b.0; let dy = a.1 - b.1
        return dx * dx + dy * dy
    }
}
