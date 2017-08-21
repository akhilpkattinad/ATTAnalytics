//
//  ATTFileStorage.swift
//  TrackingHelper
//
//  Created by Adarsh GJ on 11/08/17.
//  Copyright © 2017 Sreekanth R. All rights reserved.
//

import UIKit

class ATTFileStorage: NSObject {
    
    var folderPathURL: URL?
   
    let applicationSupportDirectoryURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    
    override init() {
        super.init()
        if let folderPath = applicationSupportDirectoryURL{
            createFolderPath(folderPath)
        }
    }
    init(_ folderPath: URL) {
        super.init()
        createFolderPath(folderPath)
    }
    
    /// createFolderPath
    ///
    /// - Parameter folderPath: path URl
    func createFolderPath(_ folderPath: URL) {
        self.folderPathURL = folderPath
        self.createDirectoryAtURLIfNeeded(folderPath)
    }
    
    /// Create URL correspond to Key
    ///
    /// - Parameter key: key value
    /// - Returns: File URL
    func URLforKey(_ key: String) -> URL? {
        return self.applicationSupportDirectoryURL?.appendingPathComponent(key)
    }
    
    /// Store Content in plist format
    ///
    /// - Parameters:
    ///   - content: content need to store
    ///   - key: Key need to store
    /// - Returns:
    func setPlistForContent(_ content: Any,forKey key:String) -> Bool {
        guard let data = dataFromContent(content) else {
            return false
        }
        return setData(data, forKey: key)
    }
    
    /// Fetch plist for Key
    ///
    /// - Parameter key: Stored key
    /// - Returns: stored content
    func plistForKey(_ key: String) -> Any? {
        guard let plistData = self.dataForKey(key) else {
            return nil
        }
        return self.plistFormData(plistData)
    }
    
    /// Create Plist from Data
    ///
    /// - Parameter data: Data type value
    /// - Returns: Plist content
    func plistFormData(_ data: Data) -> Any? {
        do {
            let plist = try  PropertyListSerialization.propertyList(from: data, options:PropertyListSerialization.ReadOptions(rawValue: 0), format: nil)
            return plist
        }
        catch let error as NSError {
            print(error.localizedDescription)
            return nil
        }
    }

    /// Content convert to Data
    ///
    /// - Parameter plistContent: It may be Dictionary,array or string
    /// - Returns: Data
    func dataFromContent(_ plistContent: Any) -> Data? {
        do {
        let data = try PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0)
            return data
        }
        catch let error as NSError {
            print(error.localizedDescription)
            return nil
        }
    }
    
    /// Create folder directory
    ///
    /// - Parameter pathURL: Directory URL
    func createDirectoryAtURLIfNeeded(_ pathURL: URL)  {
        if FileManager.default.fileExists(atPath: pathURL.path, isDirectory: nil){
            return
        }
        do {
            try FileManager.default.createDirectory(atPath: pathURL.path, withIntermediateDirectories: false, attributes: nil)
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
}
// MARK : ATTStorage

extension ATTFileStorage: ATTStorage {
    
    func setString(_ string: String, forKey key: String) -> Bool {
        return self.setPlistForContent(string, forKey: key)
    }
    func stringForKey(_ key: String) -> String? {
        return self.plistForKey(key) as? String ?? nil
    }
    
    func setDictionary(_ dictionary: [AnyHashable : Any], forKey key: String) -> Bool {
        return self.setPlistForContent(dictionary, forKey: key)
    }
    func dictionaryForKey(_ key: String) -> [AnyHashable : Any]? {
        return self.plistForKey(key) as? [AnyHashable : Any] ?? nil

    }
    func setArray(_ array: [[AnyHashable : Any]], forKey key: String) -> Bool {
        return self.setPlistForContent(array, forKey: key)

    }
    func arrayForKey(_ key: String) -> [[AnyHashable : Any]]? {
        return self.plistForKey(key) as?  [[AnyHashable : Any]] ?? nil
    }
    
    func setData(_ data: Data, forKey key: String) -> Bool {
        guard let keyURL = self.URLforKey(key) else {
            return false
        }
        do{
            try data.write(to: keyURL)
            return true

        }catch let error as NSError {
            print(error.localizedDescription)
            return false
        }
    }
    func dataForKey(_ key: String) -> Data? {
        
        guard let keyURL = self.URLforKey(key) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: keyURL)
            return data
        } catch let error as NSError {
            print(error.localizedDescription)
            return nil
        }
    }
    
    func removeKey(_ key: String) -> Bool {
        guard let keyURL = self.URLforKey(key) else {
            return false
        }
        do{
            try FileManager.default.removeItem(at:keyURL )
            return true
            
        }catch let error as NSError {
            print(error.localizedDescription)
            return false
        }

    }
    func resetAll() -> Bool {
        guard let folderURL = self.folderPathURL  else {
            return false
        }
        do{
            try FileManager.default.removeItem(at:folderURL )
            self.createDirectoryAtURLIfNeeded(folderURL)
            return true
            
        }catch let error as NSError {
            print(error.localizedDescription)
            return false
        }

    }
}
