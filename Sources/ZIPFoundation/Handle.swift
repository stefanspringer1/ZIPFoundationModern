import Foundation

public class Handle {
    public enum OpenFlags {
        case read
        case write
        case create
        case truncateToZeroLength
        case append
    }

    private enum Backing {
        case memory(MemoryFile)
        case file(FileHandle)
    }

    private let backing: Backing

    public let openFlags: Set<OpenFlags>

    init(openedMemoryFile: MemoryFile, writable: Bool, append: Bool) {
        backing = .memory(openedMemoryFile)

        var flags: Set<OpenFlags> = [.read]
        if writable {
            flags.insert(.write)
        }

        if append {
            flags.insert(.append)
        }

        openFlags = flags
    }

    /// equivalent to `rb`
    public init(forReadingFrom url: URL) throws {
        backing = try .file(.init(forReadingFrom: url))
        openFlags = [.read]
    }

    /// equivalent to `rb+`
    public init(forUpdating url: URL) throws {
        backing = try .file(.init(forUpdating: url))
        openFlags = [.read, .write]
    }

    /// equivalent to `wb+`
    public init(forWriteUpdate url: URL) throws {
        backing = try .file(.init(forWriteUpdate: url))
        openFlags = [.read, .write, .create, .truncateToZeroLength]
    }

    /// equivalent to `ab+`
    public init(forAppendUpdate url: URL) throws {
        backing = try .file(.init(forAppendUpdate: url))
        openFlags = [.read, .write, .create, .append]
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
        guard openFlags.contains(.write) else { throw Data.DataError.unwritableFile }

        switch backing {
        case let .file(file):
            if openFlags.contains(.append) { _ = try seekToEnd() }
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
        guard openFlags.contains(.write) else { throw Data.DataError.unwritableFile }

        switch backing {
        case let .file(file):
            try file.truncate(atOffset: offset)
        case .memory:
            fatalError()
        }
    }
}
