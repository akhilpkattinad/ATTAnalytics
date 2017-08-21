//
//  ATTFlushManager.swift
//  TrackingHelper
//
//  Created by Sreekanth R on 20/01/17.
//  Copyright © 2017 Sreekanth R. All rights reserved.
//

import UIKit

protocol ATTFlushManagerDelegate{
    func flushData() -> [Any]
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
        
        /*
         let deviceId = UIDevice.current.identifierForVendor!.uuidString.replacingOccurrences(of: "-", with: "") as String
         let timeStamp = "\(ATTMiddlewareSchemaManager.manager.timeStamp())"
         let appID = ATTAnalytics.helper.appID ?? ""
         let sessionID = "\(deviceId)-\(appID)-\(timeStamp)"
         */
        let timeStamp = "\(ATTMiddlewareSchemaManager.manager.timeStamp())"
        
        let sessionID = "\(currentUserID())-\(timeStamp)" //userid +time
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
        createSession()
    }
    
    func userLoggedOut() -> Void {
        self.identificationStatusUpdated = true
        UserDefaults.standard.setValue("guest", forKey: "ATTUserLoginType")
        createSession()
    }
    
    // MARK: - Handshake
    func syncNewSession() -> Void {
        self.sessionSyncCompleted = false
        self.flushDataInInterval()
    }
    
    // MARK: - End point of Syncing
    // API calls and response handling
    
    func flushDataInInterval() -> Void {
        guard let flushableData = self.delegate?.flushData() as? [ATTScreenViewModel],let schema = self.formattedSchemaFromArray(flushableData)   else {
            return
        }
        // API endpoit
        let requestPath = "save"
        let request = ContainerRequest(requestURL:requestPath,
                                       requestParams:schema,
                                       requestPriority: .Normal)
        
        
        Container.container.post(containerRequest: request, onCompletion: { (response) in
            if  let responseDict = response?.responseDictionary {
                if let syncedKeysArray = responseDict["events"] as? [AnyObject] {
                    var screenViewIDArray: [String] = []
                    for eachKeyDict in syncedKeysArray {
                        if let eventIDString = eachKeyDict["eventId"] as? String {
                            screenViewIDArray.append(eventIDString)
                        }
                    }
                    screenViewIDArray.count > 0 ? self.delegate?.removedSyncedObjects(screenIDArray: screenViewIDArray) : nil
                }
                
                if let identificationObject = responseDict["identification"] as? [String:AnyObject],let identificationStatus = identificationObject["identificationStatus"] as? Bool,identificationStatus == true {
                    self.identificationRequired = false
                    self.identificationStatusUpdated = false
                }
                
                if let sessionObject = responseDict["session"] as? [String:AnyObject], let sessionStatus = sessionObject["sessionCreationStatus"] as? Bool, sessionStatus == true {
                    self.handShakeCompleted = true
                }
                self.sessionSyncCompleted = true
            }
        })
        
        
    }
    
    // MARK: - Formatting the schema
    
    func fetchEventDictionaryArrayFromScreenViewModel(_ screenViewModel: ATTScreenViewModel) -> [[String : Any]]? {
        
        guard let screenEventsArray = screenViewModel.screenEventsArray as? [ATTEventModel],screenEventsArray.count > 0   else {
            return nil
        }
        
        var eventDictionaryArray: [[String : Any]] = []
        for eachEvent in screenEventsArray {
            let eachEventDictionary = createEventSchema(eachEvent)
            
            eventDictionaryArray.append(eachEventDictionary)
        }
        return eventDictionaryArray
    }
    func createScreenSchema(_ eachScreen: ATTScreenViewModel ) -> [String : Any] {
        
        let screenViewBeginTime         = eachScreen.screenViewBeginTime ?? Date()
        let screenViewBeginTimeFormted  = screenViewBeginTime.millisecondsSince1970
        let screeViewDuration           = eachScreen.screeViewDuration ?? 0
        let latitude                    = eachScreen.latitude ?? 0
        let longitude                   = eachScreen.longitude ?? 0
        let location                    = ["latitude":"\(latitude)", "longitude":"\(longitude)"]
        
        
        let screenViewDictionary: [String: Any] = ["sessionId":self.encodedSessionString ?? "",
                                                   "service":ATTAnalytics.helper.analyticsConfiguration.appID ?? "",
                                                   "eventId":eachScreen.screenViewID ?? "",
                                                   "userId":currentUserID(),
                                                   "eventType":"ScreenView",
                                                   "event":"ScreenView",
                                                   "timestamp":"\(screenViewBeginTimeFormted)",
                                                   "timeSpent":"\(screeViewDuration)",
                                                   "location":location,
                                                   "device":self.deviceInfo(),
                                                   "os":self.deviceOSInfo(),
                                                   "network":self.networkInfo(),
                                                   "app":self.appInfo(),
                                                   "lib":self.libInfo()]
        
        return screenViewDictionary
    }
    
    
    func createEventSchema(_ eachEvent: ATTEventModel) -> [String : Any] {
        
        //let dURL = (eachEvent.dataURL != nil) ? eachEvent.dataURL : ""
        let eventStartTime = eachEvent.eventStartTime ?? Date()
        let eventStartTimeFormated = eventStartTime.millisecondsSince1970
        let location = ["latitude":"\(eachEvent.latitude ?? 0)", "longitude":"\(eachEvent.longitude ?? 0)"]
        var eventDataDictionary: [String: Any] = [:]
        if let customParam = eachEvent.arguments{
            for key in customParam.keys {
                eventDataDictionary[key] = customParam[key]
            }
        }
        
        let eventDictionary: [String:Any] = ["sessionId":self.encodedSessionString ?? "",
                                             "service":ATTAnalytics.helper.analyticsConfiguration.appID ?? "",
                                             "eventType":eachEvent.eventType ?? "" ,
                                             "userId":currentUserID(),
                                             "event":eachEvent.eventName ?? "" ,
                                             "eventId":eachEvent.screenViewID ?? "" ,
                                             "timestamp":"\(eventStartTimeFormated)",
                                             "eventDuration":"\(eachEvent.eventDuration ?? 0)",
                                             "data":eventDataDictionary,
                                             "location":location,
                                             "device":self.deviceInfo(),
                                             "os":self.deviceOSInfo(),
                                             "network":self.networkInfo(),
                                             "app":self.appInfo(),
                                             "lib":self.libInfo()]
        
        return eventDictionary
        
    }
    func fetchSourceName(_ screenViewModel: ATTScreenViewModel) -> String{
        let screenName  = screenViewModel.screenName ?? ""
        let screenTitle = screenViewModel.screenTitle ??  ""
        
        var sourceName = screenName
        if  screenTitle != "" {
            sourceName = screenTitle
        }
        return sourceName
    }
    func fetchPreviousScreen(_ screenViewModel: ATTScreenViewModel) -> String{
        let previousScreenName = screenViewModel.previousScreenName ??  ""
        let previousScreenTitle = screenViewModel.previousScreenTitle ?? ""
        
        var previousScreen = previousScreenName
        if previousScreenTitle != "" {
            previousScreen = previousScreenTitle
        }
        return previousScreen
    }
    
    func formattedSchemaFromArray(_ screenViewModelArray:[ATTScreenViewModel]) -> [String : Any]? {
        if self.sessionSyncCompleted == false {
            return self.syncableSessionObject()
        }
        let eventCount =  screenViewModelArray.count
        if eventCount <= 0 {
            return nil
        }
        
        var screenViews: [Any]  = []
        var screenEvents: [Any] = []
        
        for eachScreen in screenViewModelArray {
            if let eventDictionaryArray = fetchEventDictionaryArrayFromScreenViewModel(eachScreen){
                screenEvents = screenEvents + eventDictionaryArray
            }
            // check is need to pass the screen view event with request
            if eachScreen.isNeedToPassScreenViewEvent {
                let screenViewDictionary  = self.createScreenSchema(eachScreen)
                screenViews.append(screenViewDictionary)
            }
        }
        
        var eventsArray: [Any] = []
        if self.identificationStatusUpdated == true {
            eventsArray.append(self.identificationObject())
        }
        eventsArray = (eventsArray + screenViews + screenEvents)
        let data = ["events":eventsArray] as [String : Any]
        return data
    }
    
    func syncableSessionObject() -> [String:Any] {
        var eventsArray: [Any] = []
        if self.handShakeCompleted == false {
            eventsArray.append(self.sessionInfo())
        }
        if self.identificationRequired == true {
            eventsArray.append(self.identificationObject())
        }
        let data = ["events":eventsArray] as [String : Any]
        return data
    }
    
    private func identificationObject() -> [String:Any] {
        var identificationDictionary: [String: Any] = [:]
        
        identificationDictionary["eventType"]   = "Identify"
        identificationDictionary["event"]       = "Identify"
        identificationDictionary["sessionId"]   = self.encodedSessionString
        identificationDictionary["timestamp"]   = "\(ATTMiddlewareSchemaManager.manager.timeStamp())"
        identificationDictionary["userId"]      = self.currentUserID()
        identificationDictionary["service"]     = ATTAnalytics.helper.analyticsConfiguration.appID ?? ""
        identificationDictionary["os"]          = self.deviceOSInfo()
        identificationDictionary["device"]      = self.deviceInfo()
        identificationDictionary["network"]     = self.networkInfo()
        identificationDictionary["app"]         = self.appInfo()
        identificationDictionary["lib"]         = self.libInfo()
        identificationDictionary["location"]    = self.locationInfo()
        
        var userProfile: [String:Any] = [:]
        if let savedUserProfile = UserDefaults.standard.object(forKey: "ATTUserProfile") as? [String:Any] {
            userProfile = savedUserProfile
        }
        userProfile["userStatus"] = "0"
        if let userType = UserDefaults.standard.object(forKey: "ATTUserLoginType") as? String,userType == "host" {
            userProfile["userStatus"] = "1"
        }
        identificationDictionary["data"] = userProfile
        return identificationDictionary
    }
    private func locationInfo() -> [String:Any] {
        let latitude =  ATTMiddlewareSchemaManager.manager.locationManager?.latitude  ?? 0
        let longitude = ATTMiddlewareSchemaManager.manager.locationManager?.longitude ?? 0
        let location = ["latitude":"\(latitude)", "longitude":"\(longitude)"]
        return location
    }
    
    private func appInfo() -> [String:Any] {
        let dictionary      = Bundle.main.infoDictionary
        let version         = dictionary?["CFBundleShortVersionString"]
        let appName         = dictionary?["CFBundleName"]
        let bundleID        = Bundle.main.bundleIdentifier
        
        var appInfoDictionary : [String:Any] = [:]
        
        appInfoDictionary["version"]        = version
        appInfoDictionary["nameSpace"]      = bundleID
        appInfoDictionary["name"]           = appName
        appInfoDictionary["language"]       = fetchAppLanguage()
        appInfoDictionary["build"]          = ""
        var appVariantValue                 = "debug"
        if let appDictionary = ATTAnalytics.helper.analyticsConfiguration.appInformationDictionary,let appVariant = appDictionary[ATTAnalytics.kAppVariant] as? String{
            appVariantValue = appVariant
        }
        appInfoDictionary["variant"]        = appVariantValue
        
        return appInfoDictionary
    }
    private func fetchAppDefaultLanguage() -> String{
        guard let languageCode = Locale.current.languageCode else {
            return ""
        }
        return languageCode
    }
    
    private func fetchAppLanguage() -> String{
        guard let appInformationDictionary = ATTAnalytics.helper.analyticsConfiguration.appInformationDictionary,let selectedLanguage = appInformationDictionary[ATTAnalytics.kAppLanguage] as? String else {
            return fetchAppDefaultLanguage()
        }
        return selectedLanguage
    }
    private func sessionInfo() -> [String:Any] {
        var sessionInfoDictionary: [String:Any] = [:]
        
        sessionInfoDictionary["sessionId"]  = self.encodedSessionString
        sessionInfoDictionary["userId"]     = self.currentUserID()
        sessionInfoDictionary["event"]      = "SessionStart"
        sessionInfoDictionary["eventType"]  = "SessionStart"
        sessionInfoDictionary["timestamp"]  = "\(ATTMiddlewareSchemaManager.manager.timeStamp())"
        sessionInfoDictionary["service"]      = ATTAnalytics.helper.analyticsConfiguration.appID ?? ""
        sessionInfoDictionary["os"]        = self.deviceOSInfo()
        sessionInfoDictionary["device"]    = self.deviceInfo()
        sessionInfoDictionary["network"]   = self.networkInfo()
        sessionInfoDictionary["app"]       = self.appInfo()
        sessionInfoDictionary["lib"]       = self.libInfo()
        sessionInfoDictionary["location"]  = self.locationInfo()
        
        return sessionInfoDictionary
    }
    
    private func libInfo() -> [String:Any] {
        return ["version":"1.0.1","variant":ATTAnalytics.helper.analyticsConfiguration.isDebugFrameWork ? "debug":"release"]
    }
    
    private func deviceOSInfo() -> [String:Any] {
        var appOSInfoDictionary: [String:Any] = [:]
        appOSInfoDictionary["name"] = "iOS"
        appOSInfoDictionary["version"] = UIDevice.current.systemVersion
        return appOSInfoDictionary
        
    }
    
    private func deviceInfo() -> [String:Any] {
        
        var appInfoDictionary: [String:Any] = [:]
        
        appInfoDictionary["deviceId"]       = UIDevice.current.identifierForVendor?.uuidString
        appInfoDictionary["type"]           = UIDevice.current.modelType
        appInfoDictionary["manufacture"]    = "Apple"
        appInfoDictionary["model"]          = UIDevice.current.model
        appInfoDictionary["name"]           = UIDevice.current.name
        appInfoDictionary["locale"]         = NSLocale.current.languageCode ?? ""
        appInfoDictionary["resolution"]     = "\(UIScreen.main.bounds.size.width) x \(UIScreen.main.bounds.size.height)"
        
        return appInfoDictionary
    }
    
    private func networkInfo() -> [String:Any] {
        var networkInfoDictionary: [String:Any] = [:]
        
        if ATTReachability.reachability.currentReachabilityStatus == .reachableViaWiFi {
            networkInfoDictionary["type"] = "Wifi"
        } else {
            networkInfoDictionary["type"]    = "Cellular"
            networkInfoDictionary["carrier"] = ATTReachability.reachability.carrierName() ?? ""
        }
        
        networkInfoDictionary["connectionSpeed"] = ""
        
        return networkInfoDictionary
    }
    
    private func currentUserID() -> String {
        var userID = UserDefaults.standard.object(forKey: "ATTUserID") as? String
        
        if userID == nil || userID == "" {
            userID = "\(ATTMiddlewareSchemaManager.manager.guestUniqueID())"
            userID = self.base64Encoded(string: userID)
            UserDefaults.standard.setValue(userID, forKey: "ATTUserID")
            UserDefaults.standard.setValue("guest", forKey: "ATTUserLoginType")
        }
        
        return userID ?? ""
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
extension Date {
    var millisecondsSince1970:Int {
        return Int((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
}
