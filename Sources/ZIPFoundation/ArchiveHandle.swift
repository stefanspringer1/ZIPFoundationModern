import Foundation

public class ArchiveHandle {
    public enum OpenFlags {
        case read
        case write
        case create
        case truncateToZeroLength
        case append
    }

    enum Backing {
        case memory(MemoryFile)
        case file(FileHandle)
    }

    let backing: Backing

    public let openFlags: Set<OpenFlags>

    public init(data: Data, accessMode: Archive.AccessMode) {
        backing = .memory(.init(data: data))

        switch accessMode {
        case .read:
            openFlags = [.read]
        case .update:
            openFlags = [.read, .write]
        case .create:
            openFlags = [.read, .write, .create, .truncateToZeroLength]
        }
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
        case let .memory(mem):
            return mem.seek(toOffset: offset)
        }
    }

    public func readToEnd() throws -> Data? {
        switch backing {
        case let .file(file):
            return try file.readToEnd()
        case let .memory(mem):
            return try mem.readToEnd()
        }
    }

    public func read(upToCount count: Int) throws -> Data? {
        switch backing {
        case let .file(file):
            return try file.read(upToCount: count)
        case let .memory(mem):
            return try mem.read(upToCount: count)
        }
    }

    public func offset() throws -> UInt64 {
        switch backing {
        case let .file(file):
            return try file.offset()
        case let .memory(mem):
            return UInt64(mem.offset)
        }
    }

    public func seekToEnd() throws -> UInt64 {
        switch backing {
        case let .file(file):
            return try file.seekToEnd()
        case let .memory(mem):
            return mem.seekToEnd()
        }
    }

    public func write(contentsOf data: some DataProtocol) throws {
        guard openFlags.contains(.write) else { throw Data.DataError.unwritableFile }

        if openFlags.contains(.append) { _ = try seekToEnd() }

        switch backing {
        case let .file(file):
            try file.write(contentsOf: data)
        case let .memory(mem):
            try mem.write(contentsOf: data)
        }
    }

    public func close() throws {
        switch backing {
        case let .file(file):
            try file.close()
        case let .memory(mem):
            mem.close()
        }
    }

    public func synchronize() throws {
        switch backing {
        case let .file(file):
            try file.synchronize()
        case .memory:
            break
        }
    }

    public func truncate(atOffset offset: UInt64) throws {
        guard openFlags.contains(.write) else { throw Data.DataError.unwritableFile }

        switch backing {
        case let .file(file):
            try file.truncate(atOffset: offset)
        case let .memory(mem):
            try mem.truncate(atOffset: offset)
        }
    }
}
