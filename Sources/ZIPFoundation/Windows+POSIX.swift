#if os(Windows)
    import Foundation
    import WinSDK
    import ucrt

    typealias lstat = _stat
    typealias mode_t = UInt16

    // https://stackoverflow.com/a/58037981/1125248
    // Algorithm: http://howardhinnant.github.io/date_algorithms.html
    private func days_from_epoch(_ y: Int, _ m: Int, _ d: Int) -> Int {
        var y = y
        y -= (m <= 2 ? 1 : 0)
        let era = y / 400
        let yoe = y - era * 400 // [0, 399]
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1 // [0, 365]
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy // [0, 146096]
        return era * 146_097 + doe - 719_468
    }

    func timegm(_ t: inout tm) -> time_t {
        var year = Int(t.tm_year) + 1900
        var month = Int(t.tm_mon)
        if month > 11 {
            year += month / 12
            month %= 12
        } else if month < 0 {
            let years_diff = (11 - month) / 12
            year -= years_diff
            month += 12 * years_diff
        }
        let days_since_epoch = days_from_epoch(year, month + 1, Int(t.tm_mday))

        return 60 * (60 * (24 * days_since_epoch + Int(t.tm_hour)) + Int(t.tm_min)) + Int(t.tm_sec)
    }
#endif
