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
    private var screenEventsArray:[AnyObject]?
    
    var screenViewModel:ATTScreenViewModel?
    var previousScreenViewModel:ATTScreenViewModel?
    var locationManager:ATTLocationManager?
    var appInfo: [String:AnyObject]?
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
    
    var deviceTimestamp: String {
        return "\(Date().millisecondsSince1970)"
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
        self.createSession()
    }
    
    func applicationDidEnterBackground() -> Void {
        self.appLaunched = false
    }
    
    func applicationDidBecomeActive() -> Void {
        /*
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
 */
    }
    
    // Session management
    func createSession() -> Void {
        self.flushManager?.createSession()
    }
    
    // MARK: - Screen view events
    
    /// ScreenView event store in to local DB
    ///
    /// - Parameters:
    ///   - screenViewID: unique ID
    ///   - name: screenName
    ///   - title: screenTitle
    ///   - previousScreenName: previousScreen Name
    ///   - previousTitle: previousScreenTitle
    ///   - aClass: screen class name
    ///   - screenViewBeginTime: screenView begin time
    func startNewScreenViewWithScreenID(screenViewID:String?,
                                        screenName name:String?,
                                        screenTitle title:String?,
                                        previousScreen previousScreenName:String?,
                                        previousScreenTitle previousTitle:String?,
                                        screenClass aClass:AnyClass?,
                                        screenViewBeginAt screenViewBeginTime:Date?) -> Void {
        self.lastViewedScreen       = name
        self.lastViewedScreenTitle  = title
        self.lastViewedScreenClass  = aClass
        self.previousScreenName     = previousScreenName
        self.previousScreenTitle    = previousTitle
        
        self.screenViewModel        = ATTScreenViewModel(screenViewID:screenViewID,
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
    
    
    /// Update previous screen data
    func updateScreenCloseDetails() -> Void {
        if let previousViewModel = self.previousScreenViewModel  {
            if let screenViewBeginTime = previousViewModel.screenViewBeginTime {
                 self.previousScreenViewModel?.screeViewDuration = -screenViewBeginTime.timeIntervalSince(ATTAnalytics.helper.currentLocalDate())
            }
            self.coreDataManager.updateScreenView(screenViewModel: previousViewModel)
        }
        self.previousScreenViewModel = self.screenViewModel
    }
    
    // MARK: - Button action events
    
    /// Create Button action event in core data
    ///
    /// - Parameters:
    ///   - eventName: Action name
    ///   - startTime: start time
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
    
    /// <#Description#>
    ///
    /// - Parameters:
    ///   - eventName: <#eventName description#>
    ///   - startTime: <#startTime description#>
    ///   - arguments: <#arguments description#>
    ///   - duration: <#duration description#>
    func createCustomEvent(eventName:String?,
                           eventStartTime startTime:Date?,
                           customArguments arguments:Dictionary<String, AnyObject>?,
                           eventDuration duration:Double?) -> Void {
        
        let newScreenID = fetchCurrentScrrenViewID()
        let newEvent    = ATTEventModel(screenViewID:newScreenID,
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
    
    /// fetch Current ScrrenViewID
    ///
    /// - Returns: ScrrenViewID
    func fetchCurrentScrrenViewID() -> String {
        var newScreenID = ""
        if let screenViewID = self.screenViewModel?.screenViewID{
            newScreenID = screenViewID
        }else{
            newScreenID = self.newUniqueID()
        }
        return newScreenID
    }
    
    /// <#Description#>
    ///
    /// - Returns: <#return value description#>
    public func newUniqueID() -> String {
        return "\(UIDevice.current.identifierForVendor!.uuidString.replacingOccurrences(of: "-", with: ""))\(self.deviceTimestamp)"
    }
    
    /// <#Description#>
    ///
    /// - Returns: <#return value description#>
    public func guestUniqueID() -> String {
        let bundleID    = Bundle.main.bundleIdentifier ?? ""
        //userid = deviceid+bundleID
        return "\(UIDevice.current.identifierForVendor!.uuidString.replacingOccurrences(of: "-", with: ""))\(bundleID)"
    }
//    func timeStamp() -> String {
//        return self.timestamp
//    }
}

// MARK: - Flush manager delegates
extension ATTMiddlewareSchemaManager:ATTFlushManagerDelegate {
    
    /// <#Description#>
    ///
    /// - Parameter screenViewID: <#screenViewID description#>
    /// - Returns: <#return value description#>
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
    
    /// Create screenModel for event
    ///
    /// - Parameter eachEvent: eachEvent
    /// - Returns: ATTScreenViewModel object
    func createScreenModelForEvent(_ eachEvent: AnyObject) -> ATTScreenViewModel {
        
        let screenViewID = eachEvent.value(forKeyPath: "screenViewID") as? String ?? ""
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
    
    /// Fetch all stored Events
    ///
    /// - Returns: array of stored events
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
    
    /// removed synced event from DB
    ///
    /// - Parameter screenIDArray: <#screenIDArray description#>
    func removedSyncedObjects(screenIDArray:[String]?) -> Void {
        self.coreDataManager.removeSyncedObjects(screenIDArray: screenIDArray!)
    }
}
