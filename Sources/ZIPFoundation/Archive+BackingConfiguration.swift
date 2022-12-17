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
        let handle: ArchiveHandle
        let endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord
        let zip64EndOfCentralDirectory: ZIP64EndOfCentralDirectory?

        init(handle: ArchiveHandle,
             endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord,
             zip64EndOfCentralDirectory: ZIP64EndOfCentralDirectory? = nil)
        {
            self.handle = handle
            self.endOfCentralDirectoryRecord = endOfCentralDirectoryRecord
            self.zip64EndOfCentralDirectory = zip64EndOfCentralDirectory
        }
    }

    static func makeBackingConfiguration(for url: URL, mode: AccessMode)
        -> BackingConfiguration?
    {
        switch mode {
        case .read:
            guard let handle = try? ArchiveHandle(forReadingFrom: url),
                  let (eocdRecord, zip64EOCD) = Archive.scanForEndOfCentralDirectoryRecord(in: handle)
            else {
                return nil
            }
            return BackingConfiguration(handle: handle,
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
                try endOfCentralDirectoryRecord.data.write(to: url, options: [.withoutOverwriting])
            } catch { return nil }
            fallthrough
        case .update:
            guard FileManager.default.isWritableFile(atPath: url.path) else { return nil }

            guard let handle = try? ArchiveHandle(forUpdating: url),
                  let (eocdRecord, zip64EOCD) = Archive.scanForEndOfCentralDirectoryRecord(in: handle)
            else {
                return nil
            }
            try? handle.seek(toOffset: 0)
            return BackingConfiguration(handle: handle,
                                        endOfCentralDirectoryRecord: eocdRecord,
                                        zip64EndOfCentralDirectory: zip64EOCD)
        }
    }

    static func makeBackingConfiguration(for data: Data, mode: AccessMode)
        -> BackingConfiguration?
    {
        let handle = ArchiveHandle(data: data, accessMode: mode)

        switch mode {
        case .read:
            guard let (eocdRecord, zip64EOCD) = Archive.scanForEndOfCentralDirectoryRecord(in: handle) else {
                return nil
            }

            return BackingConfiguration(handle: handle,
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

            try? handle.write(contentsOf: endOfCentralDirectoryRecord.data)
            fallthrough
        case .update:
            guard let (eocdRecord, zip64EOCD) = Archive.scanForEndOfCentralDirectoryRecord(in: handle) else {
                return nil
            }

            try? handle.seek(toOffset: 0)
            return BackingConfiguration(handle: handle,
                                        endOfCentralDirectoryRecord: eocdRecord,
                                        zip64EndOfCentralDirectory: zip64EOCD)
        }
    }
}
