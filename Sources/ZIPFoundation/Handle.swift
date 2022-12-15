import Foundation

public class Handle {
    private enum Backing {
        case memory(MemoryFile)
        case file(FileHandle)
    }

    private let backing: Backing

    public let writable: Bool
    public let append: Bool

    init(openedMemoryFile: MemoryFile, writable: Bool, append: Bool) {
        backing = .memory(openedMemoryFile)
        self.writable = writable
        self.append = append
    }

    public init(forReadingFrom url: URL) throws {
        backing = try .file(.init(forReadingFrom: url))
        writable = false
        append = false
    }

    public init(forUpdating url: URL) throws {
        backing = try .file(.init(forUpdating: url))
        writable = true
        append = true
    }

    /// like POSIX "a+", creates the file if needed
    public init(forAppendUpdate url: URL) throws {
        backing = try .file(.init(forAppendUpdate: url))
        writable = true
        append = true
    }

    /// like POSIX "w+", creates the file if needed
    public init(forWriteUpdate url: URL) throws {
        backing = try .file(.init(forWriteUpdate: url))
        writable = true
        append = false
    }

    public func seek(toOffset offset: UInt64) throws {
        switch backing {
        case let .file(file):
            return try file.seek(toOffset: offset)
        case .memory:
            fatalError()
        }
    }

    public func readToEnd() throws -> Data? {
        switch backing {
        case let .file(file):
            return try file.readToEnd()
        case .memory:
            fatalError()
        }
    }

    public func read(upToCount count: Int) throws -> Data? {
        switch backing {
        case let .file(file):
            return try file.read(upToCount: count)
        case .memory:
            fatalError()
        }
    }

    public func offset() throws -> UInt64 {
        switch backing {
        case let .file(file):
            return try file.offset()
        case .memory:
            fatalError()
        }
    }

    public func seekToEnd() throws -> UInt64 {
        switch backing {
        case let .file(file):
            return try file.seekToEnd()
        case .memory:
            fatalError()
        }
    }

    public func write(contentsOf data: some DataProtocol) throws {
        guard writable else { throw Data.DataError.unwritableFile }

        switch backing {
        case let .file(file):
            try file.write(contentsOf: data)
        case .memory:
            fatalError()
        }
    }

    public func close() throws {
        switch backing {
        case let .file(file):
            try file.close()
        case .memory:
            fatalError()
        }
    }

    public func synchronize() throws {
        switch backing {
        case let .file(file):
            try file.synchronize()
        case .memory:
            fatalError()
        }
    }

    public func truncate(atOffset offset: UInt64) throws {
        guard writable else { throw Data.DataError.unwritableFile }

        switch backing {
        case let .file(file):
            try file.truncate(atOffset: offset)
        case .memory:
            fatalError()
        }
    }
}
