import Foundation
import Networking
import SharedModels

public enum FeedbackScope: String, Sendable {
    case general
    case simulation
}

public enum FeedbackLabType: String, Sendable {
    case chatlab
    case trainerlab
}

public struct FeedbackLaunchContext: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let scope: FeedbackScope
    public let sourceScreen: String
    public let simulationID: Int?
    public let conversationID: Int?
    public let labType: FeedbackLabType?
    public let simulationDisplayName: String?
    public let simulationStatus: String?
    public let conversationKind: String?

    public init(
        id: UUID = UUID(),
        scope: FeedbackScope,
        sourceScreen: String,
        simulationID: Int? = nil,
        conversationID: Int? = nil,
        labType: FeedbackLabType? = nil,
        simulationDisplayName: String? = nil,
        simulationStatus: String? = nil,
        conversationKind: String? = nil,
    ) {
        self.id = id
        self.scope = scope
        self.sourceScreen = sourceScreen
        self.simulationID = simulationID
        self.conversationID = conversationID
        self.labType = labType
        self.simulationDisplayName = simulationDisplayName
        self.simulationStatus = simulationStatus
        self.conversationKind = conversationKind
    }

    public var defaultCategory: FeedbackCategory {
        switch scope {
        case .general:
            .other
        case .simulation:
            .simulationContent
        }
    }

    public var attachedContextLines: [String] {
        var lines: [String] = []
        if let simulationID {
            if let simulationDisplayName, !simulationDisplayName.isEmpty {
                lines.append("\(simulationDisplayName) (Simulation #\(simulationID))")
            } else {
                lines.append("Simulation #\(simulationID)")
            }
        }
        if let conversationID {
            lines.append("Conversation #\(conversationID)")
        }
        if let labType {
            lines.append(labType.rawValue.capitalized)
        }
        if let simulationStatus, !simulationStatus.isEmpty {
            lines.append("Status: \(simulationStatus)")
        }
        return lines
    }

    public func requestContext(appVersion: String) -> [String: JSONValue] {
        var context: [String: JSONValue] = [
            "source_screen": .string(sourceScreen),
            "submission_scope": .string(scope.rawValue),
            "app_version": .string(appVersion),
        ]

        if let labType {
            context["lab_type"] = .string(labType.rawValue)
        }
        if let conversationKind, !conversationKind.isEmpty {
            context["active_conversation_kind"] = .string(conversationKind)
        }
        if let simulationStatus, !simulationStatus.isEmpty {
            context["simulation_status"] = .string(simulationStatus)
        }
        if let simulationDisplayName, !simulationDisplayName.isEmpty {
            context["simulation_name"] = .string(simulationDisplayName)
        }
        return context
    }
}
