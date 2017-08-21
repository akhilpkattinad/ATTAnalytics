//
//  ContainerOperation.swift
//  Sample
//
//  Created by Sreekanth R on 01/11/16.
//  Copyright © 2016 Sreekanth R. All rights reserved.
//

import Foundation

protocol ContainerOperationDelegate{
    func completedOperationWithResponse(response:ContainerResponse?, operationID:String?)
}

class ContainerOperation:Operation {
    typealias completionHandler = (_ response:ContainerResponse?) -> Void
    
    // MARK: Private properties
    var sessionDataTask:URLSessionDataTask?
    var operationID:String?
    var delegate:ContainerOperationDelegate?
    var cachingPolicy:ContainerRequest.CachingTypes?
    
    // MARK: Constructors
    override init() {
        super.init()
    }
    
    convenience init(request:NSMutableURLRequest?,
                     operationID:String?,
                     priority:ContainerRequest.RequestPriority?,
                     cachePolicy:ContainerRequest.CachingTypes?,
                     delegate:ContainerOperationDelegate) {
        self.init()
        
        self.operationID = operationID
        self.delegate = delegate
        self.cachingPolicy = cachePolicy
        
        if self.cachingPolicy == nil {
            self.cachingPolicy = .NoCaching
        }
        
        if priority == nil {
            self.queuePriority = .normal
        } else {
            if priority == .VeryLow {
                self.queuePriority = .veryLow
            }
            if priority == .Low {
                self.queuePriority = .low
            }
            if priority == .Normal {
                self.queuePriority = .normal
            }
            if priority == .High {
                self.queuePriority = .high
            }
            if priority == .VeryHigh {
                self.queuePriority = .veryHigh
            }
        }
        
        self.dataTask(request: request!, onCompletion: {(response:ContainerResponse?) -> Void in
            self.delegate?.completedOperationWithResponse(response: response, operationID: self.operationID)
        })
    }
    
    // MARK: Session life cycle
    func suspendOperation() -> Void {
        self.sessionDataTask?.suspend()
    }
    
    func resumeOperation() -> Void {
        self.sessionDataTask?.resume()
    }
    
    func cancelOperation() -> Void {
        self.sessionDataTask?.cancel()
    }
    
    // MARK: Private methods
    // MARK: End point of call
    private func dataTask(request: NSMutableURLRequest, onCompletion:completionHandler?) -> Void {
        let configuration:URLSessionConfiguration = URLSessionConfiguration.default
        var hasCachedData = false
        
        if self.cachingPolicy == .DefaultCaching {
            configuration.requestCachePolicy = NSURLRequest.CachePolicy.returnCacheDataElseLoad
        }
        
        if self.cachingPolicy == .NoCaching {
            configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        }
        
        if self.cachingPolicy == .InMemoryCaching {
            configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
            
            if let urlPathString = request.url?.absoluteString ,let data = self.cachedData(dataSourcePath: urlPathString) {
                let responseDictionary = self.dictionaryFromData(responseData: data as Data) as? [String: AnyObject]
                let response = ContainerResponse(parsedResponse: responseDictionary,
                                                 error: nil,
                                                 response: nil)
                
                hasCachedData = true
                if let onCompletion = onCompletion{
                    onCompletion(response)
                    
                }
            }
        }
        
        let session = URLSession(configuration: configuration)
        self.sessionDataTask = session.dataTask(with: request as URLRequest) {(responseData, httpResponse, error) -> Void in
            if let responseData = responseData {
                if self.cachingPolicy == .InMemoryCaching {
                    self.cacheData(data: responseData as NSData?, dataSourcePath: request.url?.absoluteString)
                }
                
                //                let jsonString = NSString(data: responseData, encoding: String.Encoding.utf8.rawValue)! as String
                //                print(" Synced Data: \(jsonString)")
                
                let responseDictionary = self.dictionaryFromData(responseData: responseData ) as? [String:AnyObject]
                
                let response = ContainerResponse(parsedResponse: responseDictionary,
                                                 error: error as Error?,
                                                 response: httpResponse)
                
                if self.cachingPolicy != .InMemoryCaching {
                    onCompletion!(response)
                }
                else {
                    if hasCachedData == false {
                        onCompletion!(response)
                    }
                }
            } else {
                let response = ContainerResponse(parsedResponse: nil,
                                                 error: error as Error?,
                                                 response: httpResponse)
                onCompletion!(response)
            }
        }
        
        self.resumeOperation()
    }
    
    private func dictionaryFromData(responseData:Data) -> NSDictionary? {
        let parsedDictionary = try? JSONSerialization.jsonObject(with: responseData, options: [])
        var responseDictionary: [String:AnyObject]?
        if let dictionary = parsedDictionary as? [AnyObject] {
            responseDictionary = ["root": dictionary as AnyObject]
        } else {
            responseDictionary = parsedDictionary as? [String:AnyObject]
        }
        
        return responseDictionary as NSDictionary?
    }
    
    // MARK: In Memory caching methods
    // Caching the data
    private func cacheData(data:NSData?, dataSourcePath:String?) -> Void {
        
        if let data = data,let documentPath = self.documentDirectoryPath(dataSourcePath: dataSourcePath) {
            _ = try? data.write(toFile: documentPath, options: [])
        }
    }
    
    // Fetching the cached data
    private func cachedData(dataSourcePath:String?) -> NSData? {
        
        if let documentPath = self.documentDirectoryPath(dataSourcePath: dataSourcePath),let data = NSData(contentsOfFile: documentPath) {
            return data
        }
        
        return nil
    }
    
    private func documentDirectoryPath(dataSourcePath:String?) -> String? {
        let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let filename = dataSourcePath?.components(separatedBy: "/").last
        let writePath = documentPath.appending(filename!)
        
        return writePath
    }
}
