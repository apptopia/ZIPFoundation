//
//  ZIPFoundationFileManagerTests.swift
//  ZIPFoundation
//
//  Copyright © 2017-2019 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import XCTest
@testable import ZIPFoundation

extension ZIPFoundationTests {
    func testZipItem() {
        let fileManager = FileManager()
        let assetURL = self.resourceURL(for: #function, pathExtension: "png")
        var fileArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        fileArchiveURL.appendPathComponent(self.archiveName(for: #function))
        do {
            try fileManager.zipItem(at: assetURL, to: fileArchiveURL)
        } catch { XCTFail("Failed to zip item at URL:\(assetURL)") }
        guard let archive = Archive(url: fileArchiveURL, accessMode: .read) else {
            XCTFail("Failed to read archive."); return
        }
        XCTAssertNotNil(archive[assetURL.lastPathComponent])
        XCTAssert(archive.checkIntegrity())
        var directoryURL = ZIPFoundationTests.tempZipDirectoryURL
        directoryURL.appendPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        var directoryArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        let pathComponent = self.archiveName(for: #function, suffix: "Directory")
        directoryArchiveURL.appendPathComponent(pathComponent)
        var parentDirectoryArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        let parentPathComponent = self.archiveName(for: #function, suffix: "ParentDirectory")
        parentDirectoryArchiveURL.appendPathComponent(parentPathComponent)
        var compressedDirectoryArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        let compressedPathComponent = self.archiveName(for: #function, suffix: "CompressedDirectory")
        compressedDirectoryArchiveURL.appendPathComponent(compressedPathComponent)
        let newAssetURL = directoryURL.appendingPathComponent(assetURL.lastPathComponent)
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: directoryURL.appendingPathComponent("nested"),
                                            withIntermediateDirectories: true, attributes: nil)
            try fileManager.copyItem(at: assetURL, to: newAssetURL)
            try fileManager.createSymbolicLink(at: directoryURL.appendingPathComponent("link"),
                                               withDestinationURL: newAssetURL)
            try fileManager.zipItem(at: directoryURL, to: directoryArchiveURL)
            try fileManager.zipItem(at: directoryURL, to: parentDirectoryArchiveURL, shouldKeepParent: false)
            try fileManager.zipItem(at: directoryURL, to: compressedDirectoryArchiveURL, compressionMethod: .deflate)
        } catch { XCTFail("Unexpected error while trying to zip via fileManager.") }
        guard let directoryArchive = Archive(url: directoryArchiveURL, accessMode: .read) else {
            XCTFail("Failed to read archive."); return
        }
        XCTAssert(directoryArchive.checkIntegrity())
        guard let parentDirectoryArchive = Archive(url: parentDirectoryArchiveURL, accessMode: .read) else {
            XCTFail("Failed to read archive."); return
        }
        XCTAssert(parentDirectoryArchive.checkIntegrity())
    }

    func testZipItemErrorConditions() {
        let fileManager = FileManager()
        do {
            try fileManager.zipItem(at: URL(fileURLWithPath: "/nothing"), to: URL(fileURLWithPath: "/nowhere"))
            XCTFail("Error when zipping non-existant archive not raised")
        } catch let error as CocoaError { XCTAssert(error.code == CocoaError.fileReadNoSuchFile)
        } catch {
            XCTFail("Unexpected error while trying to zip via fileManager.")
        }
        do {
            try fileManager.zipItem(at: URL(fileURLWithPath: NSTemporaryDirectory()),
                                    to: URL(fileURLWithPath: NSTemporaryDirectory()))
            XCTFail("Error when zipping directory to already existing destination not raised")
        } catch let error as CocoaError { XCTAssert(error.code == CocoaError.fileWriteFileExists)
        } catch { XCTFail("Unexpected error while trying to zip via fileManager.") }
        do {
            let unwritableURL = URL(fileURLWithPath: "/test.zip")
            try fileManager.zipItem(at: URL(fileURLWithPath: NSTemporaryDirectory()), to: unwritableURL)
            XCTFail("Error when zipping to non writable archive not raised")
        } catch let error as Archive.ArchiveError { XCTAssert(error == .unwritableArchive)
        } catch { XCTFail("Unexpected error while trying to zip via fileManager.") }
        var directoryArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        let pathComponent = self.pathComponent(for: #function) + "Directory"
        directoryArchiveURL.appendPathComponent(pathComponent)
        directoryArchiveURL.appendPathExtension("zip")
        var unreadableFileURL = ZIPFoundationTests.tempZipDirectoryURL
        do {
            unreadableFileURL.appendPathComponent(pathComponent)
            unreadableFileURL.appendPathComponent(ProcessInfo.processInfo.globallyUniqueString)
            try fileManager.createParentDirectoryStructure(for: unreadableFileURL)
            let noPermissionAttributes = [FileAttributeKey.posixPermissions: Int16(0o000)]
            let result = fileManager.createFile(atPath: unreadableFileURL.path, contents: nil,
                                                        attributes: noPermissionAttributes)
            XCTAssert(result == true)
            try fileManager.zipItem(at: unreadableFileURL.deletingLastPathComponent(), to: directoryArchiveURL)
        } catch let error as CocoaError {
            XCTAssert(error.code == CocoaError.fileReadNoPermission)
        } catch {
            XCTFail("Unexpected error while trying to zip via fileManager.")
        }
    }

    func testUnzipItem() {
        let fileManager = FileManager()
        let archive = self.archive(for: #function, mode: .read)
        let destinationURL = self.createDirectory(for: #function)
        do {
            try fileManager.unzipItem(at: archive.url, to: destinationURL)
        } catch {
            XCTFail("Failed to extract item."); return
        }
        var itemsExist = false
        for entry in archive {
            let directoryURL = destinationURL.appendingPathComponent(entry.path)
            itemsExist = fileManager.fileExists(atPath: directoryURL.path)
            if !itemsExist { break }
        }
        XCTAssert(itemsExist)
    }

    func testUnzipItemWithPreferredEncoding() {
        let fileManager = FileManager()
        let encoding = String.Encoding.utf8
        let archive = self.archive(for: #function, mode: .read, preferredEncoding: encoding)
        let destinationURL = self.createDirectory(for: #function)
        do {
            try fileManager.unzipItem(at: archive.url, to: destinationURL, preferredEncoding: encoding)
        } catch {
            XCTFail("Failed to extract item."); return
        }
        var itemsExist = false
        for entry in archive {
            let directoryURL = destinationURL.appendingPathComponent(entry.path(using: encoding))
            itemsExist = fileManager.fileExists(atPath: directoryURL.path)
            if !itemsExist { break }
        }
        XCTAssert(itemsExist)
    }

    func testUnzipItemErrorConditions() {
        var nonexistantArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        nonexistantArchiveURL.appendPathComponent("invalid")
        let existingArchiveURL = self.resourceURL(for: #function, pathExtension: "zip")
        let destinationURL = ZIPFoundationTests.tempZipDirectoryURL
        var existingURL = destinationURL
        existingURL.appendPathComponent("test")
        existingURL.appendPathComponent("faust.txt")
        let fileManager = FileManager()
        do {
            try fileManager.unzipItem(at: nonexistantArchiveURL, to: ZIPFoundationTests.tempZipDirectoryURL)
            XCTFail("Error when unzipping non-existant archive not raised")
        } catch let error as CocoaError {
            XCTAssertTrue(error.code == CocoaError.fileReadNoSuchFile)
        } catch { XCTFail("Unexpected error while trying to unzip via fileManager."); return }
        do {
            try fileManager.createParentDirectoryStructure(for: existingURL)
            fileManager.createFile(atPath: existingURL.path, contents: Data(), attributes: nil)
            try fileManager.unzipItem(at: existingArchiveURL, to: destinationURL)
            XCTFail("Error when unzipping archive to existing destination not raised")
        } catch let error as CocoaError {
            XCTAssertTrue(error.code == CocoaError.fileWriteFileExists)
        } catch {
            XCTFail("Unexpected error while trying to unzip via fileManager."); return
        }
        let nonZipArchiveURL = self.resourceURL(for: #function, pathExtension: "png")
        do {
            try fileManager.unzipItem(at: nonZipArchiveURL, to: destinationURL)
            XCTFail("Error when trying to unzip non-archive not raised")
        } catch let error as Archive.ArchiveError {
            XCTAssertTrue(error == .unreadableArchive)
        } catch { XCTFail("Unexpected error while trying to unzip via fileManager."); return }
    }

    func testDirectoryCreationHelperMethods() {
        let processInfo = ProcessInfo.processInfo
        var nestedURL = ZIPFoundationTests.tempZipDirectoryURL
        nestedURL.appendPathComponent(processInfo.globallyUniqueString)
        nestedURL.appendPathComponent(processInfo.globallyUniqueString)
        do {
            try FileManager().createParentDirectoryStructure(for: nestedURL)
        } catch { XCTFail("Failed to create parent directory.") }
    }

    func testFileAttributeHelperMethods() {
        let cdsBytes: [UInt8] = [0x50, 0x4b, 0x01, 0x02, 0x1e, 0x15, 0x14, 0x00,
                                 0x08, 0x08, 0x08, 0x00, 0xab, 0x85, 0x77, 0x47,
                                 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0xb0, 0x11, 0x00, 0x00, 0x00, 0x00]
        guard let cds = Entry.CentralDirectoryStructure(data: Data(cdsBytes),
                                                        additionalDataProvider: { count -> Data in
                                                            guard let pathData = "/".data(using: .utf8) else {
                                                                throw AdditionalDataError.encodingError
                                                            }
                                                            XCTAssert(count == pathData.count)
                                                            return pathData
        }) else {
            XCTFail("Failed to read central directory structure."); return
        }
        let lfhBytes: [UInt8] = [0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x08, 0x08,
                                 0x08, 0x00, 0xab, 0x85, 0x77, 0x47, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        guard let lfh = Entry.LocalFileHeader(data: Data(lfhBytes),
                                              additionalDataProvider: { _ -> Data in
                                                return Data()
        }) else {
            XCTFail("Failed to read local file header."); return
        }
        guard let entry = Entry(centralDirectoryStructure: cds, localFileHeader: lfh, dataDescriptor: nil) else {
            XCTFail("Failed to create test entry."); return
        }
        var attributes = FileManager.attributes(from: entry)
        guard let permissions = attributes[.posixPermissions] as? UInt16 else {
            XCTFail("Failed to read file attributes."); return
        }
        XCTAssert(permissions == defaultDirectoryPermissions)
    }

    func testFilePermissionHelperMethods() {
        var permissions = FileManager.permissions(for: UInt32(777), osType: .unix, entryType: .file)
        XCTAssert(permissions == defaultFilePermissions)
        permissions = FileManager.permissions(for: UInt32(0), osType: .msdos, entryType: .file)
        XCTAssert(permissions == defaultFilePermissions)
        permissions = FileManager.permissions(for: UInt32(0), osType: .msdos, entryType: .directory)
        XCTAssert(permissions == defaultDirectoryPermissions)
    }

    func testFileModificationDateHelperMethods() {
        guard let nonFileURL = URL(string: "https://www.peakstep.com/") else {
            XCTFail("Failed to create file URL."); return
        }
        let nonExistantURL = URL(fileURLWithPath: "/nonexistant")
        do {
            _ = try FileManager.fileModificationDateTimeForItem(at: nonFileURL)
            _ = try FileManager.fileModificationDateTimeForItem(at: nonExistantURL)
        } catch let error as CocoaError {
            XCTAssert(error.code == CocoaError.fileReadNoSuchFile)
        } catch {
            XCTFail("Unexpected error while trying to retrieve file modification date")
        }
        let msDOSDate = Date(timeIntervalSince1970: TimeInterval(Int.min)).fileModificationDate
        XCTAssert(msDOSDate == 0)
        let msDOSTime = Date(timeIntervalSince1970: TimeInterval(Int.min)).fileModificationTime
        XCTAssert(msDOSTime == 0)
        let invalidEarlyMSDOSDate = Date(timeIntervalSince1970: 0).fileModificationDate
        XCTAssert(invalidEarlyMSDOSDate == 33)
        let invalidLateMSDOSDate = Date(timeIntervalSince1970: 4102444800).fileModificationDate
        XCTAssert(invalidLateMSDOSDate == 60961)
    }

    func testFileSizeHelperMethods() {
        let nonExistantURL = URL(fileURLWithPath: "/nonexistant")
        do {
            _ = try FileManager.fileSizeForItem(at: nonExistantURL)
        } catch let error as CocoaError {
            XCTAssert(error.code == CocoaError.fileReadNoSuchFile)
        } catch { XCTFail("Unexpected error while trying to retrieve file size") }
    }

    func testFileTypeHelperMethods() {
        let nonExistantURL = URL(fileURLWithPath: "/nonexistant")
        do {
            _ = try FileManager.typeForItem(at: nonExistantURL)
        } catch let error as CocoaError {
            XCTAssert(error.code == CocoaError.fileReadNoSuchFile)
        } catch {
            XCTFail("Unexpected error while trying to retrieve file type")
        }
        guard let nonFileURL = URL(string: "https://www.peakstep.com") else {
            XCTFail("Failed to create test URL."); return
        }
        do {
            _ = try FileManager.typeForItem(at: nonFileURL)
        } catch let error as CocoaError {
            XCTAssert(error.code == CocoaError.fileReadNoSuchFile)
        } catch {
            XCTFail("Unexpected error while trying to retrieve file type")
        }
    }

    func testFileModificationDate() {
        var testDateComponents = DateComponents()
        testDateComponents.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        testDateComponents.timeZone = TimeZone(identifier: "UTC")
        testDateComponents.year = 2000
        testDateComponents.month = 1
        testDateComponents.day = 1
        testDateComponents.hour = 12
        testDateComponents.minute = 30
        testDateComponents.second = 10
        guard let testDate = testDateComponents.date else {
            XCTFail("Failed to create test date/timestamp"); return
        }
        let assetURL = self.resourceURL(for: #function, pathExtension: "png")
        let fileManager = FileManager()
        let archive = self.archive(for: #function, mode: .create)
        do {
            try fileManager.setAttributes([.modificationDate: testDate], ofItemAtPath: assetURL.path)
            let relativePath = assetURL.lastPathComponent
            let baseURL = assetURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath, relativeTo: baseURL)
            guard let entry = archive["\(assetURL.lastPathComponent)"] else {
                throw Archive.ArchiveError.unreadableArchive
            }
            guard let fileDate = entry.fileAttributes[.modificationDate] as? Date else {
                throw CocoaError(CocoaError.fileReadUnknown)
            }
            let currentTimeInterval = testDate.timeIntervalSinceReferenceDate
            let fileTimeInterval = fileDate.timeIntervalSinceReferenceDate
            // ZIP uses MSDOS timestamps, which provide very poor accuracy
            // https://blogs.msdn.microsoft.com/oldnewthing/20151030-00/?p=91881
            XCTAssertEqual(currentTimeInterval, fileTimeInterval, accuracy: 2.0)
        } catch { XCTFail("Failed to test last file modification date") }
    }

    func testPOSIXPermissions() {
        let permissions = NSNumber(value: Int16(0o753))
        let assetURL = self.resourceURL(for: #function, pathExtension: "png")
        let fileManager = FileManager()
        let archive = self.archive(for: #function, mode: .create)
        do {
            try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: assetURL.path)
            let relativePath = assetURL.lastPathComponent
            let baseURL = assetURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath, relativeTo: baseURL)
            guard let entry = archive["\(assetURL.lastPathComponent)"] else {
                throw Archive.ArchiveError.unreadableArchive
            }
            guard let filePermissions = entry.fileAttributes[.posixPermissions] as? NSNumber else {
                throw CocoaError(CocoaError.fileReadUnknown)
            }
            XCTAssert(permissions.int16Value == filePermissions.int16Value)
        } catch { XCTFail("Failed to test POSIX permissions") }
    }

    func testTraversalAttack() {
        let fileManager = FileManager()
        let archive = self.archive(for: #function, mode: .read)
        let destinationURL = self.createDirectory(for: #function)
        do {
            try fileManager.unzipItem(at: archive.url, to: destinationURL)
        } catch {
            XCTAssert((error as? CocoaError)?.code == .fileReadInvalidFileName); return
        }
        XCTFail("Extraction should fail")
    }

    func testUniqueTemporaryDirectoryURL() {
        let archive = self.archive(for: #function, mode: .create)
        var tempURLs = Set<URL>()
        defer {
            for url in tempURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }
        // We choose 2000 temp directories to test workaround for http://openradar.appspot.com/50553219
        for _ in 1...2000 {
            let tempDir = archive.uniqueTemporaryDirectoryURL()
            XCTAssertFalse(tempURLs.contains(tempDir), "Temp directory URL should be unique. \(tempDir)")
            tempURLs.insert(tempDir)
        }
    }
}
