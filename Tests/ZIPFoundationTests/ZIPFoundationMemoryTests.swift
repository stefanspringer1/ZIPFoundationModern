//
//  ZIPFoundationMemoryTests.swift
//  ZIPFoundation
//
//  Copyright © 2017-2021 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import Foundation

import XCTest
@testable import ZIPFoundation

extension ZIPFoundationTests {
    func testExtractUncompressedFolderEntriesFromMemory() {
        let archive = memoryArchive(for: #function, mode: .read)
        for entry in archive {
            do {
                // Test extracting to memory
                var checksum = try archive.extract(entry, bufferSize: 32, consumer: { _ in })
                XCTAssert(entry.checksum == checksum)
                // Test extracting to file
                var fileURL = createDirectory(for: #function)
                fileURL.appendPathComponent(entry.path)
                checksum = try archive.extract(entry, to: fileURL)
                XCTAssert(entry.checksum == checksum)
                let fileManager = FileManager()
                XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path))
                if entry.type == .file {
                    let fileData = try Data(contentsOf: fileURL)
                    let checksum = fileData.crc32(checksum: 0)
                    XCTAssert(checksum == entry.checksum)
                }
            } catch {
                XCTFail("Failed to unzip uncompressed folder entries. Error: \(error)")
            }
        }
        XCTAssert(archive.data != nil)
    }

    func testExtractCompressedFolderEntriesFromMemory() {
        let archive = memoryArchive(for: #function, mode: .read)
        for entry in archive {
            do {
                // Test extracting to memory
                var checksum = try archive.extract(entry, bufferSize: 128, consumer: { _ in })
                XCTAssert(entry.checksum == checksum)
                // Test extracting to file
                var fileURL = createDirectory(for: #function)
                fileURL.appendPathComponent(entry.path)
                checksum = try archive.extract(entry, to: fileURL)
                XCTAssert(entry.checksum == checksum)
                let fileManager = FileManager()
                XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path))
                if entry.type != .directory {
                    let fileData = try Data(contentsOf: fileURL)
                    let checksum = fileData.crc32(checksum: 0)
                    XCTAssert(checksum == entry.checksum)
                }
            } catch {
                XCTFail("Failed to unzip compressed folder entries. Error: \(error)")
            }
        }
    }

    func testCreateArchiveAddUncompressedEntryToMemory() {
        let archive = memoryArchive(for: #function, mode: .create)
        let assetURL = resourceURL(for: #function, pathExtension: "png")
        do {
            let relativePath = assetURL.lastPathComponent
            let baseURL = assetURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath, relativeTo: baseURL)
        } catch {
            XCTFail("Failed to add entry to uncompressed folder archive with error : \(error)")
        }
        XCTAssert(archive.checkIntegrity())
    }

    func testCreateArchiveAddCompressedEntryToMemory() {
        let archive = memoryArchive(for: #function, mode: .create)
        let assetURL = resourceURL(for: #function, pathExtension: "png")
        do {
            let relativePath = assetURL.lastPathComponent
            let baseURL = assetURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath, relativeTo: baseURL, compressionMethod: .deflate)
        } catch {
            XCTFail("Failed to add entry to compressed folder archive with error : \(error)")
        }
        let entry = archive[assetURL.lastPathComponent]
        XCTAssertNotNil(entry)
        XCTAssert(archive.checkIntegrity())
    }

    func testUpdateArchiveRemoveUncompressedEntryFromMemory() {
        let archive = memoryArchive(for: #function, mode: .update)
        XCTAssert(archive.checkIntegrity())
        guard let entryToRemove = archive["original"] else {
            XCTFail("Failed to find entry to remove from memory archive"); return
        }
        do {
            try archive.remove(entryToRemove)
        } catch {
            XCTFail("Failed to remove entry from memory archive with error : \(error)")
        }
        XCTAssert(archive.checkIntegrity())
    }

    func testMemoryArchiveErrorConditions() {
        let data = Data.makeRandomData(size: 1024)
        let invalidArchive = Archive(data: data, accessMode: .read)
        XCTAssertNil(invalidArchive)
        // Trigger the code path that is taken if funopen() fails
        // We can only do this on Apple platforms
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            var unallocatableArchive: Archive?
            runWithoutMemory {
                unallocatableArchive = Archive(data: data, accessMode: .read)
            }
            XCTAssertNil(unallocatableArchive)
        #endif
    }
}

// MARK: - Helpers

extension ZIPFoundationTests {
    func memoryArchive(for testFunction: String, mode: Archive.AccessMode,
                       preferredEncoding: String.Encoding? = nil) -> Archive
    {
        var sourceArchiveURL = ZIPFoundationTests.resourceDirectoryURL
        sourceArchiveURL.appendPathComponent(testFunction.replacingOccurrences(of: "()", with: ""))
        sourceArchiveURL.appendPathExtension("zip")
        do {
            let data = mode == .create ? Data() : try Data(contentsOf: sourceArchiveURL)
            guard let archive = Archive(data: data, accessMode: mode,
                                        preferredEncoding: preferredEncoding)
            else {
                throw Archive.ArchiveError.unreadableArchive
            }
            return archive
        } catch {
            XCTFail("Failed to open memory archive for '\(sourceArchiveURL.lastPathComponent)'. Error: \(error)")
            type(of: self).tearDown()
            preconditionFailure()
        }
    }
}
