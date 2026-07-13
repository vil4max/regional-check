import Testing
import RegionalCheckDomain

struct AlertDomainTests {
    @Test
    func kyivCityRegion_isStable() {
        #expect(AlertRegion.kyivCity == AlertRegion.kyivCity)
    }
}

