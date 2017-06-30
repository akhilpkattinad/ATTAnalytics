//
//  ATTFlushManager.swift
//  TrackingHelper
//
//  Created by Sreekanth R on 20/01/17.
//  Copyright © 2017 Sreekanth R. All rights reserved.
//

import UIKit

protocol ATTFlushManagerDelegate{
    func flushData() -> Array<AnyObject>?
    func removedSyncedObjects(screenIDArray:Array<String>?) -> Void
}

class ATTFlushManager: NSObject {
    var delegate:ATTFlushManagerDelegate?
    var encodedSessionString:String?
    var sessionSyncCompleted:Bool?
    var handShakeCompleted:Bool?
    var identificationRequired:Bool?
    var identificationStatusUpdated:Bool?
    
    // MARK: - deinit
    deinit {
        self.delegate = nil
    }
    
    // MARK: - inits
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ATTFlushManager.identificationStatusChanged),
                                               name: NSNotification.Name(rawValue: ATTAnalytics.IdentifyNotification),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ATTFlushManager.userLoggedOut),
                                               name: NSNotification.Name(rawValue: ATTAnalytics.LoggoutNotification),
                                               object: nil)
        
    }
    
    convenience init(flushInterval:Double?, delegate:ATTFlushManagerDelegate?) {
        self.init()
        self.delegate = delegate
        Timer.scheduledTimer(timeInterval:flushInterval!,
                             target:self,
                             selector:#selector(ATTFlushManager.flushDataInInterval),
                             userInfo:nil,
                             repeats:true)
    }
    
    // MARK: - Identification
    func resetIdentification() -> Void {
        self.identificationRequired = true
    }
    
    // MARK: - Session management
    func createSession() -> Void {
        self.handShakeCompleted = false
        let deviceId = UIDevice.current.identifierForVendor!.uuidString.replacingOccurrences(of: "-", with: "") as String
        let timeStamp = "\(ATTMiddlewareSchemaManager.manager.timeStamp()!)"
        let appID = ATTAnalytics.helper.appID!
        let sessionID = "\(deviceId)-\(appID)-\(timeStamp)"
        self.encodedSessionString = self.base64Encoded(string: sessionID)!
        self.syncNewSession()
    }
    
    func base64Encoded(string:String?) -> String? {
        if let data = string?.data(using: .utf8) {
            return data.base64EncodedString()
        }
        
        return nil
    }
    
    // MARK: Loggin and loggout
    func identificationStatusChanged() -> Void {
        self.identificationStatusUpdated = true
        UserDefaults.standard.setValue("host", forKey: "ATTUserLoginType")
    }
    
    func userLoggedOut() -> Void {
        self.identificationStatusUpdated = true
        UserDefaults.standard.setValue("guest", forKey: "ATTUserLoginType")
    }
    
    // MARK: - Handshake
    func syncNewSession() -> Void {
        self.sessionSyncCompleted = false
        self.flushDataInInterval()
    }
    
    // MARK: - End point of Syncing
    // API calls and response handling
    func flushDataInInterval() -> Void {
        let flushableData = self.delegate?.flushData() as Array<AnyObject>?
        if flushableData != nil {
            let schema = self.formattedSchemaFromArray(eventsArray: flushableData)
            if schema != nil {
                // API endpoit
                let requestPath = "save"
                let request = ContainerRequest(requestURL:requestPath,
                                               requestParams:schema as Dictionary<String, AnyObject>?,
                                               requestPriority: .Normal)
                Container.container.post(containerRequest: request, onCompletion: { (response) in
                    let responseDict = response?.responseDictionary
                    if responseDict != nil {
                        let syncedKeysArray = responseDict?["events"] as? Array<AnyObject>
                        let identificationObject = responseDict?["identification"] as? Dictionary<String, AnyObject>
                        let identificationStatus = identificationObject?["identificationStatus"] as? Bool
                        let sessionObject = responseDict?["session"] as? Dictionary<String, AnyObject>
                        let sessionStatus = sessionObject?["sessionCreationStatus"] as? Bool
                        var screenViewIDArray = Array<String>()
                        
                        for eachKeyDict in syncedKeysArray! {
                            screenViewIDArray.append(eachKeyDict["eventId"] as! String)
                        }
                        
                        self.delegate?.removedSyncedObjects(screenIDArray: screenViewIDArray)
                        
                        if identificationStatus == true {
                            self.identificationRequired = false
                            self.identificationStatusUpdated = false
                        }
                        
                        if sessionStatus == true {
                            self.handShakeCompleted = true
                        }
                        
                        self.sessionSyncCompleted = true
                    }
                })
            }
        }
    }
    
    // MARK: - Formatting the schema
    func formattedSchemaFromArray(eventsArray:Array<AnyObject>?) -> Dictionary<String, AnyObject>? {
        if self.sessionSyncCompleted == false {
            return self.syncableSessionObject() as Dictionary<String, AnyObject>?
        }
        
        var screenViews = Array<AnyObject>()
        var screenEvents = Array<AnyObject>()
        if (eventsArray?.count)! > 0 {
            for screenViewIndex in 0...(eventsArray?.count)! - 1 {
                let eachScreen:ATTScreenViewModel = eventsArray![screenViewIndex] as! ATTScreenViewModel
                let sID = (eachScreen.screenViewID != nil) ? eachScreen.screenViewID : ""
                
                let sName = (eachScreen.screenName != nil) ? eachScreen.screenName : ""
                let sTitle = (eachScreen.screenTitle != nil) ? eachScreen.screenTitle : ""
                let sPName = (eachScreen.previousScreenName != nil) ? eachScreen.previousScreenName : ""
                let sPTitle = (eachScreen.previousScreenTitle != nil) ? eachScreen.previousScreenTitle : ""
                
                var dataDictionary = [String: AnyObject]()
                var sourceName = sName
                if sTitle != nil && sTitle != "" {
                    sourceName = sTitle
                }
                
                var previousScreen = sPName
                if sPTitle != nil && sPTitle != "" {
                    previousScreen = sPTitle
                }
                
                if eachScreen.screenEventsArray != nil && (eachScreen.screenEventsArray?.count)! > 0 {
                    for eventsIndex in 0...(eachScreen.screenEventsArray?.count)! - 1 {
                        let eachEvent:ATTEventModel = eachScreen.screenEventsArray?[eventsIndex] as! ATTEventModel
                        
                        let eType = (eachEvent.eventType != nil) ? eachEvent.eventType : ""
                        let eName = (eachEvent.eventName != nil) ? eachEvent.eventName : ""
                        //let dURL = (eachEvent.dataURL != nil) ? eachEvent.dataURL : ""
                        let eStrtTim = (eachEvent.eventStartTime != nil) ? eachEvent.eventStartTime : Date()
                        let eStrtTimFormated = (eStrtTim?.timeIntervalSince1970)! * 1000
                        let eDur = (eachEvent.eventDuration != nil) ? eachEvent.eventDuration : 0
                        let lat = (eachEvent.latitude != nil) ? eachEvent.latitude : 0
                        let log = (eachEvent.longitude != nil) ? eachEvent.longitude : 0
                        let location = ["latitude":"\(lat!)", "longitude":"\(log!)"]
                        let customParam = (eachEvent.arguments != nil) ? eachEvent.arguments : Dictionary<String, AnyObject>()
                        
                        var dataDictionary = [String: AnyObject]()
                        
                        dataDictionary["eventDuration"] = ("\(eDur!)" as AnyObject?)!
                        dataDictionary["location"] = location as AnyObject
                        dataDictionary["device"] = self.deviceInfo() as AnyObject
                        dataDictionary["network"] = self.networkInfo() as AnyObject
                        dataDictionary["sourceName"] = (sourceName as AnyObject?)!
                        dataDictionary["previousScreen"] = (previousScreen as AnyObject?)!
                        
                        for key in (customParam?.keys)! {
                            dataDictionary[key] = customParam?[key]
                        }
                        
                        let eventDictionary = ["sessionId":self.encodedSessionString as AnyObject,
                                               "eventType":(eType as AnyObject?)!,
                                               "userId":currentUserID()! as AnyObject,
                                               "event":(eName as AnyObject?)!,
                                               "eventId":(sID as AnyObject?)!,
                                               "timestamp":("\(eStrtTimFormated)" as AnyObject?)!,
                                               "data":dataDictionary as AnyObject] as [String : AnyObject]
                        
                        screenEvents.append(eventDictionary as AnyObject)
                    }
                }
                
                //let sID = (eachScreen.screenViewID != nil) ? eachScreen.screenViewID : ""
                
                let sBTime = (eachScreen.screenViewBeginTime != nil) ? eachScreen.screenViewBeginTime : Date()
                let sBTimeFormted = (sBTime?.timeIntervalSince1970)! * 1000
                let sVDur = (eachScreen.screeViewDuration != nil) ? eachScreen.screeViewDuration : 0
                let lat = (eachScreen.latitude != nil) ? eachScreen.latitude : 0
                let log = (eachScreen.longitude != nil) ? eachScreen.longitude : 0
                let location = ["latitude":"\(lat!)", "longitude":"\(log!)"]
                
                dataDictionary["sourceName"] = (sourceName as AnyObject?)!
                dataDictionary["previousScreen"] = (previousScreen as AnyObject?)!
                dataDictionary["timeSpent"] = ("\(sVDur!)" as AnyObject?)!
                dataDictionary["location"] = location as AnyObject
                dataDictionary["device"] = self.deviceInfo() as AnyObject
                dataDictionary["network"] = self.networkInfo() as AnyObject
                
                let screenViewDictionary:Dictionary<String, AnyObject> = ["sessionId":self.encodedSessionString as AnyObject,
                                                                          "eventId":(sID as AnyObject?)!,
                                                                          "userId":currentUserID()! as AnyObject,
                                                                          "eventType":"ScreenView" as AnyObject,
                                                                          "event":"ScreenView" as AnyObject,
                                                                          "timestamp":("\(sBTimeFormted)" as AnyObject?)!,
                                                                          "data":dataDictionary as AnyObject]
                
                screenViews.append(screenViewDictionary as AnyObject)
            }
            
            var eventsArray = Array<AnyObject>()
            if self.identificationStatusUpdated == true {
                eventsArray.append(self.identificationObject() as AnyObject)
            }
            
            eventsArray = (eventsArray + screenViews + screenEvents) as Array<AnyObject>
            let data = ["appId": ATTAnalytics.helper.appID! as AnyObject,
                        "events":eventsArray as AnyObject] as [String : AnyObject]
            
            return data as Dictionary<String, AnyObject>?
        }
       
        return nil
    }
    
    func syncableSessionObject() -> Dictionary<String, AnyObject>? {
        var eventsArray = Array<AnyObject>()
        if self.handShakeCompleted == false {
            eventsArray.append(self.sessionInfo() as AnyObject)
        }
        
        if self.identificationRequired == true {
            eventsArray.append(self.identificationObject() as AnyObject)
        }
        
        let data = ["appId": ATTAnalytics.helper.appID! as AnyObject,
                    "events":eventsArray as AnyObject] as [String : AnyObject]
        
        return data as Dictionary<String, AnyObject>?
    }
    
    private func identificationObject() -> Dictionary<String, AnyObject>? {
        var identificationDictionary = [String: AnyObject]()
        
        identificationDictionary["eventType"] = "Identify" as AnyObject?
        identificationDictionary["event"] = "Identify" as AnyObject?
        identificationDictionary["sessionId"] = self.encodedSessionString as AnyObject
        identificationDictionary["timestamp"] = "\(ATTMiddlewareSchemaManager.manager.timeStamp()!)" as AnyObject
        identificationDictionary["userId"] = self.currentUserID() as AnyObject
        
        var dataDictionary = [String: AnyObject]()        
        
        var userProfile = UserDefaults.standard.object(forKey: "ATTUserProfile") as? Dictionary<String, AnyObject>
        let userType = UserDefaults.standard.object(forKey: "ATTUserLoginType") as? String
        
        if userProfile == nil {
            userProfile = [String: AnyObject]()
        }
        
        userProfile?["userStatus"] = "0" as AnyObject?
        
        if userType != nil && userType == "host" {
            userProfile?["userStatus"] = "1" as AnyObject?
        }
        
        if userProfile != nil {
            dataDictionary["user"] = userProfile as AnyObject?
        }
        
        dataDictionary["device"] = self.deviceInfo() as AnyObject
        dataDictionary["network"] = self.networkInfo() as AnyObject
        dataDictionary["app"] = self.appInfo() as AnyObject
        dataDictionary["lib"] = self.libInfo() as AnyObject
        
        identificationDictionary["data"] = dataDictionary as AnyObject
        
        return identificationDictionary
    }
    
    private func appInfo() -> Dictionary<String, AnyObject>? {
        let dictionary = Bundle.main.infoDictionary
        let version = dictionary?["CFBundleShortVersionString"] as? String
        let appName = dictionary?["CFBundleName"] as? String
        let bundleID = Bundle.main.bundleIdentifier
        
        var appInfoDictionary = [String: AnyObject]()
        
        appInfoDictionary["version"] = version as AnyObject?
        appInfoDictionary["nameSpace"] = bundleID as AnyObject?
        appInfoDictionary["name"] = appName as AnyObject?
        appInfoDictionary["language"] = "" as AnyObject?
        appInfoDictionary["build"] = "" as AnyObject?
        
        return appInfoDictionary
    }
    
    private func sessionInfo() -> Dictionary<String, AnyObject>? {
        var sessionInfoDictionary = [String: AnyObject]()
        
        sessionInfoDictionary["sessionId"] = self.encodedSessionString as AnyObject?
        sessionInfoDictionary["userId"] = self.currentUserID() as AnyObject?
        sessionInfoDictionary["event"] = "SessionStart" as AnyObject?
        sessionInfoDictionary["eventType"] = "SessionStart" as AnyObject?
        sessionInfoDictionary["timestamp"] = "\(ATTMiddlewareSchemaManager.manager.timeStamp()!)" as AnyObject?
        
        return sessionInfoDictionary
    }
    
    private func libInfo() -> Dictionary<String, String>? {
        return ["libVersion":"0.0.1"]
    }
    
    private func deviceInfo() -> Dictionary<String, AnyObject>? {
        var appInfoDictionary = [String: AnyObject]()
        
        appInfoDictionary["deviceId"] = UIDevice.current.identifierForVendor!.uuidString as AnyObject?
        appInfoDictionary["os"] = "iOS" as AnyObject?
        appInfoDictionary["type"] = UIDevice.current.modelType as AnyObject?
        appInfoDictionary["version"] = UIDevice.current.systemVersion as AnyObject?
        appInfoDictionary["manufacture"] = "Apple" as AnyObject?
        appInfoDictionary["model"] = UIDevice.current.model as AnyObject?
        appInfoDictionary["name"] = UIDevice.current.name as AnyObject?
        appInfoDictionary["locale"] = NSLocale.current.languageCode as AnyObject?
        appInfoDictionary["resolution"] = "\(UIScreen.main.bounds.size.width) x \(UIScreen.main.bounds.size.height)" as AnyObject?
        
        return appInfoDictionary
    }
    
    private func networkInfo() -> Dictionary<String, AnyObject>? {
        var networkInfoDictionary = [String: AnyObject]()
        
        if ATTReachability.reachability.currentReachabilityStatus == .reachableViaWiFi {
            networkInfoDictionary["type"] = "Wifi" as AnyObject?
        } else {
            networkInfoDictionary["type"] = "Cellular" as AnyObject?
            if let carrierName = ATTReachability.reachability.carrierName() {
                networkInfoDictionary["carrier"] = carrierName as AnyObject?

            }
        }
        
        networkInfoDictionary["connectionSpeed"] = "" as AnyObject?
        
        return networkInfoDictionary
    }
    
    private func currentUserID() -> String? {
        var userID = UserDefaults.standard.object(forKey: "ATTUserID") as? String
        
        if userID == nil || userID == "" {
            userID = "\(ATTMiddlewareSchemaManager.manager.newUniqueID()!)" as String?
            userID = self.base64Encoded(string: userID)
            UserDefaults.standard.setValue(userID, forKey: "ATTUserID")
            UserDefaults.standard.setValue("guest", forKey: "ATTUserLoginType")
        }
        
        return userID
    }
}

public extension UIDevice {
    var modelType: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
            case "iPod5,1", "iPod7,1","iPhone3,1", "iPhone3,2", "iPhone3,3", "iPhone4,1", "iPhone5,1", "iPhone5,2", "iPhone5,3", "iPhone6,1", "iPhone6,2", "iPhone7,2", "iPhone7,1", "iPhone8,1", "iPhone8,2","iPhone9,1", "iPhone9,3", "iPhone9,2", "iPhone9,4", "iPhone8,4":
                
                return "mobile"
                
            case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4","iPad3,1", "iPad3,2", "iPad3,3", "iPad3,4", "iPad3,5", "iPad3,6", "iPad4,1", "iPad4,2", "iPad4,3", "iPad5,3", "iPad5,4", "iPad2,5", "iPad2,6", "iPad2,7","iPad4,4", "iPad4,5", "iPad4,6", "iPad4,7", "iPad4,8", "iPad4,9", "iPad5,1", "iPad5,2", "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8":return "tablet"
            case "AppleTV5,3":                              return "tv"
            case "i386", "x86_64":                          return "simulator"
            default:                                        return identifier
        }
    }
}
