import Foundation
import os

public enum AlertRegionResolver {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "Region")

    public static func resolve(cityName: String?, administrativeArea: String?) -> AlertRegion? {
        if let city = normalize(cityName), isKyivCity(city) {
            return .kyivCity
        }

        if let area = normalize(administrativeArea) {
            if isKyivCity(area) {
                return .kyivCity
            }
            if let region = matchOblast(area) {
                return region
            }
        }

        if let city = normalize(cityName), let region = matchOblast(city) {
            return region
        }

        let cityDescription = cityName ?? "nil"
        let areaDescription = administrativeArea ?? "nil"
        log.error(
            """
            Unresolved region city=\(cityDescription, privacy: .public) \
            admin=\(areaDescription, privacy: .public)
            """
        )
        return nil
    }

    private static func isKyivCity(_ value: String) -> Bool {
        ["київ", "kyiv", "kiev", "м київ", "m kyiv"].contains(value)
    }

    private static func matchOblast(_ value: String) -> AlertRegion? {
        let candidates = expandedVariants(value)
        for region in AlertRegion.allCases where region != .kyivCity {
            let key = normalize(region.apiKey) ?? ""
            let english = englishName(for: region)
            if candidates.contains(key) || candidates.contains(english) {
                return region
            }
        }
        return nil
    }

    private static func expandedVariants(_ value: String) -> Set<String> {
        let stem = value
            .replacingOccurrences(of: " область", with: "")
            .replacingOccurrences(of: " обл", with: "")
            .replacingOccurrences(of: " oblast", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            value,
            stem,
            stem + " область",
            stem + " oblast"
        ]
    }

    private static func normalize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let collapsed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "ʼ", with: "'")
            .replacingOccurrences(of: ".", with: "")
            .lowercased()
        let spaced = collapsed
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return spaced.isEmpty ? nil : spaced
    }

    private static func englishName(for region: AlertRegion) -> String {
        switch region {
        case .kyivCity:
            "kyiv"
        case .vinnytsia:
            "vinnytsia oblast"
        case .volyn:
            "volyn oblast"
        case .dnipropetrovsk:
            "dnipropetrovsk oblast"
        case .donetsk:
            "donetsk oblast"
        case .zhytomyr:
            "zhytomyr oblast"
        case .zakarpattia:
            "zakarpattia oblast"
        case .zaporizhzhia:
            "zaporizhzhia oblast"
        case .ivanoFrankivsk:
            "ivano-frankivsk oblast"
        case .kyivOblast:
            "kyiv oblast"
        case .kirovohrad:
            "kirovohrad oblast"
        case .luhansk:
            "luhansk oblast"
        case .lviv:
            "lviv oblast"
        case .mykolaiv:
            "mykolaiv oblast"
        case .odesa:
            "odesa oblast"
        case .poltava:
            "poltava oblast"
        case .rivne:
            "rivne oblast"
        case .sumy:
            "sumy oblast"
        case .ternopil:
            "ternopil oblast"
        case .kharkiv:
            "kharkiv oblast"
        case .kherson:
            "kherson oblast"
        case .khmelnytskyi:
            "khmelnytskyi oblast"
        case .cherkasy:
            "cherkasy oblast"
        case .chernivtsi:
            "chernivtsi oblast"
        case .chernihiv:
            "chernihiv oblast"
        }
    }
}
