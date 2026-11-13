import CoreGraphics
import DriveCheckKit
import Foundation
import os

/// One unit of the drawn map: an alert region, or Crimea and Sevastopol, which the app has no status
/// for and draws as Ukraine in the no-data fill (MAP-native AC-2).
enum MapUnit: Hashable, Sendable {
    case region(AlertRegion)
    case crimea
    case sevastopol

    init?(id: String) {
        switch id {
        case "crimea": self = .crimea
        case "sevastopol": self = .sevastopol
        default:
            guard let region = AlertRegion(rawValue: id) else { return nil }
            self = .region(region)
        }
    }
}

/// A unit's rings in the projected box: x from 0 to 1, y from 0 to 1 / `aspectRatio`, y downwards.
struct MapOutline: Sendable {
    let unit: MapUnit
    let rings: [[CGPoint]]
}

/// One unit as `UkraineOutlines.json` stores it: rings as flat x, y pairs.
private struct OutlineFileUnit: Decodable {
    let id: String
    let rings: [[Double]]
}

/// MAP-native: the 27 bundled outlines (`scripts/map/README.md`), parsed once, lazily, at the first
/// map draw. Layout reads the generated `aspectRatio` constant instead, so it never parses JSON.
final class UkraineOutlines: Sendable {
    let outlines: [MapOutline]

    /// `nil` when the bundled file is missing or does not decode; the card then draws no map.
    static let shared: UkraineOutlines? = {
        guard let url = resourceURL, let data = try? Data(contentsOf: url), let outlines = UkraineOutlines(data: data)
        else {
            Logger(subsystem: "vil4max.RegionalCheck", category: "map")
                .fault("UkraineOutlines.json is missing or does not decode")
            return nil
        }
        return outlines
    }()

    static var resourceURL: URL? {
        Bundle.main.url(forResource: "UkraineOutlines", withExtension: "json")
    }

    private struct File: Decodable {
        let units: [OutlineFileUnit]
    }

    /// Fails on any unit it does not know, rather than drawing a map with a hole in it.
    init?(data: Data) {
        guard let file = try? JSONDecoder().decode(File.self, from: data), !file.units.isEmpty else { return nil }
        var outlines: [MapOutline] = []
        for unit in file.units {
            guard let mapUnit = MapUnit(id: unit.id) else { return nil }
            let rings = unit.rings.map { flat in
                stride(from: 0, to: flat.count - 1, by: 2).map { CGPoint(x: flat[$0], y: flat[$0 + 1]) }
            }
            outlines.append(MapOutline(unit: mapUnit, rings: rings))
        }
        self.outlines = outlines
    }

    func outline(for unit: MapUnit) -> MapOutline? {
        outlines.first { $0.unit == unit }
    }
}
