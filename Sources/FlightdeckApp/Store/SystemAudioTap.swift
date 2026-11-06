import CoreAudio
import Foundation
import os

/// Listens to everything the Mac plays through a Core Audio process tap (macOS 14.2 and later),
/// for the visualiser. The first start asks for the system audio recording permission; while
/// that is denied the tap delivers silence, which the visualiser treats as "no audio".
final class SystemAudioTap: @unchecked Sendable {
    private static let bufferLength = 2048

    private let samples = OSAllocatedUnfairLock(initialState: [Float]())
    private let queue = DispatchQueue(label: "Flightdeck.SystemAudioTap", qos: .userInteractive)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var tapUUID = UUID()
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private(set) var sampleRate: Double = 48_000

    var isRunning: Bool { procID != nil }

    /// The most recent mono samples, oldest first; empty when not running.
    func recentSamples() -> [Float] {
        samples.withLock { $0 }
    }

    func start() {
        guard !isRunning, #available(macOS 14.2, *) else { return }
        guard createTap(), createAggregateDevice(), startReading() else { return stop() }
    }

    func stop() {
        if let procID {
            AudioDeviceStop(deviceID, procID)
            AudioDeviceDestroyIOProcID(deviceID, procID)
        }
        if deviceID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(deviceID) }
        if #available(macOS 14.2, *), tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil
        deviceID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
        samples.withLock { $0.removeAll() }
    }

    @available(macOS 14.2, *)
    private func createTap() -> Bool {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.isPrivate = true
        description.muteBehavior = .unmuted
        tapUUID = description.uuid
        return AudioHardwareCreateProcessTap(description, &tapID) == noErr
    }

    /// Taps only deliver audio through an aggregate device, here one wrapping the current output.
    private func createAggregateDevice() -> Bool {
        guard let outputUID = Self.defaultOutputUID() else { return false }
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Flightdeck visualiser",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: tapUUID.uuidString]],
        ]
        guard AudioHardwareCreateAggregateDevice(description as CFDictionary, &deviceID) == noErr else { return false }
        sampleRate = Self.nominalSampleRate(of: deviceID) ?? sampleRate
        return true
    }

    private func startReading() -> Bool {
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, queue) { [samples] _, input, _, _, _ in
            let mono = Self.monoMix(of: UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)))
            samples.withLock { buffer in
                buffer.append(contentsOf: mono)
                if buffer.count > Self.bufferLength { buffer.removeFirst(buffer.count - Self.bufferLength) }
            }
        }
        guard status == noErr, let procID else { return false }
        return AudioDeviceStart(deviceID, procID) == noErr
    }

    /// Averages interleaved or separate channels of 32-bit float audio into one channel.
    private static func monoMix(of buffers: UnsafeMutableAudioBufferListPointer) -> [Float] {
        guard let first = buffers.first, first.mNumberChannels > 0 else { return [] }
        let channels = Int(first.mNumberChannels) * buffers.count
        let frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size / Int(first.mNumberChannels)
        var mono = [Float](repeating: 0, count: frames)
        for buffer in buffers {
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            let stride = Int(buffer.mNumberChannels)
            for frame in 0..<frames {
                for channel in 0..<stride { mono[frame] += data[frame * stride + channel] / Float(channels) }
            }
        }
        return mono
    }

    private static func defaultOutputUID() -> String? {
        var device = AudioObjectID(kAudioObjectUnknown)
        guard read(kAudioHardwarePropertyDefaultSystemOutputDevice, of: AudioObjectID(kAudioObjectSystemObject), into: &device) else { return nil }
        var uid: Unmanaged<CFString>?
        guard read(kAudioDevicePropertyDeviceUID, of: device, into: &uid) else { return nil }
        return uid?.takeRetainedValue() as String?
    }

    private static func nominalSampleRate(of device: AudioObjectID) -> Double? {
        var rate = Float64(0)
        return read(kAudioDevicePropertyNominalSampleRate, of: device, into: &rate) && rate > 0 ? rate : nil
    }

    private static func read<Value>(_ selector: AudioObjectPropertySelector, of object: AudioObjectID, into value: inout Value) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<Value>.size)
        return withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0) } == noErr
    }
}
