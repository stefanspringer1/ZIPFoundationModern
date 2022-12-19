//
//  FileManager+ZIP.swift
//  ZIPFoundation
//
//  Copyright © 2017-2021 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import Foundation
import SystemPackage
import CSProgress

extension FileManager {
    typealias CentralDirectoryStructure = Entry.CentralDirectoryStructure

    /// Zips the file or directory contents at the specified source URL to the destination URL.
    ///
    /// If the item at the source URL is a directory, the directory itself will be
    /// represented within the ZIP `Archive`. Calling this method with a directory URL
    /// `file:///path/directory/` will create an archive with a `directory/` entry at the root level.
    /// You can override this behavior by passing `false` for `shouldKeepParent`. In that case, the contents
    /// of the source directory will be placed at the root of the archive.
    /// - Parameters:
    ///   - sourceURL: The file URL pointing to an existing file or directory.
    ///   - destinationURL: The file URL that identifies the destination of the zip operation.
    ///   - shouldKeepParent: Indicates that the directory name of a source item should be used as root element
    ///                       within the archive. Default is `true`.
    ///   - compressionMethod: Indicates the `CompressionMethod` that should be applied.
    ///                        By default, `zipItem` will create uncompressed archives.
    ///   - progress: A progress object that can be used to track or cancel the zip operation.
    /// - Throws: Throws an error if the source item does not exist or the destination URL is not writable.
    public func zipItem(at sourceURL: URL, to destinationURL: URL,
                        shouldKeepParent: Bool = true, compressionMethod: CompressionMethod = .none,
                        progress: CSProgress? = nil) throws
    {
        guard itemExists(at: sourceURL) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: sourceURL.path])
        }
        guard !itemExists(at: destinationURL) else {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: destinationURL.path])
        }
        guard let archive = Archive(url: destinationURL, accessMode: .create) else {
            throw Archive.ArchiveError.unwritableArchive
        }
        let isDirectory = try fileTypeForItem(at: sourceURL) == .typeDirectory
        if isDirectory {
            let subPaths = try subpathsOfDirectory(atPath: sourceURL.path)
            var totalUnitCount = Int64(0)
            if let progress {
                totalUnitCount = subPaths.reduce(Int64(0)) {
                    let itemURL = sourceURL.appendingPathComponent($1)
                    let itemSize = archive.totalUnitCountForAddingItem(at: itemURL)
                    return $0 + itemSize
                }
                progress.totalUnitCount = totalUnitCount
            }

            // If the caller wants to keep the parent directory, we use the lastPathComponent of the source URL
            // as common base for all entries (similar to macOS' Archive Utility.app)
            let directoryPrefix = sourceURL.lastPathComponent
            for entryPath in subPaths {
                let finalEntryPath = shouldKeepParent ? directoryPrefix + "/" + entryPath : entryPath
                let finalBaseURL = shouldKeepParent ? sourceURL.deletingLastPathComponent() : sourceURL
                if let progress {
                    let itemURL = sourceURL.appendingPathComponent(entryPath)
                    let entryProgress = archive.makeProgressForAddingItem(at: itemURL)
                    progress.addChild(entryProgress, withPendingUnitCount: entryProgress.totalUnitCount)
                    try archive.addEntry(with: finalEntryPath, relativeTo: finalBaseURL,
                                         compressionMethod: compressionMethod, progress: entryProgress)
                } else {
                    try archive.addEntry(with: finalEntryPath, relativeTo: finalBaseURL,
                                         compressionMethod: compressionMethod)
                }
            }
        } else {
            progress?.totalUnitCount = archive.totalUnitCountForAddingItem(at: sourceURL)
            let baseURL = sourceURL.deletingLastPathComponent()
            try archive.addEntry(with: sourceURL.lastPathComponent, relativeTo: baseURL,
                                 compressionMethod: compressionMethod, progress: progress)
        }
    }

    /// Unzips the contents at the specified source URL to the destination URL.
    ///
    /// - Parameters:
    ///   - sourceURL: The file URL pointing to an existing ZIP file.
    ///   - destinationURL: The file URL that identifies the destination directory of the unzip operation.
    ///   - skipCRC32: Optional flag to skip calculation of the CRC32 checksum to improve performance.
    ///   - progress: A progress object that can be used to track or cancel the unzip operation.
    ///   - preferredEncoding: Encoding for entry paths. Overrides the encoding specified in the archive.
    /// - Throws: Throws an error if the source item does not exist or the destination URL is not writable.
    public func unzipItem(at sourceURL: URL, to destinationURL: URL, skipCRC32: Bool = false,
                          progress: CSProgress? = nil, preferredEncoding: String.Encoding? = nil) throws
    {
        guard itemExists(at: sourceURL) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: sourceURL.path])
        }
        guard let archive = Archive(url: sourceURL, accessMode: .read, preferredEncoding: preferredEncoding) else {
            throw Archive.ArchiveError.unreadableArchive
        }
        // Defer extraction of symlinks until all files & directories have been created.
        // This is necessary because we can't create links to files that haven't been created yet.
        let sortedEntries = archive.sorted { left, right -> Bool in
            switch (left.type, right.type) {
            case (.directory, .file): return true
            case (.directory, .symlink): return true
            case (.file, .symlink): return true
            default: return false
            }
        }
        var totalUnitCount = Int64(0)
        if let progress {
            totalUnitCount = sortedEntries.reduce(0) { $0 + archive.totalUnitCountForReading($1) }
            progress.totalUnitCount = totalUnitCount
        }

        for entry in sortedEntries {
            let path = preferredEncoding == nil ? entry.path : entry.path(using: preferredEncoding!)
            let entryURL = destinationURL.appendingPathComponent(path)
            guard entryURL.isContained(in: destinationURL) else {
                throw CocoaError(.fileReadInvalidFileName,
                                 userInfo: [NSFilePathErrorKey: entryURL.path])
            }
            let crc32: CRC32
            if let progress {
                let entryProgress = archive.makeProgressForReading(entry)
                progress.addChild(entryProgress, withPendingUnitCount: entryProgress.totalUnitCount)
                crc32 = try archive.extract(entry, to: entryURL, skipCRC32: skipCRC32, progress: entryProgress)
            } else {
                crc32 = try archive.extract(entry, to: entryURL, skipCRC32: skipCRC32)
            }

            func verifyChecksumIfNecessary() throws {
                if skipCRC32 == false, crc32 != entry.checksum {
                    throw Archive.ArchiveError.invalidCRC32
                }
            }
            try verifyChecksumIfNecessary()
        }
    }

    // MARK: - Helpers

    func itemExists(at url: URL) -> Bool {
        // Use `URL.checkResourceIsReachable()` instead of `FileManager.fileExists()` here
        // because we don't want implicit symlink resolution.
        // As per documentation, `FileManager.fileExists()` traverses symlinks and therefore a broken symlink
        // would throw a `.fileReadNoSuchFile` false positive error.
        // For ZIP files it may be intended to archive "broken" symlinks because they might be
        // resolvable again when extracting the archive to a different destination.
        (try? url.checkResourceIsReachable()) == true
    }

    func createParentDirectoryStructure(for url: URL) throws {
        let parentDirectoryURL = url.deletingLastPathComponent()
        try createDirectory(at: parentDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    func permissionsForItem(at url: URL) throws -> FilePermissions {
        FilePermissions(rawValue: CInterop.Mode((try attributesOfItem(atPath: url.path)[.posixPermissions] as! NSNumber).uint16Value))
    }

    func fileTypeForItem(at url: URL) throws -> FileAttributeType {
        let typeAny = try attributesOfItem(atPath: url.path)[.type]
        if let string = typeAny as? String {
            return FileAttributeType(rawValue: string)
        } else {
            return typeAny as! FileAttributeType
        }
    }

    func fileModificationDateTimeForItem(at url: URL) throws -> Date {
        try attributesOfItem(atPath: url.path)[.modificationDate] as! Date
    }

    func fileSizeForItem(at url: URL) throws -> UInt64 {
        (try attributesOfItem(atPath: url.path)[.size] as! NSNumber).uint64Value
    }
}

extension Date {
    init(dateTime: (UInt16, UInt16)) {
        var msdosDateTime = Int(dateTime.0)
        msdosDateTime <<= 16
        msdosDateTime |= Int(dateTime.1)
        var unixTime = tm()
        unixTime.tm_sec = Int32((msdosDateTime & 31) * 2)
        unixTime.tm_min = Int32((msdosDateTime >> 5) & 63)
        unixTime.tm_hour = Int32((Int(dateTime.1) >> 11) & 31)
        unixTime.tm_mday = Int32((msdosDateTime >> 16) & 31)
        unixTime.tm_mon = Int32((msdosDateTime >> 21) & 15)
        unixTime.tm_mon -= 1 // UNIX time struct month entries are zero based.
        unixTime.tm_year = Int32(1980 + (msdosDateTime >> 25))
        unixTime.tm_year -= 1900 // UNIX time structs count in "years since 1900".
        let time = timegm(&unixTime)
        self = Date(timeIntervalSince1970: TimeInterval(time))
    }

    var fileModificationDateTime: (UInt16, UInt16) {
        return (self.fileModificationDate, self.fileModificationTime)
    }

    var fileModificationDate: UInt16 {
        var time = time_t(timeIntervalSince1970)
        guard let unixTime = gmtime(&time) else {
            return 0
        }
        var year = unixTime.pointee.tm_year + 1900 // UNIX time structs count in "years since 1900".
        // ZIP uses the MSDOS date format which has a valid range of 1980 - 2099.
        year = year >= 1980 ? year : 1980
        year = year <= 2099 ? year : 2099
        let month = unixTime.pointee.tm_mon + 1 // UNIX time struct month entries are zero based.
        let day = unixTime.pointee.tm_mday
        return (UInt16)(day + (month * 32) + ((year - 1980) * 512))
    }

    var fileModificationTime: UInt16 {
        var time = time_t(timeIntervalSince1970)
        guard let unixTime = gmtime(&time) else {
            return 0
        }
        let hour = unixTime.pointee.tm_hour
        let minute = unixTime.pointee.tm_min
        let second = unixTime.pointee.tm_sec
        return (UInt16)((second / 2) + (minute * 32) + (hour * 2048))
    }
}

public extension URL {
    func isContained(in parentDirectoryURL: URL) -> Bool {
        FilePath(absoluteString).lexicallyNormalized().starts(with: FilePath(parentDirectoryURL.absoluteString).lexicallyNormalized())
    }
}

struct FileAttributes {
    let type: Entry.EntryType
    let permissions: FilePermissions

    init(type: Entry.EntryType, permissions: FilePermissions) {
        self.type = type
        self.permissions = permissions
    }

    init(mode: mode_t, isDirectoryHint: Bool? = nil) {
        if let type = Entry.EntryType(mode: mode) {
            self.type = type
        } else if let isDirectory = isDirectoryHint {
            type = isDirectory ? .directory : .file
        } else {
            fatalError("can't get file attributes for mode \(mode)")
        }

        permissions = .init(rawValue: mode & ~mode_t(S_IFMT))
    }

    init(externalRawValue: UInt32, isDirectoryHint: Bool? = nil) {
        self.init(mode: mode_t(externalRawValue >> 16),
                  isDirectoryHint: isDirectoryHint)
    }

    var rawValue: mode_t {
        type.mode | mode_t(permissions.rawValue)
    }

    var externalRawValue: UInt32 {
        UInt32(rawValue) << 16
    }
}

extension Entry.EntryType {
    var fileType: FileAttributeType {
        switch self {
        case .directory:
            return .typeDirectory
        case .symlink:
            return .typeSymbolicLink
        case .file:
            return .typeRegular
        }
    }
}

extension FileAttributeType {
    var entryType: Entry.EntryType {
        switch self {
        case .typeDirectory:
            return .directory
        case .typeSymbolicLink:
            return .symlink
        case .typeRegular:
            return .file
        default:
            fatalError("can't conver from \(rawValue) to entryType")
        }
    }
}
