import Foundation

/// Content-free technical events (section 13, P07). No media, transcripts, contacts,
/// phone numbers, titles or screen text are ever recorded here.
public struct DiagnosticEvent: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable {
        case lifecycle, sampleRejected, queueOverflow, writerRejected, checkpoint, deadline, resourceState
        case recovery, deletion, validation, purchase, permission, error
    }

    public var sequence: Int
    public var uptime: Double
    public var kind: Kind
    public var session: String?
    public var reason: ReasonCode?
    public var source: SourceKind?
    public var detail: String?
}

public final class DiagnosticsLog: @unchecked Sendable {
    private let lock = NSLock()
    private var ring: [DiagnosticEvent] = []
    private var next = 0
    private let capacity: Int
    private let clock: any MonotonicClock
    private let origin: MonotonicInstant

    public init(capacity: Int = 2_000, clock: any MonotonicClock = SystemMonotonicClock()) {
        self.capacity = capacity
        self.clock = clock
        self.origin = clock.now()
    }

    /// `detail` must be a fixed technical token (state name, error code), never user content.
    public func record(_ kind: DiagnosticEvent.Kind, session: UUID? = nil, reason: ReasonCode? = nil,
                       source: SourceKind? = nil, detail: String? = nil) {
        lock.lock(); defer { lock.unlock() }
        let event = DiagnosticEvent(sequence: next, uptime: clock.now().seconds(since: origin), kind: kind,
                                    session: session.map { String($0.uuidString.prefix(8)) }, reason: reason,
                                    source: source, detail: detail.map(Self.sanitize))
        next += 1
        if ring.count < capacity { ring.append(event) } else { ring[event.sequence % capacity] = event }
    }

    public var events: [DiagnosticEvent] {
        lock.lock(); defer { lock.unlock() }
        return ring.sorted { $0.sequence < $1.sequence }
    }

    /// Keeps details to short technical tokens so free text cannot leak into reports.
    static func sanitize(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-:= "))
        let filtered = String(String.UnicodeScalarView(s.unicodeScalars.filter { allowed.contains($0) && $0.isASCII }))
        return String(filtered.prefix(80))
    }

    public struct Report: Codable, Sendable {
        public var generatedAt: Date
        public var appVersion: String
        public var osVersion: String
        public var deviceModel: String
        public var resourceState: String
        public var events: [DiagnosticEvent]
        public var note: String
    }

    /// A user-triggered report. It explains failures without including recording content (T35).
    public func exportReport(appVersion: String, osVersion: String, deviceModel: String, resourceState: String, now: Date) throws -> Data {
        let report = Report(generatedAt: now, appVersion: appVersion, osVersion: osVersion, deviceModel: deviceModel,
                            resourceState: resourceState, events: events,
                            note: "Technical events only. No recordings, titles, audio, transcripts, contacts or screen text are included.")
        return try AtomicJSON.encoder.encode(report)
    }
}
