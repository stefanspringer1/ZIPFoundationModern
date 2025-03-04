# NOTE

This is a fork of weichsel's [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) with two goals: 

1. Add portability to non-Apple operating systems by removing the need for having a system-installed `zlib` by simply providing `zlib` C source as a package dependency.
2. Add compatibility for non-POSIX/Linux systems (currently only testing Windows) by removing low-level POSIX/Linux system calls like fopen, funopen, etc. and replacing them with the high level `FileHandle` of Foundation and (for in-memory archives) writing a file handle wrapper for `Data`.

I kept as many of the original tests as possible and added a Windows environment to the test suite. Assume there could be broken stuff, but for my use case it seems to be as stable as the original ZIPFoundation at least on macOS, Linux, and Windows.

The following is an amended readme from the original repo.

# ZIPFoundation

[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20Linux%20|%20Windows-lightgrey.svg)](https://github.com/weichsel/ZIPFoundationModern)

ZIP Foundation is a library to create, read and modify ZIP archive files.  
It is written in Swift and based on [Apple's libcompression](https://developer.apple.com/documentation/compression) for high performance and energy efficiency.  
To learn more about the performance characteristics of the framework, you can read [this blog post](https://thomas.zoechling.me/journal/2017/07/ZIPFoundation.html).

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
    - [Zipping Files and Directories](#zipping-files-and-directories)
    - [Unzipping Archives](#unzipping-archives)
- [Advanced Usage](#advanced-usage)
    - [Accessing individual Entries](#accessing-individual-entries)
    - [Creating Archives](#creating-archives)
    - [Adding and Removing Entries](#adding-and-removing-entries)
    - [Closure based Reading and Writing](#closure-based-reading-and-writing)
    - [In-Memory Archives](#in-memory-archives)    
    - [Progress Tracking and Cancellation](#progress-tracking-and-cancellation)
- [Credits](#credits)
- [License](#license)

## Features

- [x] Modern Swift API
- [x] High Performance Compression and Decompression
- [x] Large File Support
- [x] In-Memory Archives
- [x] Deterministic Memory Consumption
- [x] Linux compatibility
- [x] Windows compatibility
- [x] No 3rd party dependencies even on non-Apple platforms!
- [x] Mostly Comprehensive Unit and Performance Test Coverage
- [x] Complete Documentation

## Installation

### Swift Package Manager
The Swift Package Manager is a dependency manager integrated with the Swift build system. To learn how to use the Swift Package Manager for your project, please read the [official documentation](https://github.com/apple/swift-package-manager/blob/master/Documentation/Usage.md).  
To add ZIP Foundation as a dependency, you have to add it to the `dependencies` of your `Package.swift` file and refer to that dependency in your `target`.

```swift
// swift-tools-version:5.7
import PackageDescription
let package = Package(
    name: "<Your Product Name>",
    dependencies: [
		.package(url: "https://github.com/gregcotten/ZIPFoundationModern.git", branch: "development")
    ],
    targets: [
        .target(
		name: "<Your Target Name>",
		dependencies: [
			.product(name: "ZIPFoundation", package: "ZIPFoundationModern")
		]),
    ]
)
```

After adding the dependency, you can fetch the library with:

```bash
$ swift package resolve
```

## Usage
ZIP Foundation provides two high level methods to zip and unzip items. Both are implemented as extension of `FileManager`.  
The functionality of those methods is modeled after the behavior of the Archive Utility in macOS.  

### Zipping Files and Directories
To zip a single file you simply pass a file URL representing the item you want to zip and a destination URL to `FileManager.zipItem(at sourceURL: URL, to destinationURL: URL)`:

```swift
let fileManager = FileManager()
let currentWorkingPath = fileManager.currentDirectoryPath
var sourceURL = URL(fileURLWithPath: currentWorkingPath)
sourceURL.appendPathComponent("file.txt")
var destinationURL = URL(fileURLWithPath: currentWorkingPath)
destinationURL.appendPathComponent("archive.zip")
do {
    try fileManager.zipItem(at: sourceURL, to: destinationURL)
} catch {
    print("Creation of ZIP archive failed with error:\(error)")
}
```

By default, archives are created without any compression. To create compressed ZIP archives, the optional `compressionMethod` parameter has to be set to `.deflate`.  
The same method also accepts URLs that represent directory items. In that case, `zipItem` adds the directory content of `sourceURL` to the archive.  
By default, a root directory entry named after the `lastPathComponent` of the `sourceURL` is added to the destination archive.  If you don't want to preserve the parent directory of the source in your archive, you can pass `shouldKeepParent: false`.

### Unzipping Archives
To unzip existing archives, you can use `FileManager.unzipItem(at sourceURL: URL, to destinationURL: URL)`.  
This recursively extracts all entries within the archive to the destination URL:

```swift
let fileManager = FileManager()
let currentWorkingPath = fileManager.currentDirectoryPath
var sourceURL = URL(fileURLWithPath: currentWorkingPath)
sourceURL.appendPathComponent("archive.zip")
var destinationURL = URL(fileURLWithPath: currentWorkingPath)
destinationURL.appendPathComponent("directory")
do {
    try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
    try fileManager.unzipItem(at: sourceURL, to: destinationURL)
} catch {
    print("Extraction of ZIP archive failed with error:\(error)")
}
```

## Advanced Usage
ZIP Foundation also allows you to individually access specific entries without the need to extract the whole archive. Additionally it comes with the ability to incrementally update archive contents.

### Accessing individual Entries
To gain access to specific ZIP entries, you have to initialize an `Archive` object with a file URL that represents an existing archive. After doing that, entries can be retrieved via their relative path. `Archive` conforms to `Sequence` and therefore supports subscripting:

```swift
let fileManager = FileManager()
let currentWorkingPath = fileManager.currentDirectoryPath
var archiveURL = URL(fileURLWithPath: currentWorkingPath)
archiveURL.appendPathComponent("archive.zip")
guard let archive = Archive(url: archiveURL, accessMode: .read) else  {
    return
}
guard let entry = archive["file.txt"] else {
    return
}
var destinationURL = URL(fileURLWithPath: currentWorkingPath)
destinationURL.appendPathComponent("out.txt")
do {
    try archive.extract(entry, to: destinationURL)
} catch {
    print("Extracting entry from archive failed with error:\(error)")
}
```

The `extract` method accepts optional parameters that allow you to control compression and memory consumption.  
You can find detailed information about that parameters in the method's documentation.

### Creating Archives
To create a new `Archive`, pass in a non-existing file URL and `AccessMode.create`.

```swift
let currentWorkingPath = fileManager.currentDirectoryPath
var archiveURL = URL(fileURLWithPath: currentWorkingPath)
archiveURL.appendPathComponent("newArchive.zip")
guard let archive = Archive(url: archiveURL, accessMode: .create) else  {
    return
}
```

### Adding and Removing Entries
You can add or remove entries to/from archives that have been opened with `.create` or `.update` `AccessMode`.
To add an entry from an existing file, you can pass a relative path and a base URL to `addEntry`. The relative path identifies the 
entry within the ZIP archive. The relative path and the base URL must form an absolute file URL that points to the file you want to add to
the archive:

```swift
let fileManager = FileManager()
let currentWorkingPath = fileManager.currentDirectoryPath
var archiveURL = URL(fileURLWithPath: currentWorkingPath)
archiveURL.appendPathComponent("archive.zip")
guard let archive = Archive(url: archiveURL, accessMode: .update) else  {
    return
}
var fileURL = URL(fileURLWithPath: currentWorkingPath)
fileURL.appendPathComponent("file.txt")
do {
    try archive.addEntry(with: fileURL.lastPathComponent, relativeTo: fileURL.deletingLastPathComponent())
} catch {
    print("Adding entry to ZIP archive failed with error:\(error)")
}
```

Alternatively, the `addEntry(with path: String, fileURL: URL)` method can be used to add files that are _not_ sharing a common base directory. 
The `fileURL` parameter must contain an absolute file URL that points to a file, symlink or directory on an arbitrary file system location.

The `addEntry` method accepts several optional parameters that allow you to control compression, memory consumption and file attributes.  
You can find detailed information about that parameters in the method's documentation.

To remove an entry, you need a reference to an entry within an archive that you can pass to `removeEntry`:

```swift
guard let entry = archive["file.txt"] else {
    return
}
do {
    try archive.remove(entry)
} catch {
    print("Removing entry from ZIP archive failed with error:\(error)")
}
```

### Closure based Reading and Writing
ZIP Foundation also allows you to consume ZIP entry contents without writing them to the file system. 
The `extract` method accepts a closure of type `Consumer`. This closure is called during extraction until the contents of an entry are exhausted:  

```swift
try archive.extract(entry, consumer: { (data) in
    print(data.count)
})
```   
The `data` passed into the closure contains chunks of the current entry. You can control the chunk size of the entry by providing the optional `bufferSize` parameter.

You can also add entries from an in-memory data source. To do this you have to provide a closure of type `Provider` to the `addEntry` method:

```swift
let string = "abcdefghijkl"
guard let data = string.data(using: .utf8) else { return }
try? archive.addEntry(with: "fromMemory.txt", type: .file, uncompressedSize: UInt64(data.count), bufferSize: 4, provider: { (position, size) -> Data in
    // This will be called until `data` is exhausted (3x in this case).
    return data.subdata(in: position..<position+size)
})
```
The closure is called until enough data has been provided to create an entry of `uncompressedSize`. The closure receives `position` and `size` arguments 
so that you can manage the state of your data source.

### In-Memory Archives
Besides closure based reading and writing of file based archives, ZIP Foundation also provides capabilities to process in-memory archives. 
This allows creation or extraction of archives that only reside in RAM. One use case for this functionality is dynamic creation of ZIP archives that are later sent to a client - without performing any disk IO.  

To work with in-memory archives the `init(data: Data, accessMode: AccessMode)` initializer must be used.  
To _read_ or _update_ an in-memory archive, the passed-in `data` must contain a representation of a valid ZIP archive.  
To _create_ an in-memory archive, the `data` parameter can be omitted:

```swift
let string = "Some string!"
guard let archive = Archive(accessMode: .create),
        let data = string.data(using: .utf8) else { return }
    try? archive.addEntry(with: "inMemory.txt", type: .file, uncompressedSize: UInt64(data.count), bufferSize: 4, provider: { (position, size) -> Data in
        return data.subdata(in: position..<position+size)
    })
let archiveData = archive.data
```

### Progress Tracking and Cancellation
All `Archive` operations take an optional `progress` parameter. By passing in an instance of [Progress](https://developer.apple.com/documentation/foundation/progress), you indicate that
you want to track the progress of the current ZIP operation. ZIP Foundation automatically configures the `totalUnitCount` of the `progress` object and continuously updates its `completedUnitCount`.  
To get notifications about the completed work of the current operation, you can attach a Key-Value Observer to the `fractionCompleted` property of your `progress` object.  
The ZIP Foundation `FileManager` extension methods also accept optional `progress` parameters. `zipItem` and `unzipItem` both automatically create a hierarchy of progress objects that reflect the progress of all items contained in a directory or an archive that contains multiple items.  

The [cancel()](https://developer.apple.com/documentation/foundation/progress/1413832-cancel) method of `Progress` can be used to terminate an unfinished ZIP operation. In case of cancelation, the current operation throws an `ArchiveError.cancelledOperation` exception. 

## Credits

This fork, `ZIPFoundationModern`, is adapted and maintained by [Greg Cotten](https://github.com/gregcotten).     
The original [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) package is written and maintained by [Thomas Zoechling](http://thomas.zoechling.me).


## License

ZIP Foundation is released under the MIT License.  
See [LICENSE](https://github.com/gregcotten/ZIPFoundationModern/blob/master/LICENSE) for details.
