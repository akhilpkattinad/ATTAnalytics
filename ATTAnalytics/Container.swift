//
//  Container.swift
//  Sample
//
//  Created by Sreekanth R on 27/10/16.
//  Copyright © 2016 Sreekanth R. All rights reserved.
//

import Foundation

class Container: NSObject {
    typealias completionHandler = (_ response:ContainerResponse?) -> Void
    
    // MARK: Private variables
    var baseURL      = "http://13.126.181.33:8086"
    var debugBaseURL = "http://13.126.181.33:8086"
    
    var completion:completionHandler?
    private var operationQueue:OperationQueue?
    private var timeStamp: String {
        return "\(Date().millisecondsSince1970)"
    }
    
    enum RequestMethod {
        case Get
        case Post
    }
    
    // MARK: Constructors
    override init() {
        super.init()
    }
    
    convenience init(maxConcurrentOperations:Int?, queueName:String?) {
        self.init()
        
        self.operationQueue = OperationQueue()
        self.operationQueue?.name = queueName
        self.operationQueue?.maxConcurrentOperationCount = maxConcurrentOperations!
    }
    
    // MARK: Shared object
    class var container: Container {
        struct Static {
            static let instance = Container(maxConcurrentOperations: 10000,
                                            queueName: "ContainerOperationsQueue")
        }
        return Static.instance
    }
    
    // MARK: Public methods
    // MARK: For HTTP METHOD GET
    @discardableResult func get(containerRequest:ContainerRequest?, onCompletion:completionHandler?) -> String? {
        guard let containerRequest = containerRequest,let urlRequest = self.formulateRequestFromContainerRequest(containerRequest: containerRequest) else{
            return nil
        }
        
        urlRequest.httpMethod = self.stringConvertedRequestMethod(method:.Get)
        
        self.completion = onCompletion
        let operationID = self.timeStamp
        let operation = ContainerOperation(request: urlRequest,
                                           operationID: operationID,
                                           priority: containerRequest.priority,
                                           cachePolicy: containerRequest.cachingPolicy,
                                           delegate: self)
        
        self.operationQueue?.addOperation(operation)
        return operationID
    }
    
    // MARK: For HTTP METHOD POST
    @discardableResult func post(containerRequest:ContainerRequest?, onCompletion:completionHandler?) -> String? {
        
        guard let containerRequest = containerRequest,
            let urlRequest = self.formulateRequestFromContainerRequest(containerRequest: containerRequest),
            let requestParams = containerRequest.requestParams,
            let data = fetchJSONSerializedData(requestParams) else{
            return nil
        }
        
        urlRequest.httpMethod = self.stringConvertedRequestMethod(method:.Post)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data
        
        if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String?{
            print(" Syncable Data: \(jsonString)")
        }
        self.completion = onCompletion
        let operationID = self.timeStamp
        let operation = ContainerOperation(request: urlRequest,
                                           operationID: operationID,
                                           priority: containerRequest.priority,
                                           cachePolicy: containerRequest.cachingPolicy,
                                           delegate: self)
        
        self.operationQueue?.addOperation(operation)
        return operationID
    }
    
    func fetchJSONSerializedData(_ dataToConvert: Any) -> Data? {
        do {
            let data = try JSONSerialization.data(withJSONObject:dataToConvert, options: [])
            return data
        } catch  {
            return nil
        }
    }
    
    // MARK: Lifecycles for Cancel, Suspend and Resume
    func cancelOperation(operationID:String?) -> Void {
        if let theOperation = self.findOperationWithID(operationID: operationID) {
            theOperation.cancelOperation()
        }
    }
    
    func suspendOperation(operationID:String?) -> Void {
        if let theOperation = self.findOperationWithID(operationID: operationID) {
            theOperation.suspendOperation()
        }
    }
    
    func resumeOperation(operationID:String?) -> Void {
        if let theOperation = self.findOperationWithID(operationID: operationID) {
            theOperation.resumeOperation()
        }
    }
    
    // MARK: Private methods
    private func stringConvertedRequestMethod(method:RequestMethod?) -> String {
        if method == .Get {return "GET"}
        if method == .Post {return "POST"}
        return "GET"
    }
    
    private func findOperationWithID(operationID:String?) -> ContainerOperation? {
        guard let operationID = operationID,let allOperations = self.operationQueue?.operations  else {
            return nil
        }
        
        let filteredArray = allOperations.filter { _ in operationID == operationID }
        if filteredArray.count > 0 {
            return filteredArray.first as? ContainerOperation
        }
        
        return nil
    }
    
    private func formulateRequestFromContainerRequest(containerRequest:ContainerRequest?) -> NSMutableURLRequest? {
        
        var theRequestURLString: String!
        if let newServerURL = ATTAnalytics.helper.analyticsConfiguration.serverURL {
            theRequestURLString = newServerURL
        }else{
            theRequestURLString = ATTAnalytics.helper.analyticsConfiguration.isDebugFrameWork ? debugBaseURL : baseURL
        }

        if let requestURL = containerRequest?.requestURL {
            theRequestURLString = theRequestURLString.appending(requestURL)
        }
        if let theRequestURL = URL(string: theRequestURLString){
            let urlRequest = NSMutableURLRequest(url: theRequestURL)
            return urlRequest
        }
        return nil
      
    }
}

// MARK: ContainerOperationDelegate
extension Container : ContainerOperationDelegate {
    func completedOperationWithResponse(response:ContainerResponse?, operationID:String?) {
        DispatchQueue.main.async {
            if let completionBlock = self.completion {
                completionBlock(response)
            }
        }
    }
}
