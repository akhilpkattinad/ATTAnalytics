//
//  ATTMiddlewareSchemaManager.swift
//  TrackingHelper
//
//  Created by Sreekanth R on 18/01/17.
//  Copyright © 2017 Sreekanth R. All rights reserved.
//

import UIKit
import CoreLocation

class ATTMiddlewareSchemaManager: NSObject {
    // MARK: Private properties
    private var flushManager:ATTFlushManager?
    private var screenEventsArray:Array<AnyObject>?
    
    var screenViewModel:ATTScreenViewModel?
    var previousScreenViewModel:ATTScreenViewModel?
    var locationManager:ATTLocationManager?
    var appInfo:Dictionary<String, AnyObject>?
    var appLaunched:Bool?
    var lastViewedScreen:String?
    var lastViewedScreenTitle:String?
    var lastViewedScreenClass:AnyClass?
    var previousScreenName:String?
    var previousScreenTitle:String?
    
    // MARK: Lazy initializations
    lazy var syncableSchemaArray: [Any] = {
        return []
    }()
    
    lazy var coreDataManager: ATTCoreDataManager = {
        return ATTCoreDataManager()
    }()
    
    var timestamp: String {
        return "\(NSDate().timeIntervalSince1970 * 1000)"
    }
    
    // MARK: Shared object
    /// Shared Object
    public class var manager: ATTMiddlewareSchemaManager {
        struct Static {
            static let instance = ATTMiddlewareSchemaManager()
        }
        
        return Static.instance
    }
    
    // MARK: - deinit
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.screenViewModel = nil
        self.locationManager = nil
        self.appInfo = nil
        self.lastViewedScreen = nil
    }
    
    func startUpdatingLocations() -> Void {
        self.locationManager = ATTLocationManager()
    }
    
    func startFlushManager() -> Void {
        self.flushManager = ATTFlushManager(flushInterval:15, delegate:self)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ATTMiddlewareSchemaManager.applicationDidFinishedLaunching),
                                               name: NSNotification.Name.UIApplicationDidFinishLaunching,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ATTMiddlewareSchemaManager.applicationDidBecomeActive),
                                               name: NSNotification.Name.UIApplicationDidBecomeActive,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ATTMiddlewareSchemaManager.applicationDidEnterBackground),
                                               name: NSNotification.Name.UIApplicationDidEnterBackground,
                                               object: nil)
    }
    
    func applicationDidFinishedLaunching() -> Void {
        self.appLaunched = true
        self.flushManager?.resetIdentification()
    }
    
    func applicationDidEnterBackground() -> Void {
        self.appLaunched = false
    }
    
    func applicationDidBecomeActive() -> Void {
        self.createSession()
        if self.appLaunched == false {
            self.startNewScreenViewWithScreenID(screenViewID: self.newUniqueID(),
                                                screenName: self.lastViewedScreen,
                                                screenTitle: self.lastViewedScreenTitle,
                                                previousScreen:self.previousScreenName,
                                                previousScreenTitle: self.previousScreenTitle,
                                                screenClass: self.lastViewedScreenClass,
                                                screenViewBeginAt: Date())
            self.appLaunched = false
        }
    }
    
    // Session management
    func createSession() -> Void {
        self.flushManager?.createSession()
    }
    
    // MARK: - Screen view events
    func startNewScreenViewWithScreenID(screenViewID:String?,
                                        screenName name:String?,
                                        screenTitle title:String?,
                                        previousScreen previousScreenName:String?,
                                        previousScreenTitle previousTitle:String?,
                                        screenClass aClass:AnyClass?,
                                        screenViewBeginAt screenViewBeginTime:Date?) -> Void {
        self.lastViewedScreen = name
        self.lastViewedScreenTitle = title
        self.lastViewedScreenClass = aClass
        self.previousScreenName = previousScreenName
        self.previousScreenTitle = previousTitle
        
        self.screenViewModel = ATTScreenViewModel(screenViewID:screenViewID,
                                                  screenName:name,
                                                  screenTitle:title,
                                                  previousScreen:previousScreenName,
                                                  previousScreenTitle:previousTitle,
                                                  screenViewBeginAt:screenViewBeginTime,
                                                  latitude:self.locationManager?.latitude,
                                                  longitude:self.locationManager?.longitude)
        if self.previousScreenViewModel == nil {
            self.previousScreenViewModel = screenViewModel
        }
        
        self.coreDataManager.createScreenView(screenViewModel: self.screenViewModel)
    }
    
    func updateScreenCloseDetails() -> Void {
        if self.previousScreenViewModel != nil {
            self.previousScreenViewModel?.screeViewDuration = -(self.previousScreenViewModel?.screenViewBeginTime?.timeIntervalSince(ATTAnalytics.helper.currentLocalDate()))!
            self.coreDataManager.updateScreenView(screenViewModel: self.previousScreenViewModel)
        }
        
        self.previousScreenViewModel = self.screenViewModel
    }
    
    // MARK: - Button action events
    func createIBActionEvent(eventName:String?, eventStartTime startTime:Date?) -> Void {        
        let newEvent = ATTEventModel(screenViewID:self.screenViewModel?.screenViewID,
                                     eventType:"ButtonAction",
                                     eventName:eventName,
                                     eventStartTime:startTime,
                                     eventDuration:0,
                                     latitude:self.locationManager?.latitude,
                                     longitude:self.locationManager?.longitude)
        self.coreDataManager.createEvents(event: newEvent)
    }
    
    // MARK: - Custom events
    func createCustomEvent(eventName:String?,
                           eventStartTime startTime:Date?,
                           customArguments arguments:Dictionary<String, AnyObject>?,
                           eventDuration duration:Double?) -> Void {
        var newScreenID = ""
        if self.screenViewModel?.screenViewID == nil{
            newScreenID = self.newUniqueID()
        }else{
           newScreenID = (self.screenViewModel?.screenViewID)!
        }
        
        let newEvent = ATTEventModel(screenViewID:newScreenID,
                                     eventType:"CustomEvent",
                                     eventName:eventName,
                                     eventStartTime:startTime,
                                     eventDuration:duration,
                                     latitude:self.locationManager?.latitude,
                                     longitude:self.locationManager?.longitude,
                                     dataURL:"",
                                     customArguments:arguments)
        self.coreDataManager.createEvents(event: newEvent)
    }
    
    public func newUniqueID() -> String {
        return "\(UIDevice.current.identifierForVendor!.uuidString.replacingOccurrences(of: "-", with: ""))\(self.timeStamp())"
    }
    public func guestUniqueID() -> String {
        let bundleID    = Bundle.main.bundleIdentifier ?? ""
        //userid = deviceid+bundleID
        return "\(UIDevice.current.identifierForVendor!.uuidString.replacingOccurrences(of: "-", with: ""))\(bundleID)"
    }
    func timeStamp() -> String {
        return self.timestamp
    }
}

