
import Foundation

enum ExpiryStatus {
    case expired
    case expiringSoon
    case fresh

    var title: String {
        switch self {
        case .expired:
            return "Expired"
        case .expiringSoon:
            return "Expiring Soon"
        case .fresh:
            return "Fresh"
        }
    }
}

enum ExpiryService {

    static func status(
        for expiryDate: Date,
        today: Date = Date()
    ) -> ExpiryStatus {

        let calendar = Calendar.current

        let todayStart = calendar.startOfDay(for: today)
        let expiryStart = calendar.startOfDay(for: expiryDate)

        if expiryStart < todayStart {
            return .expired
        }

        let warningDate = calendar.date(
            byAdding: .day,
            value: 3,
            to: todayStart
        ) ?? todayStart

        if expiryStart <= warningDate {
            return .expiringSoon
        }

        return .fresh
    }
}
