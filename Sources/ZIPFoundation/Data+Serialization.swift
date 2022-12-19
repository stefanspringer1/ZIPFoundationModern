//
//  Data+Serialization.swift
//  ZIPFoundation
//
//  Copyright © 2017-2021 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import Foundation

protocol DataSerializable {
    static var size: Int { get }
    init?(data: Data, additionalDataProvider: (Int) throws -> Data)
    var data: Data { get }
}

extension Data {
    enum DataError: Error {
        case unreadableFile
        case unwritableFile
    }

    func scanValue<T>(start: Int) -> T {
        let subdata = subdata(in: start ..< start + MemoryLayout<T>.size)
        return subdata.withUnsafeBytes { $0.load(as: T.self) }
    }

    static func readStruct<T>(from file: ArchiveHandle, at offset: UInt64)
        -> T? where T: DataSerializable
    {
        guard offset <= .max else { return nil }
        try? file.seek(toOffset: offset)
        guard let data = try? readChunk(of: T.size, from: file) else {
            return nil
        }
        let structure = T(data: data, additionalDataProvider: { additionalDataSize -> Data in
            try self.readChunk(of: additionalDataSize, from: file)
        })
        return structure
    }

    static func consumePart(of size: Int64, chunkSize: Int, skipCRC32: Bool = false,
                            provider: Provider, consumer: Consumer) throws -> CRC32
    {
        var checksum = CRC32(0)
        guard size > 0 else {
            try consumer(Data())
            return checksum
        }

        let readInOneChunk = (size < chunkSize)
        var chunkSize = readInOneChunk ? Int(size) : chunkSize
        var bytesRead: Int64 = 0
        while bytesRead < size {
            let remainingSize = size - bytesRead
            chunkSize = remainingSize < chunkSize ? Int(remainingSize) : chunkSize
            let data = try provider(bytesRead, chunkSize)
            try consumer(data)
            if !skipCRC32 {
                checksum = data.crc32(checksum: checksum)
            }
            bytesRead += Int64(chunkSize)
        }
        return checksum
    }

    static func readChunk(of size: Int, from file: ArchiveHandle) throws -> Data {
        guard size > 0 else {
            return Data()
        }

        let data: Data?
        do {
            data = try file.read(upToCount: size)
        } catch {
            throw DataError.unreadableFile
        }

        guard let data else {
            return Data()
        }

        return data
    }

    static func write(chunk: Data, to file: ArchiveHandle) throws -> Int {
        try file.write(contentsOf: chunk)
        return chunk.count
    }

    static func writeLargeChunk(_ chunk: Data,
                                to file: ArchiveHandle) throws -> UInt64
    {
        try file.write(contentsOf: chunk)
        return UInt64(chunk.count)
    }
}