// MARK: - Flush manager delegates
extension ATTMiddlewareSchemaManager:ATTFlushManagerDelegate {
    /*
    func flushData() -> Array<AnyObject>? {
        self.syncableSchemaArray.removeAll()
        let allScreens = self.coreDataManager.fetchAllScreens()! as Array<AnyObject>
        
        for eachScreen in allScreens {
            if (eachScreen.value(forKeyPath: "presentScreen") as? String) == self.screenViewModel?.screenName &&
                (eachScreen.value(forKeyPath: "screenViewID") as? String) == self.screenViewModel?.screenViewID {
                continue
            }
            
            let screenModel = ATTScreenViewModel(screenViewID:eachScreen.value(forKeyPath: "screenViewID") as? String,
                                                 screenName:eachScreen.value(forKeyPath: "presentScreen") as? String,
                                                 screenTitle:eachScreen.value(forKeyPath: "screenTitle") as? String,
                                                 previousScreen:eachScreen.value(forKeyPath: "previousScreen") as? String,
                                                 previousScreenTitle:eachScreen.value(forKeyPath: "previousScreenTitle") as? String,
                                                 screenViewBeginAt:eachScreen.value(forKeyPath: "screenWatchedTime") as? Date,
                                                 latitude:eachScreen.value(forKeyPath: "latitude") as? Double,
                                                 longitude:eachScreen.value(forKeyPath: "longitude") as? Double)
            
            //screenModel.previousScreenName = eachScreen.value(forKeyPath: "previousScreen") as? String
            screenModel.screeViewDuration = eachScreen.value(forKeyPath: "screenWatchDuration") as? Double
            
            let screenEvents = self.coreDataManager.fetchEventWithScreenID(screenID: screenModel.screenViewID)! as Array<AnyObject>
            
            var eventsArray = Array<AnyObject>()
            var customParam:Dictionary<String, AnyObject>?
            for eachEvent in screenEvents {
                let eventModel = ATTEventModel(screenViewID:screenModel.screenViewID,
                                               eventType:eachEvent.value(forKeyPath: "eventType") as? String,
                                               eventName:eachEvent.value(forKeyPath: "eventName") as? String,
                                               eventStartTime:eachEvent.value(forKeyPath: "eventStartTime") as? Date,
                                               eventDuration:eachEvent.value(forKeyPath: "eventDuration") as? Double,
                                               latitude:eachEvent.value(forKeyPath: "latitude") as? CLLocationDegrees,
                                               longitude:eachEvent.value(forKeyPath: "longitude") as? CLLocationDegrees)
                
                if eachEvent.value(forKeyPath: "customParam") != nil {
                    customParam = try? JSONSerialization.jsonObject(with: eachEvent.value(forKeyPath: "customParam")! as! Data, options: []) as! Dictionary<String, AnyObject>
                    eventModel.arguments = customParam
                }
                
                eventModel.dataURL = eachEvent.value(forKeyPath: "dataURL") as! String?
                
                eventsArray.append(eventModel)
            }
            
            screenModel.screenEventsArray = eventsArray
            self.syncableSchemaArray.append(screenModel)
        }
        
        return self.syncableSchemaArray
    }*/
     func createScreenModelForscreenViewID(_ screenViewID: String) -> ATTScreenViewModel {
        
        guard let screenViewArray = self.coreDataManager.fetchScreenWithScreenID(screenID: screenViewID),screenViewArray.count > 0 else {
            let screenModel = ATTScreenViewModel()
            screenModel.isNeedToPassScreenViewEvent = false
            screenModel.screenViewID = screenViewID
            return screenModel
        }
        let eachScreen = screenViewArray.first
        let screenModel = ATTScreenViewModel(screenViewID:screenViewID,
                                             screenName:eachScreen?.value(forKeyPath: "presentScreen") as? String,
                                             screenTitle:eachScreen?.value(forKeyPath: "screenTitle") as? String,
                                             previousScreen:eachScreen?.value(forKeyPath: "previousScreen") as? String,
                                             previousScreenTitle:eachScreen?.value(forKeyPath: "previousScreenTitle") as? String,
                                             screenViewBeginAt:eachScreen?.value(forKeyPath: "screenWatchedTime") as? Date,
                                             latitude:eachScreen?.value(forKeyPath: "latitude") as? Double,
                                             longitude:eachScreen?.value(forKeyPath: "longitude") as? Double)
        
        screenModel.screeViewDuration = eachScreen?.value(forKeyPath: "screenWatchDuration") as? Double
        return screenModel
        
    }
    func createScreenModelForEvent(_ eachEvent: AnyObject) -> ATTScreenViewModel {
        let screenViewID = eachEvent.value(forKeyPath: "screenViewID") as! String
        let screenModel = createScreenModelForscreenViewID(screenViewID)
        let eventModel = ATTEventModel(screenViewID:screenViewID,
                                       eventType:eachEvent.value(forKeyPath: "eventType") as? String,
                                       eventName:eachEvent.value(forKeyPath: "eventName") as? String,
                                       eventStartTime:eachEvent.value(forKeyPath: "eventStartTime") as? Date,
                                       eventDuration:eachEvent.value(forKeyPath: "eventDuration") as? Double,
                                       latitude:eachEvent.value(forKeyPath: "latitude") as? CLLocationDegrees,
                                       longitude:eachEvent.value(forKeyPath: "longitude") as? CLLocationDegrees)
        
        if let customParamData = eachEvent.value(forKeyPath: "customParam") as? Data ,let customParam = try? JSONSerialization.jsonObject(with: customParamData, options: []) as? [String:AnyObject] {
            eventModel.arguments = customParam
        }
        
        eventModel.dataURL = eachEvent.value(forKeyPath: "dataURL") as? String
        
        
        screenModel.screenEventsArray = [eventModel]
        
        return screenModel
    }
    
    func flushData() -> [Any] {
        self.syncableSchemaArray.removeAll()
        
        guard let allEvents =   self.coreDataManager.fetchAllEvents()  else {
            return []
        }
        for eachEvent in allEvents {
            if let _ = eachEvent.value(forKeyPath: "screenViewID") as? String {
                let screenModel = createScreenModelForEvent(eachEvent)
                self.syncableSchemaArray.append(screenModel)
            }
        }
        return self.syncableSchemaArray
    }
 
    
    func removedSyncedObjects(screenIDArray:Array<String>?) -> Void {
        self.coreDataManager.removeSyncedObjects(screenIDArray: screenIDArray!)
    }
}
