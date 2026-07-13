import RegionalCheckDomain

public struct RegionTitleUseCase: Sendable {
    public init() {}

    public func execute(region: AlertRegion) -> String {
        switch region.kind {
        case .kyivCity:
            return "Kyiv"
        case .oblast(let name):
            return name
        }
    }
}

