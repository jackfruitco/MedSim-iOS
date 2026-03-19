import Foundation
import SharedModels

// MARK: - Laterality / Location decomposition

public extension InterventionSite {
    /// Anatomical location without laterality, e.g. "Arm" from "RIGHT_ARM"
    var locationLabel: String {
        let lower = code.lowercased()
        return lower
            .replacingOccurrences(of: "right_", with: "")
            .replacingOccurrences(of: "left_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    /// "left" or "right" extracted from the code prefix, nil if not bilateral
    var laterality: String? {
        let lower = code.lowercased()
        if lower.hasPrefix("right_") { return "right" }
        if lower.hasPrefix("left_") { return "left" }
        return nil
    }

    /// Sites grouped by locationLabel (e.g. all "Arm" sites together)
    static func grouped(_ sites: [InterventionSite]) -> [(location: String, sites: [InterventionSite])] {
        var order: [String] = []
        var map: [String: [InterventionSite]] = [:]
        for site in sites {
            let key = site.locationLabel
            if map[key] == nil {
                order.append(key)
                map[key] = []
            }
            map[key]!.append(site)
        }
        return order.map { loc in (location: loc, sites: map[loc]!) }
    }
}

// MARK: - Injury → Intervention suggestions

public struct InterventionSuggestion: Sendable {
    public let interventionType: String
    public let label: String
    public let defaultSiteCode: String?

    public init(interventionType: String, label: String, defaultSiteCode: String? = nil) {
        self.interventionType = interventionType
        self.label = label
        self.defaultSiteCode = defaultSiteCode
    }
}

// MARK: - Bundled dictionary

/// In-memory intervention dictionary seeded from this bundle at startup, then
/// replaced by a live fetch from /api/v1/trainerlab/dictionaries/interventions/.
public enum InterventionDictionary {
    // MARK: Bundled data (reflects backend v0.7.5 + TCCC-CPP tier)

    public static let bundled: [InterventionGroup] = basicTCCC + tcccCPP

    // MARK: - Basic TCCC (7 types, currently registered in backend)

    private static let basicTCCC: [InterventionGroup] = [
        InterventionGroup(
            interventionType: "tourniquet",
            label: "Tourniquet",
            sites: [
                InterventionSite(code: "RIGHT_ARM", label: "Right Arm"),
                InterventionSite(code: "LEFT_ARM", label: "Left Arm"),
                InterventionSite(code: "RIGHT_LEG", label: "Right Leg"),
                InterventionSite(code: "LEFT_LEG", label: "Left Leg")
            ]
        ),
        InterventionGroup(
            interventionType: "wound_packing",
            label: "Wound Packing",
            sites: [
                InterventionSite(code: "RIGHT_AXILLA", label: "Right Axilla"),
                InterventionSite(code: "LEFT_AXILLA", label: "Left Axilla"),
                InterventionSite(code: "RIGHT_INGUINAL", label: "Right Inguinal"),
                InterventionSite(code: "LEFT_INGUINAL", label: "Left Inguinal"),
                InterventionSite(code: "RIGHT_NECK", label: "Right Neck"),
                InterventionSite(code: "LEFT_NECK", label: "Left Neck")
            ]
        ),
        InterventionGroup(
            interventionType: "pressure_dressing",
            label: "Pressure Dressing",
            sites: [
                InterventionSite(code: "RIGHT_ARM", label: "Right Arm"),
                InterventionSite(code: "LEFT_ARM", label: "Left Arm"),
                InterventionSite(code: "RIGHT_LEG", label: "Right Leg"),
                InterventionSite(code: "LEFT_LEG", label: "Left Leg")
            ]
        ),
        InterventionGroup(
            interventionType: "npa",
            label: "Nasopharyngeal Airway (NPA)",
            sites: [
                InterventionSite(code: "RIGHT_NARE", label: "Right Nare"),
                InterventionSite(code: "LEFT_NARE", label: "Left Nare")
            ]
        ),
        InterventionGroup(
            interventionType: "opa",
            label: "Oropharyngeal Airway (OPA)",
            sites: [
                InterventionSite(code: "ORAL", label: "Oral")
            ]
        ),
        InterventionGroup(
            interventionType: "needle_decompression",
            label: "Needle Decompression (NCD)",
            sites: [
                InterventionSite(code: "RIGHT_ANTERIOR_CHEST", label: "Right Anterior Chest"),
                InterventionSite(code: "LEFT_ANTERIOR_CHEST", label: "Left Anterior Chest"),
                InterventionSite(code: "RIGHT_LATERAL_CHEST", label: "Right Lateral Chest"),
                InterventionSite(code: "LEFT_LATERAL_CHEST", label: "Left Lateral Chest")
            ]
        ),
        InterventionGroup(
            interventionType: "surgical_cric",
            label: "Surgical Cricothyrotomy",
            sites: [
                InterventionSite(code: "ANTERIOR_NECK_MIDLINE", label: "Anterior Neck Midline")
            ]
        )
    ]

    // MARK: - TCCC-CPP / Tier 4 (paramedic-level; flagged in backend as B4 gap)

    private static let tcccCPP: [InterventionGroup] = [
        InterventionGroup(
            interventionType: "junctional_tourniquet",
            label: "Junctional Tourniquet",
            sites: [
                InterventionSite(code: "JTQ-RIGHT-GROIN", label: "Right Groin"),
                InterventionSite(code: "JTQ-LEFT-GROIN", label: "Left Groin"),
                InterventionSite(code: "JTQ-RIGHT-AXILLA", label: "Right Axilla"),
                InterventionSite(code: "JTQ-LEFT-AXILLA", label: "Left Axilla")
            ]
        ),
        InterventionGroup(
            interventionType: "hemostatic_agent",
            label: "Hemostatic Agent",
            sites: [
                InterventionSite(code: "HA-WOUND-SITE", label: "Wound Site")
            ]
        ),
        InterventionGroup(
            interventionType: "pelvic_binder",
            label: "Pelvic Binder",
            sites: [
                InterventionSite(code: "PB-PELVIS", label: "Pelvis")
            ]
        ),
        InterventionGroup(
            interventionType: "iv_access",
            label: "IV Access",
            sites: [
                InterventionSite(code: "IV-RIGHT-AC", label: "Right Antecubital"),
                InterventionSite(code: "IV-LEFT-AC", label: "Left Antecubital"),
                InterventionSite(code: "IV-RIGHT-EJ", label: "Right External Jugular"),
                InterventionSite(code: "IV-LEFT-EJ", label: "Left External Jugular"),
                InterventionSite(code: "IV-RIGHT-FEM", label: "Right Femoral"),
                InterventionSite(code: "IV-LEFT-FEM", label: "Left Femoral")
            ]
        ),
        InterventionGroup(
            interventionType: "io_access",
            label: "IO Access",
            sites: [
                InterventionSite(code: "IO-RIGHT-PROX-TIBIA", label: "Right Proximal Tibia"),
                InterventionSite(code: "IO-LEFT-PROX-TIBIA", label: "Left Proximal Tibia"),
                InterventionSite(code: "IO-STERNUM", label: "Sternum"),
                InterventionSite(code: "IO-RIGHT-HUMERUS", label: "Right Humerus"),
                InterventionSite(code: "IO-LEFT-HUMERUS", label: "Left Humerus")
            ]
        ),
        InterventionGroup(
            interventionType: "fluid_resuscitation",
            label: "Fluid Resuscitation",
            sites: [
                InterventionSite(code: "FR-IV-LINE", label: "IV Line"),
                InterventionSite(code: "FR-IO-LINE", label: "IO Line")
            ]
        ),
        InterventionGroup(
            interventionType: "blood_transfusion",
            label: "Blood Transfusion / WBCT",
            sites: [
                InterventionSite(code: "BT-IV-LINE", label: "IV Line"),
                InterventionSite(code: "BT-IO-LINE", label: "IO Line")
            ]
        ),
        InterventionGroup(
            interventionType: "advanced_airway",
            label: "Advanced Airway (Intubation)",
            sites: [
                InterventionSite(code: "AA-ORAL-TRACHEA", label: "Oral/Tracheal"),
                InterventionSite(code: "AA-NASAL-TRACHEA", label: "Nasotracheal")
            ]
        ),
        InterventionGroup(
            interventionType: "chest_tube",
            label: "Chest Tube / Finger Thoracostomy",
            sites: [
                InterventionSite(code: "CT-RIGHT-4TH-ICS", label: "Right 4th ICS"),
                InterventionSite(code: "CT-LEFT-4TH-ICS", label: "Left 4th ICS"),
                InterventionSite(code: "CT-RIGHT-5TH-ICS", label: "Right 5th ICS"),
                InterventionSite(code: "CT-LEFT-5TH-ICS", label: "Left 5th ICS")
            ]
        )
    ]

    // MARK: - Injury → Intervention suggestions

    /// Returns suggested intervention types for a given injury category and kind.
    /// Used by the injury detail quick-action sheet.
    public static func suggestions(forCategory category: String, kind: String) -> [InterventionSuggestion] {
        let cat = category.lowercased()
        let k = kind.lowercased()

        // Hemorrhage — limb
        if cat.contains("hemorrhage") || cat.contains("bleeding") {
            if k.contains("arm") || k.contains("hand") || k.contains("forearm") {
                return [
                    InterventionSuggestion(interventionType: "tourniquet", label: "Tourniquet"),
                    InterventionSuggestion(interventionType: "pressure_dressing", label: "Pressure Dressing")
                ]
            }
            if k.contains("leg") || k.contains("thigh") || k.contains("calf") || k.contains("foot") {
                return [
                    InterventionSuggestion(interventionType: "tourniquet", label: "Tourniquet"),
                    InterventionSuggestion(interventionType: "pressure_dressing", label: "Pressure Dressing")
                ]
            }
            // Junctional (groin, axilla, neck, pelvis)
            if k.contains("groin") || k.contains("inguinal") {
                return [
                    InterventionSuggestion(interventionType: "junctional_tourniquet", label: "Junctional Tourniquet"),
                    InterventionSuggestion(interventionType: "wound_packing", label: "Wound Packing")
                ]
            }
            if k.contains("axilla") || k.contains("neck") {
                return [
                    InterventionSuggestion(interventionType: "wound_packing", label: "Wound Packing"),
                    InterventionSuggestion(interventionType: "hemostatic_agent", label: "Hemostatic Agent")
                ]
            }
            if k.contains("pelvi") {
                return [
                    InterventionSuggestion(interventionType: "pelvic_binder", label: "Pelvic Binder"),
                    InterventionSuggestion(interventionType: "wound_packing", label: "Wound Packing")
                ]
            }
            // Generic hemorrhage
            return [
                InterventionSuggestion(interventionType: "wound_packing", label: "Wound Packing"),
                InterventionSuggestion(interventionType: "hemostatic_agent", label: "Hemostatic Agent"),
                InterventionSuggestion(interventionType: "pressure_dressing", label: "Pressure Dressing")
            ]
        }

        // Airway / respiratory
        if cat.contains("airway") || cat.contains("respiratory") || cat.contains("breathing") {
            if k.contains("tension") || k.contains("pneumothorax") {
                return [
                    InterventionSuggestion(interventionType: "needle_decompression", label: "Needle Decompression"),
                    InterventionSuggestion(interventionType: "chest_tube", label: "Chest Tube")
                ]
            }
            if k.contains("obstruction") || k.contains("obstructed") {
                return [
                    InterventionSuggestion(interventionType: "npa", label: "NPA"),
                    InterventionSuggestion(interventionType: "opa", label: "OPA"),
                    InterventionSuggestion(interventionType: "surgical_cric", label: "Surgical Cric")
                ]
            }
            return [
                InterventionSuggestion(interventionType: "npa", label: "NPA"),
                InterventionSuggestion(interventionType: "opa", label: "OPA")
            ]
        }

        // Burns / wounds — generic
        if cat.contains("burn") || cat.contains("wound") || cat.contains("laceration") {
            return [
                InterventionSuggestion(interventionType: "wound_packing", label: "Wound Packing"),
                InterventionSuggestion(interventionType: "pressure_dressing", label: "Pressure Dressing")
            ]
        }

        return []
    }

    // MARK: - Lookup helpers

    /// Find a group by its intervention_type code, checking live cache first.
    public static func group(
        for interventionType: String,
        in live: [InterventionGroup]
    ) -> InterventionGroup? {
        (live.isEmpty ? bundled : live).first { $0.interventionType == interventionType }
    }
}
