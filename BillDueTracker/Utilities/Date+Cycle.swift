import Foundation

extension Date {
    func startOfMonth(in timeZone: TimeZone, calendar baseCalendar: Calendar = .gregorian) -> Date {
        var calendar = baseCalendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    func startOfDay(in timeZone: TimeZone, calendar baseCalendar: Calendar = .gregorian) -> Date {
        var calendar = baseCalendar
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: self)
    }

    func addingMonths(_ value: Int, in timeZone: TimeZone, calendar baseCalendar: Calendar = .gregorian) -> Date {
        var calendar = baseCalendar
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .month, value: value, to: self) ?? self
    }

    func addingYears(_ value: Int, in timeZone: TimeZone, calendar baseCalendar: Calendar = .gregorian) -> Date {
        var calendar = baseCalendar
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .year, value: value, to: self) ?? self
    }

    func addingDays(_ value: Int, in timeZone: TimeZone, calendar baseCalendar: Calendar = .gregorian) -> Date {
        var calendar = baseCalendar
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: value, to: self) ?? self
    }

    static let gregorian = Calendar(identifier: .gregorian)
}

extension Calendar {
    static let gregorian = Calendar(identifier: .gregorian)
}
