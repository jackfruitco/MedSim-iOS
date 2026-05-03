import Foundation
import SharedModels

struct RunConsoleOperationalLogRow: Equatable {
    let title: String
    let detail: String?
    let canonicalEventType: String
}

enum RunConsoleOperationalLogPresentation {
    static func recentUniqueItems(from events: [EventEnvelope], limit: Int = 30) -> [EventEnvelope] {
        guard limit > 0 else { return [] }

        var seen = Set<String>()
        var result: [EventEnvelope] = []
        result.reserveCapacity(min(events.count, limit))

        for event in events.reversed() where seen.insert(event.eventID).inserted {
            result.append(event)
            if result.count == limit {
                break
            }
        }

        return result
    }

    static func row(for event: EventEnvelope) -> RunConsoleOperationalLogRow {
        let canonicalEventType = SimulationEventRegistry.canonicalize(event.eventType)
        let title = SimulationEventRegistry.displayTitle(
            for: canonicalEventType,
            payload: event.payload,
        )
        let detail = normalizedDetail(
            SimulationEventRegistry.displayMessage(
                for: canonicalEventType,
                payload: event.payload,
            ),
            title: title,
        )

        return RunConsoleOperationalLogRow(
            title: title,
            detail: detail,
            canonicalEventType: canonicalEventType,
        )
    }

    private static func normalizedDetail(_ detail: String, title: String) -> String? {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed == title || trimmed == "\(title) received." {
            return nil
        }
        return trimmed
    }
}
