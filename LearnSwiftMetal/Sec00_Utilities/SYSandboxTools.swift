//
//  SYSandboxTools.swift
//  Sec22_RotateArray
//
//  Created by ShenYuanLuo on 2023/4/9.
//

import Foundation

class SYSandboxTools {
    typealias ItemsResult = (folders: [String], files: [String])
    
    public static func documentPath() -> String {
        let paths: [String] = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return paths[0]
    }
    
    public static func cachePath() -> String {
        let paths: [String] = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return paths[0]
    }
    
    public static func appSupportPath() -> String {
        let paths: [String] = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return paths[0]
    }
    
    public static func libraryPath() -> String {
        let paths: [String] = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        return 0 < paths.count ? paths[0] : ""
    }
    
    public static func isExistFolder(at path: String) -> Bool {
        if 0 == path.count {
            return false
        }
        var isDir: ObjCBool = false
        let manager = FileManager.default
        let isExist = manager.fileExists(atPath: path, isDirectory: &isDir)
        if true == isDir.boolValue && true == isExist {
            return true
        }
        return false
    }
    
    public static func isExistFile(at path: String) -> Bool {
        if 0 == path.count {
            return false
        }
        var isDir: ObjCBool = false
        let manager = FileManager.default
        let isExist = manager.fileExists(atPath: path, isDirectory: &isDir)
        if false == isDir.boolValue && true == isExist {
            return true
        }
        return false
    }
    
    @discardableResult
    public static func createFolder(at path: String) -> Bool {
        if 0 == path.count {
            return false
        }
        if isExistFolder(at: path) {
            return true
        }
        do {
            try FileManager.default.createDirectory(atPath: path,
                                                    withIntermediateDirectories: true)
        } catch let error as NSError {
            print("Create folder failed: \(error.localizedDescription)")
            return false
        } catch {
            print("Create folder failed!!!")
            return false
        }
        return true
    }
    
    @discardableResult
    public static func moveFolder(fromPath src: String, toPath dest: String) -> Bool {
        if false == self.isExistFolder(at: src) {
            print("Folder does not exist, cannot be moved")
            return false
        }
        if self.isExistFolder(at: dest) {
            print("Folder already exists, no need to move")
            return false
        }
        do {
            try FileManager.default.moveItem(atPath: src, toPath: dest)
        } catch let error as NSError {
            print("Move folder failed: \(error.localizedDescription)")
            return false
        } catch {
            print("Move folder failed!!!")
            return false
        }
        return true
    }
    
    @discardableResult
    public static func moveFile(fromPath src: String, toPath dest: String) -> Bool {
        if false == self.isExistFile(at: src) {
            print("File does not exist, cannot be moved")
            return false
        }
        if self.isExistFile(at: dest) {
            print("File already exists, no need to move")
            return false
        }
        do {
            try FileManager.default.moveItem(atPath: src, toPath: dest)
        } catch let error as NSError {
            print("Move file failed: \(error.localizedDescription)")
            return false
        } catch {
            print("Move file failed!!!")
            return false
        }
        return true
    }
    
    @discardableResult
    public static func deleteFolder(at path: String) -> Bool {
        if false == isExistFolder(at: path) {
            return true
        }
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch let error as NSError {
            print("Delete folder failed: \(error.localizedDescription)")
            return false
        } catch {
            print("Delete folder failed!!!")
            return false
        }
        return true
    }
    
    @discardableResult
    public static func deleteFile(at path: String) -> Bool {
        if false == isExistFile(at: path) {
            return true
        }
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch let error as NSError {
            print("Delete file failed: \(error.localizedDescription)")
            return false
        } catch {
            print("Delete file failed!!!")
            return false
        }
        return true
    }
    
    public static func allFolders(at path: String) -> [String] {
        if false ==  self.isExistFolder(at: path) {
            return []
        }
        do {
            let arr = try FileManager.default.contentsOfDirectory(atPath: path)
            var folders: [String] = []
            for p in arr {
                if self.isExistFolder(at: String(format: "%@/%@", path, p)) {
                    folders.append(p)
                }
            }
            return folders
        } catch let error as NSError {
            print("Get folders failed: \(error.localizedDescription)")
            return []
        } catch {
            print("Get folders failed!!!")
            return []
        }
    }
    
    public static func allFiles(at path: String) -> [String] {
        if false ==  self.isExistFolder(at: path) {
            return []
        }
        do {
            let arr = try FileManager.default.contentsOfDirectory(atPath: path)
            var files: [String] = []
            for p in arr {
                if self.isExistFile(at: path + "/" + p) {
                    files.append(p)
                }
            }
            return files
        } catch let error as NSError {
            print("Get files failed: \(error.localizedDescription)")
            return []
        } catch {
            print("Get files failed!!!")
            return []
        }
    }
    
    public static func allItems(at path: String) -> ItemsResult {
        if false ==  self.isExistFolder(at: path) {
            return ([], [])
        }
        var items: [String] = []
        do {
            items = try FileManager.default.contentsOfDirectory(atPath: path)
            var files: [String] = []
            var folders: [String] = []
            for item in items {
                if self.isExistFolder(at: path + "/" + item) {
                    folders.append(item)
                } else if self.isExistFile(at: path + "/" + item) {
                    files.append(item)
                }
            }
            return (folders, files)
        } catch let error as NSError {
            print("Failed to fetch all files+folders: \(path), error: \(error)")
            return ([], [])
        } catch {
            print("Failed to fetch all files+folders: \(path)")
            return ([], [])
        }
    }
    
}
