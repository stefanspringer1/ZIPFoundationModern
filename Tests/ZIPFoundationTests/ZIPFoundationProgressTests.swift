//
//  ZIPFoundationProgressTests.swift
//  ZIPFoundation
//
//  Copyright © 2017-2021 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//
import XCTest
@testable import ZIPFoundation
import CSProgress

extension ZIPFoundationTests {
    func testArchiveAddUncompressedEntryProgress() {
        let archive = archive(for: #function, mode: .update)
        let assetURL = resourceURL(for: #function, pathExtension: "png")
        let progress = archive.makeProgressForAddingItem(at: assetURL)

        let expectation = progress.expectFractionCompleted(0.5)

        let zipQueue = DispatchQueue(label: "ZIPFoundationTests")
        zipQueue.async {
            do {
                let relativePath = assetURL.lastPathComponent
                let baseURL = assetURL.deletingLastPathComponent()
                try archive.addEntry(with: relativePath, relativeTo: baseURL, bufferSize: 1, progress: progress)
            } catch let error as Archive.ArchiveError {
                XCTAssert(error == Archive.ArchiveError.cancelledOperation)
            } catch {
                XCTFail("Failed to add entry to uncompressed folder archive with error : \(error)")
            }
        }
        wait(for: [expectation], timeout: 20.0)
        zipQueue.sync {
            XCTAssert(progress.fractionCompleted > 0.5)
            XCTAssert(archive.checkIntegrity())
        }
    }

    func testArchiveAddCompressedEntryProgress() {
        let archive = archive(for: #function, mode: .update)
        let assetURL = resourceURL(for: #function, pathExtension: "png")
        let progress = archive.makeProgressForAddingItem(at: assetURL)
        let expectation = progress.expectFractionCompleted(0.5)

        let zipQueue = DispatchQueue(label: "ZIPFoundationTests")
        zipQueue.async {
            do {
                let relativePath = assetURL.lastPathComponent
                let baseURL = assetURL.deletingLastPathComponent()
                try archive.addEntry(with: relativePath, relativeTo: baseURL,
                                     compressionMethod: .deflate, bufferSize: 1, progress: progress)
            } catch let error as Archive.ArchiveError {
                XCTAssert(error == Archive.ArchiveError.cancelledOperation)
            } catch {
                XCTFail("Failed to add entry to uncompressed folder archive with error : \(error)")
            }
        }
        wait(for: [expectation], timeout: 20.0)
        zipQueue.sync {
            XCTAssert(progress.fractionCompleted > 0.5)
            XCTAssert(archive.checkIntegrity())
        }
    }

    func testRemoveEntryProgress() {
        let archive = archive(for: #function, mode: .update)
        guard let entryToRemove = archive["test/data.random"] else {
            XCTFail("Failed to find entry to remove in uncompressed folder")
            return
        }
        let progress = archive.makeProgressForRemoving(entryToRemove)
        let expectation = progress.expectFractionCompleted(0.5)
        let zipQueue = DispatchQueue(label: "ZIPFoundationTests")
        zipQueue.async {
            do {
                try archive.remove(entryToRemove, progress: progress)
            } catch let error as Archive.ArchiveError {
                XCTAssert(error == Archive.ArchiveError.cancelledOperation)
            } catch {
                XCTFail("Failed to remove entry from uncompressed folder archive with error : \(error)")
            }
        }
        wait(for: [expectation], timeout: 20.0)
        zipQueue.sync {
            XCTAssert(progress.fractionCompleted > 0.5)
            XCTAssert(archive.checkIntegrity())
        }
    }

    func testZipItemProgress() {
        let fileManager = FileManager()
        let assetURL = resourceURL(for: #function, pathExtension: "png")
        var fileArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        fileArchiveURL.appendPathComponent(archiveName(for: #function))
        let fileProgress = CSProgress()
        let fileExpectation = fileProgress.expectCompleted()

        var didSucceed = true
        let testQueue = DispatchQueue.global()
        testQueue.async {
            do {
                try fileManager.zipItem(at: assetURL, to: fileArchiveURL, progress: fileProgress)
            } catch { didSucceed = false }
        }
        var directoryURL = ZIPFoundationTests.tempZipDirectoryURL
        directoryURL.appendPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        var directoryArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        directoryArchiveURL.appendPathComponent(archiveName(for: #function, suffix: "Directory"))
        let newAssetURL = directoryURL.appendingPathComponent(assetURL.lastPathComponent)
        let directoryProgress = CSProgress()
        let directoryExpectation = directoryProgress.expectCompleted()
        testQueue.async {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                try fileManager.createDirectory(at: directoryURL.appendingPathComponent("nested"),
                                                withIntermediateDirectories: true, attributes: nil)
                try fileManager.copyItem(at: assetURL, to: newAssetURL)
                try fileManager.createSymbolicLink(at: directoryURL.appendingPathComponent("link"),
                                                   withDestinationURL: newAssetURL)
                try fileManager.zipItem(at: directoryURL, to: directoryArchiveURL, progress: directoryProgress)
            } catch { didSucceed = false }
        }
        wait(for: [fileExpectation, directoryExpectation], timeout: 20.0)
        guard let archive = Archive(url: fileArchiveURL, accessMode: .read),
              let directoryArchive = Archive(url: directoryArchiveURL, accessMode: .read)
        else {
            XCTFail("Failed to read archive."); return
        }
        XCTAssert(didSucceed)
        XCTAssert(archive.checkIntegrity())
        XCTAssert(directoryArchive.checkIntegrity())
    }

    func testUnzipItemProgress() {
        let fileManager = FileManager()
        let archive = archive(for: #function, mode: .read)
        let destinationURL = createDirectory(for: #function)
        let progress = CSProgress()
        let expectation = progress.expectCompleted()
        DispatchQueue.global().async {
            do {
                try fileManager.unzipItem(at: archive.url, to: destinationURL, progress: progress)
            } catch {
                XCTFail("Failed to extract item."); return
            }
            var itemsExist = false
            for entry in archive {
                let directoryURL = destinationURL.appendingPathComponent(entry.path)
                itemsExist = fileManager.itemExists(at: directoryURL)
                if !itemsExist { break }
            }
            XCTAssert(itemsExist)
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testZIP64ArchiveAddEntryProgress() {
        mockIntMaxValues()
        defer { self.resetIntMaxValues() }
        let archive = archive(for: #function, mode: .update)
        let assetURL = resourceURL(for: #function, pathExtension: "png")
        let progress = archive.makeProgressForAddingItem(at: assetURL)
        let cancel = progress.expectFractionCompleted(0.5)
        let zipQueue = DispatchQueue(label: "ZIPFoundationTests")
        zipQueue.async {
            do {
                let relativePath = assetURL.lastPathComponent
                let baseURL = assetURL.deletingLastPathComponent()
                try archive.addEntry(with: relativePath, relativeTo: baseURL,
                                     compressionMethod: .deflate, bufferSize: 1, progress: progress)
            } catch let error as Archive.ArchiveError {
                XCTAssert(error == Archive.ArchiveError.cancelledOperation)
            } catch {
                XCTFail("Failed to add entry to uncompressed folder archive with error : \(error)")
            }
        }
        wait(for: [cancel], timeout: 20.0)
        zipQueue.sync {
            XCTAssert(progress.fractionCompleted > 0.5)
            XCTAssert(archive.checkIntegrity())
        }
    }
}

extension CSProgress {
    func expectFractionCompleted(_ reachedAtLeast: Double, description: String? = nil) -> XCTestExpectation {
        let expect: XCTestExpectation
        if let description {
            expect = XCTestExpectation(description: description)
        } else {
            expect = XCTestExpectation()
        }

        addFractionCompletedNotification { done, total, fractionCompleted in
            print("\(done) / \(total)")
            if fractionCompleted >= reachedAtLeast {
                expect.fulfill()
                self.cancel()
            }
        }

        return expect
    }

    func expectCompleted(description: String? = nil) -> XCTestExpectation {
        expectFractionCompleted(1.0, description: description)
    }
}
