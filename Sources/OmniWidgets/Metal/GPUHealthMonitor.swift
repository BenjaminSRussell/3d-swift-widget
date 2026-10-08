import Foundation
import Metal
import os

/// Tracks whether a usable `MTLDevice` exists and drives recovery after a GPU reset or removal.
///
/// * Renderers report command-buffer failures with `reportFailure(_:)`.
/// * On macOS the monitor also watches `MTLCopyAllDevicesWithObserver` for removal of the
///   current device (eGPU unplug, driver reset).
/// * Recovery asks `deviceProvider` for a fresh device up to `maxRecoveryAttempts` times.
///   On success `generation` increments, so views that key their Metal content on it are
///   rebuilt with new pipelines. On failure the state becomes `.fallback` and the UI shows
///   the software path with a banner, never a silent black screen.
@MainActor
public final class GPUHealthMonitor: ObservableObject {
    public enum State: Equatable {
        case ready(deviceName: String)
        case recovering(reason: String, attempt: Int)
        case fallback(reason: String)

        public var isReady: Bool { if case .ready = self { return true } else { return false } }
    }

    @Published public private(set) var state: State
    /// Increments every time a new device is installed; key Metal views on this.
    @Published public private(set) var generation = 0
    @Published public private(set) var device: MTLDevice?
    /// Human-readable log of failures and recoveries (newest last), also sent to os.Logger.
    @Published public private(set) var events: [String] = []

    public var maxRecoveryAttempts: Int
    public var retryDelay: Duration

    private let deviceProvider: () -> MTLDevice?
    private var recoveryTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    private static let log = Logger(subsystem: "HDTE.OmniWidgets", category: "gpu")

    public init(deviceProvider: @escaping () -> MTLDevice? = { MTLCreateSystemDefaultDevice() },
                maxRecoveryAttempts: Int = 3,
                retryDelay: Duration = .milliseconds(500),
                observeSystemDevices: Bool = true) {
        self.deviceProvider = deviceProvider
        self.maxRecoveryAttempts = maxRecoveryAttempts
        self.retryDelay = retryDelay
        if let dev = deviceProvider() {
            device = dev
            state = .ready(deviceName: dev.name)
        } else {
            state = .fallback(reason: "No Metal device available")
        }
        if observeSystemDevices { startObservingDevices() }
        record(stateDescription)
    }

    deinit {
        if let observer { MTLRemoveDeviceObserver(observer) }
        recoveryTask?.cancel()
    }

    public var stateDescription: String {
        switch state {
        case .ready(let name): return "GPU ready: \(name)"
        case .recovering(let reason, let attempt): return "Recovering GPU (attempt \(attempt)): \(reason)"
        case .fallback(let reason): return "Software fallback: \(reason)"
        }
    }

    /// Called by renderers when a command buffer fails or the device stops responding.
    /// Repeated reports during an in-flight recovery are coalesced.
    public func reportFailure(_ reason: String) {
        guard recoveryTask == nil else { return }
        Self.log.error("GPU failure: \(reason, privacy: .public)")
        record("Failure: \(reason)")
        device = nil
        recoveryTask = Task { [weak self] in await self?.recover(reason: reason) }
    }

    /// Debug/test hook: behaves like a GPU reset. With `permanently`, recovery is forced to fail
    /// so the fallback banner can be exercised.
    public func simulateDeviceLoss(permanently: Bool = false) {
        simulatedOutage = permanently
        reportFailure(permanently ? "Simulated permanent device loss" : "Simulated device reset")
    }

    /// User-initiated retry from the fallback banner.
    public func retry() {
        simulatedOutage = false
        guard !state.isReady else { return }
        reportFailure("Manual retry")
    }

    /// Awaits the current recovery (for tests).
    public func waitForRecovery() async { await recoveryTask?.value }

    private var simulatedOutage = false

    private func recover(reason: String) async {
        defer { recoveryTask = nil }
        for attempt in 1...max(1, maxRecoveryAttempts) {
            state = .recovering(reason: reason, attempt: attempt)
            if attempt > 1 { try? await Task.sleep(for: retryDelay) }
            if Task.isCancelled { return }
            if !simulatedOutage, let dev = deviceProvider() {
                device = dev
                generation += 1
                state = .ready(deviceName: dev.name)
                Self.log.notice("GPU recovered on \(dev.name, privacy: .public) after \(attempt) attempt(s)")
                record("Recovered on \(dev.name) (attempt \(attempt))")
                return
            }
        }
        state = .fallback(reason: reason)
        Self.log.error("GPU unavailable, using software fallback: \(reason, privacy: .public)")
        record("Fallback: \(reason)")
    }

    private func record(_ line: String) {
        events.append(line)
        if events.count > 50 { events.removeFirst(events.count - 50) }
    }

    private func startObservingDevices() {
        #if os(macOS)
        let (_, obs) = MTLCopyAllDevicesWithObserver { [weak self] dev, note in
            guard note == .wasRemoved || note == .removalRequested else { return }
            let name = dev.name
            Task { @MainActor [weak self] in
                guard let self, let current = self.device, current.registryID == dev.registryID else { return }
                self.reportFailure("Device \(name) \(note == .wasRemoved ? "was removed" : "removal requested")")
            }
        }
        observer = obs
        #endif
    }
}

public extension MTLCommandBuffer {
    /// Description of a failed command buffer, or nil if it completed. Device-loss style errors
    /// (`.deviceRemoved`, `.timeout`, `.notPermitted`, `.outOfMemory`) are the ones that warrant recovery.
    var failureReason: String? {
        guard status == .error else { return nil }
        let code = (error as NSError?).map { MTLCommandBufferError.Code(rawValue: UInt($0.code)) } ?? nil
        let kind: String
        switch code {
        case .deviceRemoved?: kind = "device removed"
        case .timeout?: kind = "GPU timeout"
        case .notPermitted?: kind = "not permitted (app backgrounded?)"
        case .outOfMemory?: kind = "out of GPU memory"
        case .pageFault?: kind = "page fault"
        default: kind = "command buffer error"
        }
        return "\(kind): \(error?.localizedDescription ?? "unknown")"
    }
}
