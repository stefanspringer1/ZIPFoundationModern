#if os(Windows)
    import Foundation

    typealias mode_t = UInt16

    let S_IFLNK = mode_t(40960)
#endif
