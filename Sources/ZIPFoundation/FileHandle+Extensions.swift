import Foundation

extension FileHandle {
    /// like POSIX "a+", creates the file if needed
    convenience init(forAppendUpdate url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        try self.init(forUpdating: url)
    }

    /// like POSIX "w+", creates the file if needed
    convenience init(forWriteUpdate url: URL) throws {
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)

        try self.init(forUpdating: url)
    }
}
