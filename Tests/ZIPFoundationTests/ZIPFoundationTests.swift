//
//  ZIPFoundationTests.swift
//  ZIPFoundation
//
//  Copyright © 2017-2021 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import XCTest
@testable import ZIPFoundation

enum AdditionalDataError: Error {
    case encodingError
    case invalidDataError
}

class ZIPFoundationTests: XCTestCase {
    static var tempZipDirectoryURL: URL = {
        let processInfo = ProcessInfo.processInfo
        var tempZipDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        tempZipDirectory.appendPathComponent("ZipTempDirectory")
        // We use a unique path to support parallel test runs via
        // "swift test --parallel"
        // When using --parallel, setUp() and tearDown() are called
        // multiple times.
        tempZipDirectory.appendPathComponent(processInfo.globallyUniqueString)
        return tempZipDirectory
    }()

    static var resourceDirectoryURL: URL {
        Bundle.module.resourceURL!
    }

    override class func setUp() {
        super.setUp()
        do {
            let fileManager = FileManager()
            if fileManager.itemExists(at: tempZipDirectoryURL) {
                try fileManager.removeItem(at: tempZipDirectoryURL)
            }
            try fileManager.createDirectory(at: tempZipDirectoryURL,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
        } catch {
            XCTFail("Unexpected error while trying to set up test resources.")
        }
    }

    override class func tearDown() {
        do {
            let fileManager = FileManager()
            try fileManager.removeItem(at: tempZipDirectoryURL)
        } catch {
            XCTFail("Unexpected error while trying to clean up test resources.")
        }
        super.tearDown()
    }

    // MARK: - Helpers

    func archive(for testFunction: String, mode: Archive.AccessMode,
                 preferredEncoding: String.Encoding? = nil) -> Archive
    {
        var sourceArchiveURL = ZIPFoundationTests.resourceDirectoryURL
        sourceArchiveURL.appendPathComponent(testFunction.replacingOccurrences(of: "()", with: ""))
        sourceArchiveURL.appendPathExtension("zip")
        var destinationArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        destinationArchiveURL.appendPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        destinationArchiveURL.appendPathExtension("zip")
        do {
            if mode != .create {
                let fileManager = FileManager()
                try fileManager.copyItem(at: sourceArchiveURL, to: destinationArchiveURL)
            }
            guard let archive = Archive(url: destinationArchiveURL, accessMode: mode,
                                        preferredEncoding: preferredEncoding)
            else {
                throw Archive.ArchiveError.unreadableArchive
            }
            return archive
        } catch Archive.ArchiveError.unreadableArchive {
            XCTFail("Failed to get test archive '\(destinationArchiveURL.lastPathComponent)'")
            type(of: self).tearDown()
            preconditionFailure()
        } catch {
            XCTFail("File system error: \(error)")
            type(of: self).tearDown()
            preconditionFailure()
        }
    }

    func pathComponent(for testFunction: String) -> String {
        testFunction.replacingOccurrences(of: "()", with: "")
    }

    func archiveName(for testFunction: String, suffix: String = "") -> String {
        let archiveName = testFunction.replacingOccurrences(of: "()", with: "")
        return archiveName.appending(suffix).appending(".zip")
    }

    func resourceURL(for testFunction: String, pathExtension: String) -> URL {
        var sourceAssetURL = ZIPFoundationTests.resourceDirectoryURL
        sourceAssetURL.appendPathComponent(testFunction.replacingOccurrences(of: "()", with: ""))
        sourceAssetURL.appendPathExtension(pathExtension)
        var destinationAssetURL = ZIPFoundationTests.tempZipDirectoryURL
        destinationAssetURL.appendPathComponent(sourceAssetURL.lastPathComponent)
        do {
            let fileManager = FileManager()
            try fileManager.copyItem(at: sourceAssetURL, to: destinationAssetURL)
            return destinationAssetURL
        } catch {
            XCTFail("Failed to get test resource '\(destinationAssetURL.lastPathComponent)'")
            type(of: self).tearDown()
            preconditionFailure()
        }
    }

    func createDirectory(for testFunction: String) -> URL {
        let fileManager = FileManager()
        var URL = ZIPFoundationTests.tempZipDirectoryURL
        URL = URL.appendingPathComponent(pathComponent(for: testFunction))
        do {
            try fileManager.createDirectory(at: URL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to get create directory for test function:\(testFunction)")
            type(of: self).tearDown()
            preconditionFailure()
        }
        return URL
    }

    #if !os(Windows)
    func runWithFileDescriptorLimit(_ limit: UInt64, handler: () -> Void) {
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(Android)
            let fileNoFlag = RLIMIT_NOFILE
        #else
            let fileNoFlag = Int32(RLIMIT_NOFILE.rawValue)
        #endif
        var storedRlimit = rlimit()
        getrlimit(fileNoFlag, &storedRlimit)
        var tempRlimit = storedRlimit
        tempRlimit.rlim_cur = rlim_t(limit)
        setrlimit(fileNoFlag, &tempRlimit)
        defer { setrlimit(fileNoFlag, &storedRlimit) }
        handler()
    }
    #endif

    func runWithoutMemory(handler: () -> Void) {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let systemAllocator = CFAllocatorGetDefault().takeUnretainedValue()
            CFAllocatorSetDefault(kCFAllocatorNull)
            defer { CFAllocatorSetDefault(systemAllocator) }
            handler()
        #endif
    }

    // MARK: - ZIP64 Helpers

    // It's not practical to create compressed files that exceed the size limit every time for test,
    // so provide helper methods to mock the maximum size limit

    func mockIntMaxValues(int32Factor: Int = 64, int16Factor: Int = 64) {
        maxUInt32 = UInt32(int32Factor * int32Factor)
        maxUInt16 = UInt16(int16Factor)
    }

    func resetIntMaxValues() {
        maxUInt32 = .max
        maxUInt16 = .max
    }
}

extension Archive {
    func checkIntegrity() -> Bool {
        var isCorrect = false
        do {
            for entry in self {
                let checksum = try extract(entry, consumer: { _ in })
                isCorrect = checksum == entry.checksum
                guard isCorrect else { break }
            }
        } catch {
            return false
        }
        return isCorrect
    }
}

extension Data {
    static func makeRandomData(size: Int) -> Data {
        let bytes = [UInt32](repeating: 0, count: size).map { _ in UInt32.random(in: 0 ... UInt32.max) }
        return Data(bytes: bytes, count: size)
    }
}

#if os(macOS)
    extension NSUserScriptTask {
        static func makeVolumeCreationTask(at tempDir: URL, volumeName: String) throws -> NSUserScriptTask {
            let scriptURL = tempDir.appendingPathComponent("createVol.sh", isDirectory: false)
            let dmgURL = tempDir.appendingPathComponent(volumeName).appendingPathExtension("dmg")
            let script = """
            #!/bin/bash
            hdiutil create -size 5m -fs HFS+ -type SPARSEBUNDLE -ov -volname "\(volumeName)" "\(dmgURL.path)"
            hdiutil attach -nobrowse "\(dmgURL.appendingPathExtension("sparsebundle").path)"

            """
            try script.write(to: scriptURL, atomically: false, encoding: .utf8)
            let permissions = NSNumber(value: Int16(0o770))
            try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: scriptURL.path)
            return try NSUserScriptTask(url: scriptURL)
        }
    }
#endif
