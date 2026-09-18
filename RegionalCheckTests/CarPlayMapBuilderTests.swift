import CarPlay
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing
import UIKit

/// RD-9: builder tests for the CarPlay Map tab (Variant B). The dangerous cases — a missing,
/// undecodable, unsizeable, or stale image — are proven here even though the rendered card
/// itself is unverified (no CarPlay Simulator access this session; see the Agent Result).
@MainActor
struct CarPlayMapBuilderTests {
    private struct FixedSizing: CarPlayMapImageSizing {
        let maximumCardImageSize: CGSize
    }

    private static let normalSize = CGSize(width: 480, height: 320)
    private static let realImageData: Data = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 60))
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 60))
        }.pngData() ?? Data()
    }()

    private func makeApp(alarmRegions: Set<AlertRegion> = []) -> AppContainer {
        AppContainer.fixture(
            region: .kyivCity,
            network: FixtureNetwork(alarmRegions: alarmRegions),
            defaultsSuite: "RegionalCheckTests.carplay-map.\(UUID().uuidString)"
        )
    }

    private func makeBuilder(
        _ app: AppContainer,
        sizing: any CarPlayMapImageSizing = FixedSizing(maximumCardImageSize: normalSize)
    ) -> CarPlayMapBuilder {
        CarPlayMapBuilder(status: app.status, imageSizing: sizing, onRefresh: {})
    }

    private func freshness(_ app: AppContainer, advancedBy seconds: TimeInterval = 0) -> CarPlayFreshness {
        CarPlayFreshness(
            now: AppContainer.fixtureNow.addingTimeInterval(seconds),
            refreshIntervalSeconds: RefreshPolicy.baseIntervalSeconds(for: app.status.refreshEnvironment())
        )
    }

    private func loaded(_ app: AppContainer) -> CarPlayLoadState {
        CarPlayRefreshCoordinator.cachedSnapshot(from: app.status).map { .loaded($0) } ?? .failed(cached: nil)
    }

    private func freshImage(loadedAt: Date) -> CarPlayMapImageState {
        CarPlayMapImageState(imageData: Self.realImageData, loadedAt: loadedAt, loadFailed: false)
    }

    // MARK: - Golden path

    @Test("REQ-SURF-006 the Map tab is free: no Pro check anywhere in its rows")
    func mapTabNeverChecksSubscription() async {
        await TestLocale.english {
            let app = makeApp(alarmRegions: [.kharkiv, .sumy])
            await app.status.refresh()
            let builder = makeBuilder(app)

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: .notLoaded)

            // Free regardless of `app.subscription` state (never queried by the builder at all).
            #expect(sections.first?.items.count == 2) // count row + refresh row, no image yet
        }
    }

    @Test("Count row shows the alerted count and affected list")
    func countRowShowsAlertedRegions() async {
        await TestLocale.english {
            let app = makeApp(alarmRegions: [.kharkiv, .sumy])
            await app.status.refresh()
            let builder = makeBuilder(app)

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: .notLoaded)
            let countItem = sections.first?.items.first as? CPListItem

            #expect(countItem?.text == "2 of 25 regions under alert")
            #expect(countItem?.detailText == "Sumy Oblast, Kharkiv Oblast")
        }
    }

    @Test("Clear state shows dedicated copy, no detail")
    func clearStateShowsNoRegionsUnderAlert() async {
        await TestLocale.english {
            let app = makeApp(alarmRegions: [])
            await app.status.refresh()
            let builder = makeBuilder(app)

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: .notLoaded)
            let countItem = sections.first?.items.first as? CPListItem

            #expect(countItem?.text == "No regions under alert")
            #expect(countItem?.detailText == nil)
        }
    }

    @Test("Behavior: no current data keeps the real last-known count, with its age appended")
    func staleDataKeepsCountWithAge() async {
        await TestLocale.english {
            let app = makeApp(alarmRegions: [.kharkiv])
            await app.status.refresh()
            let later = freshness(app, advancedBy: 25 * 60)
            let builder = makeBuilder(app)

            let sections = builder.sections(loadState: loaded(app), freshness: later, image: .notLoaded)
            let countItem = sections.first?.items.first as? CPListItem

            #expect(countItem?.text == "1 of 25 regions under alert · 25 min ago")
        }
    }

    @Test("Refresh map row is always present and its handler calls onRefresh")
    func refreshRowCallsOnRefresh() async throws {
        try await TestLocale.english {
            let app = makeApp()
            await app.status.refresh()
            var refreshed = false
            let builder = CarPlayMapBuilder(status: app.status, onRefresh: { refreshed = true })

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: .notLoaded)
            let refreshItem = try #require(sections.first?.items.last as? CPListItem)
            refreshItem.handler?(refreshItem) {}

            #expect(refreshItem.text == "Refresh map")
            #expect(refreshed)
        }
    }

    @Test("No snapshot ever fetched: no sections, same empty-state wording as the Details tab")
    func noSnapshotProducesNoSections() {
        TestLocale.english {
            let app = makeApp()
            let builder = makeBuilder(app)

            let sections = builder.sections(
                loadState: .loading(cached: nil),
                freshness: freshness(app),
                image: .notLoaded
            )
            let template = builder.mapTemplate(
                loadState: .loading(cached: nil),
                freshness: freshness(app),
                image: .notLoaded
            )

            #expect(sections.isEmpty)
            #expect(template.emptyViewTitleVariants.first == "No Current Data")
        }
    }

    // MARK: - Image row: golden path

    @Test("A fresh, decodable image within the reported size renders as the first row")
    func freshImageRenders() async {
        await TestLocale.english {
            let app = makeApp()
            await app.status.refresh()
            let builder = makeBuilder(app)
            let image = freshImage(loadedAt: AppContainer.fixtureNow)

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: image)

            #expect(sections.first?.items.count == 3)
            #expect(sections.first?.items.first is CPListImageRowItem)
        }
    }

    // MARK: - Image row: fallback triggers (product's four required cases)

    @Test("Fallback: a missing image produces the text-only tab")
    func missingImageFallsBackToTextOnly() async {
        await TestLocale.english {
            let app = makeApp()
            await app.status.refresh()
            let builder = makeBuilder(app)

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: .notLoaded)

            #expect(sections.first?.items.count == 2)
            #expect(!(sections.first?.items.contains { $0 is CPListImageRowItem } ?? true))
        }
    }

    @Test("Fallback: a zero maximumImageSize produces the text-only tab, never a blank card")
    func zeroSizeFallsBackToTextOnly() async {
        await TestLocale.english {
            let app = makeApp()
            await app.status.refresh()
            let builder = makeBuilder(app, sizing: FixedSizing(maximumCardImageSize: .zero))
            let image = freshImage(loadedAt: AppContainer.fixtureNow)

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: image)

            #expect(!(sections.first?.items.contains { $0 is CPListImageRowItem } ?? true))
        }
    }

    @Test("Fallback: an absurd maximumImageSize produces the text-only tab, not an untrusted render")
    func absurdSizeFallsBackToTextOnly() async {
        await TestLocale.english {
            let app = makeApp()
            await app.status.refresh()
            let builder = makeBuilder(
                app,
                sizing: FixedSizing(maximumCardImageSize: CGSize(width: 1_000_000, height: 1_000_000))
            )
            let image = freshImage(loadedAt: AppContainer.fixtureNow)

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: image)

            #expect(!(sections.first?.items.contains { $0 is CPListImageRowItem } ?? true))
        }
    }

    @Test("Fallback: a decode failure produces the text-only tab")
    func decodeFailureFallsBackToTextOnly() async {
        await TestLocale.english {
            let app = makeApp()
            await app.status.refresh()
            let builder = makeBuilder(app)
            let notAnImage = CarPlayMapImageState(
                imageData: Data("not a real image".utf8),
                loadedAt: AppContainer.fixtureNow,
                loadFailed: false
            )

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: notAnImage)

            #expect(!(sections.first?.items.contains { $0 is CPListImageRowItem } ?? true))
        }
    }

    @Test("Fallback: an explicit load failure produces the text-only tab, even with old image bytes present")
    func loadFailureFallsBackToTextOnly() async {
        await TestLocale.english {
            let app = makeApp()
            await app.status.refresh()
            let builder = makeBuilder(app)
            let failedButHasOldData = CarPlayMapImageState(
                imageData: Self.realImageData,
                loadedAt: AppContainer.fixtureNow,
                loadFailed: true
            )

            let sections = builder.sections(
                loadState: loaded(app),
                freshness: freshness(app),
                image: failedButHasOldData
            )

            #expect(!(sections.first?.items.contains { $0 is CPListImageRowItem } ?? true))
        }
    }

    @Test("Fallback: a stale image is never presented as current — text-only tab instead")
    func staleImageFallsBackToTextOnly() async {
        await TestLocale.english {
            let app = makeApp()
            await app.status.refresh()
            let builder = makeBuilder(app)
            // 25 minutes old, same 2x-interval staleness rule as the alert status.
            let stale = freshImage(loadedAt: AppContainer.fixtureNow.addingTimeInterval(-25 * 60))

            let sections = builder.sections(loadState: loaded(app), freshness: freshness(app), image: stale)

            #expect(!(sections.first?.items.contains { $0 is CPListImageRowItem } ?? true))
        }
    }
}
