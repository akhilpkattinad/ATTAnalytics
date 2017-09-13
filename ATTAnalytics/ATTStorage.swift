//
//  ATTStorage.swift
//  TrackingHelper
//
//  Created by Adarsh GJ on 11/08/17.
//  Copyright © 2017 Adarsh GJ. All rights reserved.
//

import Foundation

protocol ATTStorage {
   
    /// Remove content from storage
    ///
    /// - Parameter key: key
    /// - Returns: Sucess status
    func removeKey(_ key: String) -> Bool
    
    
    /// Remove all store content
    ///
    /// - Returns: status
    func resetAll() -> Bool
    
 
    ///  Data store in to local file system
    ///
    /// - Parameters:
    ///   - data: data
    ///   - key: key
    /// - Returns: Sucess status
    func setData(_ data: Data,forKey key: String) -> Bool
    
    
  
    /// fetch store data
    ///
    /// - Parameter key: key
    /// - Returns: stored data
    func dataForKey(_ key: String) -> Data?
    
    

    /// Dictionary store in to local file system
    ///
    /// - Parameters:
    ///   - dictionary: dictionary
    ///   - key: key
    /// - Returns: Sucess status
    func setDictionary(_ dictionary: [AnyHashable:Any],forKey key: String) -> Bool

    
  
    /// Fetch stored Dictionary
    ///
    /// - Parameter key: key value
    /// - Returns: Dictionary
    func dictionaryForKey(_ key: String) -> [AnyHashable:Any]?
    
    
    
    /// Array store in to local file system
    ///
    /// - Parameters:
    ///   - array: array value to store
    ///   - key: key
    /// - Returns: Sucess status
    func setArray(_ array: [[AnyHashable:Any]],forKey key: String) -> Bool
    
  
    ///  Fetch stored Array content
    ///
    /// - Parameter key: key
    /// - Returns: Arry dictionary
    func arrayForKey(_ key: String) -> [[AnyHashable:Any]]?

  
    /// String store in to local file system
    ///
    /// - Parameters:
    ///   - string: String value to store
    ///   - key: key
    /// - Returns: Sucess status
    func setString(_ string: String,forKey key: String) -> Bool

   
    /// Fetch stored string value
    ///
    /// - Parameter key: key
    /// - Returns: stored string
    func stringForKey(_ key: String) -> String?

}
