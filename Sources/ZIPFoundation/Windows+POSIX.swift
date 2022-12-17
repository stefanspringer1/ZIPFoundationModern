#if os(Windows)
    import Foundation
    import SystemPackage

    typealias mode_t = CInterop.Mode

    let S_IFLNK = mode_t(40960)
#endif
