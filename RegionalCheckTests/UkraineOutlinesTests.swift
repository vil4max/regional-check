import CoreGraphics
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// MAP-native: the bundled outlines the Status map is drawn from.
struct UkraineOutlinesTests {
    private func outlines() throws -> UkraineOutlines {
        try #require(UkraineOutlines.shared, "the bundled outlines did not decode")
    }

    @Test("MAP-native AC-1 every region has exactly one outline, with Crimea and Sevastopol as Ukraine")
    func everyRegionHasOneOutline() throws {
        let outlines = try outlines()
        #expect(outlines.outlines.count == 27)
        let regions = outlines.outlines.compactMap { if case .region(let region) = $0.unit { region } else { nil } }
        #expect(regions.count == AlertRegion.allCases.count)
        #expect(Set(regions) == Set(AlertRegion.allCases))
        #expect(outlines.outlines.contains { $0.unit == .crimea })
        #expect(outlines.outlines.contains { $0.unit == .sevastopol })
        let city = try #require(outlines.outline(for: .region(.kyivCity)))
        let oblast = try #require(outlines.outline(for: .region(.kyivOblast)))
        #expect(city.rings != oblast.rings)
        for outline in outlines.outlines {
            #expect(!outline.rings.isEmpty, "\(outline.unit) has no ring")
            #expect(outline.rings.allSatisfy { $0.count >= 3 }, "\(outline.unit) has a degenerate ring")
        }
    }

    @Test("MAP-native AC-1 Kyiv city and Sevastopol draw over the units that enclose them")
    func enclavesDrawLast() throws {
        let order = try outlines().outlines.map(\.unit)
        #expect(Set(order.suffix(2)) == [.region(.kyivCity), .sevastopol])
    }

    @Test("MAP-native AC-5 the frame is Ukraine's own bounds, with no empty band")
    func frameIsUkrainesBounds() throws {
        let points = try outlines().outlines.flatMap(\.rings).flatMap { $0 }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        #expect(abs((xs.min() ?? 1) - 0) < 0.001)
        #expect(abs((xs.max() ?? 0) - 1) < 0.001)
        #expect(abs((ys.min() ?? 1) - 0) < 0.001)
        let height = (ys.max() ?? 0) - (ys.min() ?? 0)
        let aspect = 1 / height
        #expect(abs(aspect - UkraineOutlines.aspectRatio) / UkraineOutlines.aspectRatio < 0.005)
    }

    @Test("MAP-native AC-9 the outline data is small and parsed once per process")
    func dataIsSmallAndShared() throws {
        let url = try #require(UkraineOutlines.resourceURL)
        let size = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        #expect(size < 100_000)
        #expect(try outlines() === (try #require(UkraineOutlines.shared)))
    }

    @Test("MAP-native AC-11 the bundled outlines name their source and licence")
    func outlinesNameTheirSource() throws {
        let url = try #require(UkraineOutlines.resourceURL)
        let file = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let source = try #require(file["source"] as? String)
        #expect(source.contains("Kartographia"))
        #expect(source.contains("CC BY 3.0 IGO"))
    }

    @Test("MAP-native AC-9 data that does not decode gives no outlines instead of a crash")
    func undecodableDataGivesNothing() {
        #expect(UkraineOutlines(data: Data("{}".utf8)) == nil)
        #expect(UkraineOutlines(data: Data("not json".utf8)) == nil)
        #expect(UkraineOutlines(data: Data(#"{"units":[{"id":"atlantis","rings":[[0,0,1,0,1,1]]}]}"#.utf8)) == nil)
    }
}
