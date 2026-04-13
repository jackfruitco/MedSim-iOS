import Foundation

public enum InterventionDisplayText {
    public static func interventionTypeLabel(
        _ interventionType: String,
        dictionary: [InterventionGroup] = [],
    ) -> String {
        dictionary.first(where: { $0.interventionType == interventionType })?.label
            ?? SimulationEventRegistry.humanizedLabel(interventionType)
    }

    public static func siteLabel(
        siteCode: String?,
        siteLabel: String?,
        interventionType: String? = nil,
        dictionary: [InterventionGroup] = [],
    ) -> String? {
        if let siteLabel, !siteLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return siteLabel
        }

        if
            let interventionType,
            let siteCode,
            let group = dictionary.first(where: { $0.interventionType == interventionType }),
            let label = group.sites.first(where: { $0.code.caseInsensitiveCompare(siteCode) == .orderedSame })?.label
        {
            return label
        }

        guard let siteCode, !siteCode.isEmpty else { return nil }
        return normalizedSiteCode(siteCode)
    }

    public static func normalizedSiteCode(_ siteCode: String) -> String {
        let separatorSet = CharacterSet(charactersIn: "_-")
        let rawTokens = siteCode
            .uppercased()
            .components(separatedBy: separatorSet)
            .filter { !$0.isEmpty }

        guard !rawTokens.isEmpty else { return siteCode }

        let displayTokens = rawTokens.droppingAccessRoutePrefix()
        return displayTokens.map(formatToken).joined(separator: " ")
    }

    private static func formatToken(_ token: String) -> String {
        switch token {
        case "IV", "IO", "AC", "EJ", "ICS", "NPA", "OPA":
            token
        case "PROX":
            "Proximal"
        case "DIST":
            "Distal"
        case "FEM":
            "Femoral"
        case "ANT":
            "Anterior"
        case "LAT":
            "Lateral"
        case "MIDLINE":
            "Midline"
        default:
            token.capitalized
        }
    }
}

private extension [String] {
    func droppingAccessRoutePrefix() -> [String] {
        guard let first, ["IV", "IO"].contains(first), count > 1 else {
            return self
        }
        return Array(dropFirst())
    }
}
