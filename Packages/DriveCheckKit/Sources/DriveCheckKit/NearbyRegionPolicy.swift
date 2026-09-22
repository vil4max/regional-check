/// Product-level proximity policy for surfacing alerts near the selected region.
/// Kyiv city intentionally uses a wider ring than its literal administrative border.
public enum NearbyRegionPolicy {
    public static func activeAlerts(
        near selectedRegion: AlertRegion,
        among activeAlerts: [AlertRegion]
    ) -> [AlertRegion] {
        let active = Set(activeAlerts)
        return nearbyRegions(to: selectedRegion).filter { active.contains($0) }
    }

    /// REQ-SURF-010: the region is surrounded when at least one neighbour is under alert and
    /// either half or more of its neighbours are, or more than half of the country is. It reads
    /// the current snapshot only; it is a warning about the situation now, not a forecast.
    public static func isSurrounded(_ region: AlertRegion, among activeAlerts: [AlertRegion]) -> Bool {
        let alerting = self.activeAlerts(near: region, among: activeAlerts).count
        guard alerting > 0 else { return false }
        let countryAlerting = Set(activeAlerts).count
        return alerting * 2 >= nearbyRegions(to: region).count
            || countryAlerting * 2 > AlertRegion.allCases.count
    }

    public static func isSurrounded(_ region: AlertRegion, snapshot: AlertsSnapshot?) -> Bool {
        guard let snapshot else { return false }
        return isSurrounded(region, among: AlertRegion.allCases.filter { snapshot.status(for: $0) == .alarm })
    }

    public static func nearbyRegions(to region: AlertRegion) -> [AlertRegion] {
        switch region {
        case .kyivCity:
            [.kyivOblast, .chernihiv, .zhytomyr, .cherkasy, .poltava]
        case .vinnytsia:
            [.zhytomyr, .kyivOblast, .cherkasy, .kirovohrad, .odesa, .chernivtsi, .khmelnytskyi]
        case .volyn:
            [.rivne, .lviv]
        case .dnipropetrovsk:
            [.poltava, .kharkiv, .donetsk, .zaporizhzhia, .kherson, .mykolaiv, .kirovohrad]
        case .donetsk:
            [.luhansk, .kharkiv, .dnipropetrovsk, .zaporizhzhia]
        case .zhytomyr:
            [.rivne, .khmelnytskyi, .vinnytsia, .kyivOblast]
        case .zakarpattia:
            [.lviv, .ivanoFrankivsk]
        case .zaporizhzhia:
            [.donetsk, .dnipropetrovsk, .kherson]
        case .ivanoFrankivsk:
            [.zakarpattia, .lviv, .ternopil, .chernivtsi]
        case .kyivOblast:
            [.kyivCity, .zhytomyr, .vinnytsia, .cherkasy, .poltava, .chernihiv]
        case .kirovohrad:
            [.vinnytsia, .cherkasy, .poltava, .dnipropetrovsk, .mykolaiv, .odesa]
        case .luhansk:
            [.kharkiv, .donetsk]
        case .lviv:
            [.volyn, .rivne, .ternopil, .ivanoFrankivsk, .zakarpattia]
        case .mykolaiv:
            [.odesa, .kirovohrad, .dnipropetrovsk, .kherson]
        case .odesa:
            [.vinnytsia, .kirovohrad, .mykolaiv]
        case .poltava:
            [.kyivOblast, .chernihiv, .sumy, .kharkiv, .dnipropetrovsk, .kirovohrad, .cherkasy]
        case .rivne:
            [.volyn, .lviv, .ternopil, .khmelnytskyi, .zhytomyr]
        case .sumy:
            [.chernihiv, .poltava, .kharkiv]
        case .ternopil:
            [.lviv, .rivne, .khmelnytskyi, .chernivtsi, .ivanoFrankivsk]
        case .kharkiv:
            [.sumy, .poltava, .dnipropetrovsk, .donetsk, .luhansk]
        case .kherson:
            [.mykolaiv, .dnipropetrovsk, .zaporizhzhia]
        case .khmelnytskyi:
            [.rivne, .zhytomyr, .vinnytsia, .chernivtsi, .ternopil]
        case .cherkasy:
            [.vinnytsia, .kyivOblast, .poltava, .kirovohrad]
        case .chernivtsi:
            [.ivanoFrankivsk, .ternopil, .khmelnytskyi, .vinnytsia]
        case .chernihiv:
            [.kyivOblast, .poltava, .sumy]
        }
    }
}
