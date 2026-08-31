import Foundation

public enum AlertRegion: String, CaseIterable, Codable, Sendable, Hashable {
    case kyivCity
    case vinnytsia
    case volyn
    case dnipropetrovsk
    case donetsk
    case zhytomyr
    case zakarpattia
    case zaporizhzhia
    case ivanoFrankivsk
    case kyivOblast
    case kirovohrad
    case luhansk
    case lviv
    case mykolaiv
    case odesa
    case poltava
    case rivne
    case sumy
    case ternopil
    case kharkiv
    case kherson
    case khmelnytskyi
    case cherkasy
    case chernivtsi
    case chernihiv

    public var apiKey: String {
        switch self {
        case .kyivCity:
            "м. Київ"
        case .vinnytsia:
            "Вінницька область"
        case .volyn:
            "Волинська область"
        case .dnipropetrovsk:
            "Дніпропетровська область"
        case .donetsk:
            "Донецька область"
        case .zhytomyr:
            "Житомирська область"
        case .zakarpattia:
            "Закарпатська область"
        case .zaporizhzhia:
            "Запорізька область"
        case .ivanoFrankivsk:
            "Івано-Франківська область"
        case .kyivOblast:
            "Київська область"
        case .kirovohrad:
            "Кіровоградська область"
        case .luhansk:
            "Луганська область"
        case .lviv:
            "Львівська область"
        case .mykolaiv:
            "Миколаївська область"
        case .odesa:
            "Одеська область"
        case .poltava:
            "Полтавська область"
        case .rivne:
            "Рівненська область"
        case .sumy:
            "Сумська область"
        case .ternopil:
            "Тернопільська область"
        case .kharkiv:
            "Харківська область"
        case .kherson:
            "Херсонська область"
        case .khmelnytskyi:
            "Хмельницька область"
        case .cherkasy:
            "Черкаська область"
        case .chernivtsi:
            "Чернівецька область"
        case .chernihiv:
            "Чернігівська область"
        }
    }

    public var title: String {
        title(locale: .current)
    }

    public func title(locale: Locale) -> String {
        let bundle = Self.localizedBundle(for: locale)
        switch self {
        case .kyivCity:
            return String(localized: "Kyiv", bundle: bundle, locale: locale)
        default:
            return String(localized: String.LocalizationValue(apiKey), bundle: bundle, locale: locale)
        }
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        guard let languageCode = locale.language.languageCode?.identifier,
              let path = Bundle.module.path(forResource: languageCode, ofType: "lproj"),
              let localizedBundle = Bundle(path: path)
        else {
            return .module
        }
        return localizedBundle
    }

    public static func from(apiKey: String) -> AlertRegion? {
        allCases.first { $0.apiKey == apiKey }
    }
}
