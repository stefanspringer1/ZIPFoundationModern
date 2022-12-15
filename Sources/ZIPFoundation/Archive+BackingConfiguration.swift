//
//  Archive+BackingConfiguration.swift
//  ZIPFoundation
//
//  Copyright © 2017-2021 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import Foundation

extension Archive {

    struct BackingConfiguration {
        let file: Handle
        let endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord
        let zip64EndOfCentralDirectory: ZIP64EndOfCentralDirectory?
        let memoryFile: MemoryFile?

        init(file: Handle,
             endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord,
             zip64EndOfCentralDirectory: ZIP64EndOfCentralDirectory? = nil,
             memoryFile: MemoryFile? = nil) {
            self.file = file
            self.endOfCentralDirectoryRecord = endOfCentralDirectoryRecord
            self.zip64EndOfCentralDirectory = zip64EndOfCentralDirectory
            self.memoryFile = memoryFile
        }
    }

    static func makeBackingConfiguration(for url: URL, mode: AccessMode)
    -> BackingConfiguration? {
        switch mode {
        case .read:
            guard let archiveFile = try? Handle(forReadingFrom: url),
                  let (eocdRecord, zip64EOCD) = Archive.scanForEndOfCentralDirectoryRecord(in: archiveFile) else {
                return nil
            }
            return BackingConfiguration(file: archiveFile,
                                        endOfCentralDirectoryRecord: eocdRecord,
                                        zip64EndOfCentralDirectory: zip64EOCD)
        case .create:
            let endOfCentralDirectoryRecord = EndOfCentralDirectoryRecord(numberOfDisk: 0, numberOfDiskStart: 0,
                                                                          totalNumberOfEntriesOnDisk: 0,
                                                                          totalNumberOfEntriesInCentralDirectory: 0,
                                                                          sizeOfCentralDirectory: 0,
                                                                          offsetToStartOfCentralDirectory: 0,
                                                                          zipFileCommentLength: 0,
                                                                          zipFileCommentData: Data())
            do {
                try endOfCentralDirectoryRecord.data.write(to: url, options: .withoutOverwriting)
            } catch { return nil }
            fallthrough
        case .update:
            guard let archiveFile = try? Handle(forUpdating: url),
                  let (eocdRecord, zip64EOCD) = Archive.scanForEndOfCentralDirectoryRecord(in: archiveFile) else {
                return nil
            }
            try? archiveFile.seek(toOffset: 0)
            return BackingConfiguration(file: archiveFile,
                                        endOfCentralDirectoryRecord: eocdRecord,
                                        zip64EndOfCentralDirectory: zip64EOCD)
        }
    }

    static func makeBackingConfiguration(for data: Data, mode: AccessMode)
    -> BackingConfiguration? {
        let posixMode: String
        switch mode {
        case .read: posixMode = "rb"
        case .create: posixMode = "wb+"
        case .update: posixMode = "rb+"
        }
        let memoryFile = MemoryFile(data: data)
        guard let archiveFile = memoryFile.open(mode: posixMode) else { return nil }

        switch mode {
        case .read:
            guard let (eocdRecord, zip64EOCD) = Archive.scanForEndOfCentralDirectoryRecord(in: archiveFile) else {
                return nil
            }

            return BackingConfiguration(file: archiveFile,
                                        endOfCentralDirectoryRecord: eocdRecord,
                                        zip64EndOfCentralDirectory: zip64EOCD,
                                        memoryFile: memoryFile)
        case .create:
            let endOfCentralDirectoryRecord = EndOfCentralDirectoryRecord(numberOfDisk: 0, numberOfDiskStart: 0,
                                                                          totalNumberOfEntriesOnDisk: 0,
                                                                          totalNumberOfEntriesInCentralDirectory: 0,
                                                                          sizeOfCentralDirectory: 0,
                                                                          offsetToStartOfCentralDirectory: 0,
                                                                          zipFileCommentLength: 0,
                                                                          zipFileCommentData: Data())

            try? archiveFile.write(contentsOf: endOfCentralDirectoryRecord.data)
            fallthrough
        case .update:
            guard let (eocdRecord, zip64EOCD) = Archive.scanForEndOfCentralDirectoryRecord(in: archiveFile) else {
                return nil
            }

            try? archiveFile.seek(toOffset: 0)
            return BackingConfiguration(file: archiveFile,
                                        endOfCentralDirectoryRecord: eocdRecord,
                                        zip64EndOfCentralDirectory: zip64EOCD,
                                        memoryFile: memoryFile)
        }
    }
}
