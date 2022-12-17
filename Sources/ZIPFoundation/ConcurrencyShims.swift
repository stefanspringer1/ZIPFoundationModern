import Foundation

public typealias ProgressCallback = (Double) -> Void

extension FileManager {
    /// Zips the file or directory contents at the specified source URL to the destination URL.
    /// This is simply a (cancellable!) async wrapper on the synchronous API, so we don't do Task.yields or anything yet.
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
    ///   - progressCallback: A progress callback to observe the percentage complete
    /// - Throws: Throws an error if the source item does not exist or the destination URL is not writable.
    public func zipItem(at sourceURL: URL,
                        to destinationURL: URL,
                        shouldKeepParent: Bool = true,
                        compressionMethod: CompressionMethod = .none,
                        progressCallback: ProgressCallback? = nil) async throws {
        try await withCancellableProgress(progressCallback: progressCallback) { progress in
            try self.zipItem(at: sourceURL,
                             to: destinationURL,
                             shouldKeepParent: shouldKeepParent,
                             compressionMethod: compressionMethod,
                             progress: progress)
        }
    }

    /// Unzips the contents at the specified source URL to the destination URL.
    /// This is simply a (cancellable!) async wrapper on the synchronous API, so we don't do Task.yields or anything yet.
    ///
    /// - Parameters:
    ///   - sourceURL: The file URL pointing to an existing ZIP file.
    ///   - destinationURL: The file URL that identifies the destination directory of the unzip operation.
    ///   - skipCRC32: Optional flag to skip calculation of the CRC32 checksum to improve performance.
    ///   - preferredEncoding: Encoding for entry paths. Overrides the encoding specified in the archive.
    ///   - progressCallback: A progress callback to observe the percentage complete.
    /// - Throws: Throws an error if the source item does not exist or the destination URL is not writable.
    public func unzipItem(at sourceURL: URL,
                          to destinationURL: URL,
                          skipCRC32: Bool = false,
                          preferredEncoding: String.Encoding? = nil,
                          progressCallback: ProgressCallback? = nil) async throws {
        try await withCancellableProgress(progressCallback: progressCallback) { progress in
            try self.unzipItem(at: sourceURL,
                               to: destinationURL,
                               skipCRC32: skipCRC32,
                               progress: progress,
                               preferredEncoding: preferredEncoding)
        }
    }
}


func withCancellableProgress<T>(progressCallback: ProgressCallback? = nil, operation: @escaping (Progress) throws -> T) async rethrows -> T {
    let progress = Progress()
    let observer = progress.observe(\.fractionCompleted) { p, _ in
        progressCallback?(p.fractionCompleted)
    }

    return try await withTaskCancellationHandler {
        try await Task {
            try withExtendedLifetime(observer) {
                try operation(progress)
            }
        }.value
    } onCancel: {
        progress.cancel()
    }
}
