import Foundation

extension FileHandle {
    /// equivalent to `ab+`
    convenience init(forAppendUpdate url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        try self.init(forUpdating: url)
    }

    /// equivalent to `wb+`
    convenience init(forWriteUpdate url: URL) throws {
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)

        try self.init(forUpdating: url)
    }
}
