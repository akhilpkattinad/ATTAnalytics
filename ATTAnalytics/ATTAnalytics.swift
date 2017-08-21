//
//  TrackingHelper.swift
//  test
//
//  Created by Sreekanth R on 03/11/16.
//  Copyright © 2016 Sreekanth R. All rights reserved.
//

import Foundation
import UIKit

public class ATTAnalytics: NSObject {
    
    
    
    // MARK: Pubclic Constants
    public static let TrackingNotification      = "RegisterForTrakingNotification"
    public static let CrashTrackingNotification = "RegisterForCrashTrakingNotification"
    public static let IdentifyNotification      = "IndentifyUser"
    public static let LoggoutNotification       = "loggoutUser"
    public static let kAppLanguage              = "language"
    private static let crashLogFileName         = "ATTCrashLog.log"
    public static let kAppVariant               = "AppVariant"

    enum StateTypes {
        case State
        case Event
    }
    
    public var analyticsConfiguration: ATTAnalyticsConfiguration!
    private var configParser:ATTConfigParser?
    private var configurationFilePath:String?
    private var presentViewControllerName:String?
    private var previousViewControllerName:String?
    private var previousViewControllerTitle:String?
    private var screenViewID:String?
    private var stateChangeTrackingSelector:Selector?
    private var screenViewStart:Date?
    private let cacheDirectory = (NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                                                      .userDomainMask,
                                                                      true)[0] as String).appending("/")
    // MARK: - Lazy variables
    lazy var fileManager: FileManager = {
        return FileManager.default
    }()
    
    lazy var schemaManager: ATTMiddlewareSchemaManager = {
        return ATTMiddlewareSchemaManager()
    }()
    
    // MARK: - Shared object
    /// Shared Object
    public class var helper: ATTAnalytics {
        struct Static {
            static let instance = ATTAnalytics()
        }
        return Static.instance
    }
    
    // MARK: - deinit
    deinit {
        self.configParser = nil
        self.configurationFilePath = nil
        self.stateChangeTrackingSelector = nil
        self.screenViewStart = nil
        self.presentViewControllerName = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    /// This Analytics initate to track the app event also pass appConfiguration objects to
    ///
    /// - Parameter appConfiguration: ATTAnalyticsConfiguration instance here define some configuration settings.
    public func beginTracking(_ appConfiguration: ATTAnalyticsConfiguration) -> Void {
        self.analyticsConfiguration = appConfiguration
        self.createConfigParser(configurations:appConfiguration.appConfigurationDictionary)
        self.configureSwizzling(stateTracking:appConfiguration.trackingStateTypes, methodTracking:appConfiguration.trackingMethodTypes)
        self.setupMiddlewareManager()
    }
    
    /// Can be called manually for Manual event tracking
    ///
    /// - Parameters:
    ///   - keyword: Event name
    ///   - arguments: customArguments is used when an object requires to trigger event with dynamic values
    ///   - event: ATTCustomEvent instance
    public func registerForTracking(appSpecificKeyword keyword:String?,
                                    customArguments arguments:[String:AnyObject]?,
                                    customEvent event:ATTCustomEvent?) -> Void {
        var duration:Double = 0.0
        if let eventDuration = event?.duration {
            duration = eventDuration
        }
        ATTMiddlewareSchemaManager.manager.createCustomEvent(eventName: keyword,
                                                             eventStartTime: Date(),
                                                             customArguments: arguments,
                                                             eventDuration: duration)
    }
    
    /// Used to receive the crashlog events
    /// Must be called once inside AppDelegate's **applicationDidBecomeActive**
    public func registerForCrashLogging() -> Void {
        if let crashLogData = self.readLastSavedCrashLog() {
            
            if (crashLogData as String).characters.count > 0 {
                var notificationObject: [String: AnyObject] = [:]
                
                notificationObject["type"]          = "CrashLogTracking" as AnyObject?
                notificationObject["crash_report"]  = crashLogData as AnyObject?
                notificationObject["app_info"]      = self.appInfo() as AnyObject?
                
                NotificationCenter.default.post(name:NSNotification.Name(rawValue:ATTAnalytics.CrashTrackingNotification),
                                                object:notificationObject)
            }
        }
    }
    
    // MARK: - User info
    
    /// User info
    ///
    /// - Parameters:
    ///   - userId: userID string
    ///   - profile: userProfile Dictionary
    public func identifyUser(userID userId:String,
                             userProfile profile:[String:AnyObject]?) -> Void {
        
        UserDefaults.standard.setValue(userId, forKey: "ATTUserID")
        UserDefaults.standard.setValue(profile, forKey: "ATTUserProfile")
        NotificationCenter.default.post(name:NSNotification.Name(rawValue:ATTAnalytics.IdentifyNotification),
                                        object:nil)
    }
    
    /// Reset User
    public func resetUser() -> Void {
        
        UserDefaults.standard.setValue("", forKey: "ATTUserID")
        UserDefaults.standard.setValue("", forKey: "ATTUserProfile")
        NotificationCenter.default.post(name:NSNotification.Name(rawValue:ATTAnalytics.LoggoutNotification),
                                        object:nil)
    }
    
    // MARK: - Private methods
    
    /// setup MiddlewareManager calss
    private func setupMiddlewareManager() -> Void {
        ATTMiddlewareSchemaManager.manager.startUpdatingLocations()
        ATTMiddlewareSchemaManager.manager.startFlushManager()
        ATTMiddlewareSchemaManager.manager.appInfo = self.appInfo()
    }
    
    
    /// Initiate ATTConfigParser class
    ///
    /// - Parameter configurations: configurations dictionary
    private func createConfigParser(configurations:[String: Any]?) -> Void{
        self.configParser = nil
        self.configParser = ATTConfigParser(configurations:configurations)
    }
    
    /// configure swizzling Method
    ///
    /// - Parameters:
    ///   - state: TrackingTypes enum
    ///   - method:TrackingTypes enum
    private func configureSwizzling(stateTracking state:TrackingTypes?,
                                    methodTracking method:TrackingTypes?) -> Void {
        if state == .Automatic {
            self.swizzileLifecycleMethodImplementation()
        }
        if method == .Automatic {
            self.swizzileIBActionMethods()
        }
    }
    
    /// Triggered for state changes
    ///
    /// - Parameter viewController: viewController
    private func triggerEventForTheVisibleViewController(viewController:UIViewController) -> Void {
        self.trackConfigurationForClass(aClass:viewController.classForCoder,
                                        withSelector:self.stateChangeTrackingSelector,
                                        ofStateType:.State,
                                        havingAppSpecificKeyword:nil,
                                        withCustomArguments:nil)
    }
    
    /// Triggered for method invocation
    ///
    /// - Parameters:
    ///   - originalClass: originalClass
    ///   - selector: selector method
    private func triggerEventForTheVisibleViewController(originalClass:AnyClass?, selector:Selector?) -> Void {
        self.trackConfigurationForClass(aClass:originalClass,
                                        withSelector:selector,
                                        ofStateType:.Event,
                                        havingAppSpecificKeyword:nil,
                                        withCustomArguments:nil)
    }
    
    /// Looping through the configuration to find out the matching paramters and values
    ///
    /// - Parameters:
    ///   - aClass: aClass
    ///   - selector: method
    ///   - type: auto or manual enum
    ///   - keyword: havingAppSpecificKeyword
    ///   - arguments: withCustomArguments
    /// - Returns: return value description
    @discardableResult private func trackConfigurationForClass(aClass:AnyClass?,
                                                               withSelector selector:Selector?,
                                                               ofStateType type:StateTypes?,havingAppSpecificKeyword
        keyword:String?,
                                                               withCustomArguments arguments:Dictionary<String, AnyObject>?) -> [AnyObject]? {
        
        let paramters = self.configurationForClass(aClass:aClass,
                                                   withSelector:selector,
                                                   ofStateType:type,
                                                   havingAppSpecificKeyword:keyword)
        
        if let paramterArray = paramters,paramterArray.count > 0 {
            self.registeredAnEvent(configuration:paramters,
                                   customArguments:arguments)
        }
        
        return paramters
    }
    // Parsing the Configuration file
    private func fetchConfigurationDictionary(_ filePath: String?) ->[String:AnyObject]? {
        guard  let resourcePath = filePath else {
            return nil
        }
        let resourceData = NSDictionary(contentsOfFile: resourcePath)
        return resourceData as? [String:AnyObject]
    }
    
    // Parsing the Configuration file
    private func configurationDictionary() -> NSDictionary? {
        guard  let resourcePath = self.configurationFilePath else {
            return nil
        }
        let resourceData = NSDictionary(contentsOfFile: resourcePath)
        return resourceData
    }
    
    /// Configuration for class
    ///
    /// - Parameters:
    ///   - aClass: Class value
    ///   - selector: Method selector
    ///   - type: type
    ///   - keyword: keyword
    /// - Returns: Array of object
    private func configurationForClass(aClass:AnyClass?,
                                       withSelector selector:Selector?,
                                       ofStateType type:StateTypes?,
                                       havingAppSpecificKeyword keyword:String?) -> [AnyObject]? {
        var state = ""
        if type == .State {
            state = ATTConfigConstants.AgentKeyTypeState
        } else {
            state = ATTConfigConstants.AgentKeyTypeEvent
        }
        let resultConfig = self.configParser?.findConfigurationForClass(aClass:aClass,
                                                                        withSelector:selector,
                                                                        ofStateType:state,
                                                                        havingAppSpecificKeyword:keyword)
        return resultConfig
    }
    
    
    /// Triggering a Notification, whenever it finds a matching configuration
    ///
    /// - Parameters:
    ///   - configuration: configuration
    ///   - customArguments: customArguments
    private func registeredAnEvent(configuration:Array<AnyObject>?,
                                   customArguments:Dictionary<String, AnyObject>?) -> Void {
        
        var notificationObject:[String: AnyObject] = [:]
        notificationObject["configuration"]     = configuration as AnyObject?
        notificationObject["custom_arguments"]  = customArguments as AnyObject?
        notificationObject["app_info"]          = self.appInfo() as AnyObject?
        NotificationCenter.default.post(name:NSNotification.Name(rawValue:ATTAnalytics.TrackingNotification),
                                        object:notificationObject)
    }
    
    /// Fetch app information
    ///
    /// - Returns: appInfo Dictionary
    private func appInfo() -> Dictionary<String, AnyObject>? {
        
        let dictionary  = Bundle.main.infoDictionary
        let version     = dictionary?["CFBundleShortVersionString"] as? String
        let build       = dictionary?["CFBundleVersion"] as? String
        let appName     = dictionary?["CFBundleName"] as? String
        let bundleID    = Bundle.main.bundleIdentifier
        
        var appInfoDictionary: [String: AnyObject] = [:]
        
        appInfoDictionary["build"]          = build as AnyObject?
        appInfoDictionary["bundleVersion"]  = version as AnyObject?
        appInfoDictionary["bundleID"]       = bundleID as AnyObject?
        appInfoDictionary["bundleName"]     = appName as AnyObject?
        return appInfoDictionary
    }
    
    // MARK: - Crashlog file manipulations
    private func readLastSavedCrashLog() -> String? {
        let fileName = ATTAnalytics.crashLogFileName
        let filePath = self.cacheDirectory.appending(fileName)
        var dataString: String?
        
        if self.fileManager.fileExists(atPath:filePath) {
            if let crashLogData = NSData(contentsOfFile:filePath) {
                dataString = NSString(data:crashLogData as Data, encoding:String.Encoding.utf8.rawValue) as String?
            }
        }
        // To avoid complexity in reading and parsing the crash log, keeping only the last crash information
        // For allowing this, previous crash logs are deleted after reading
        self.removeLastSavedCrashLog()
        self.createCrashLogFile(atPath:filePath)
        return dataString
    }
    
    private func createCrashLogFile(atPath: String) -> Void {
        freopen(atPath.cString(using:String.Encoding.utf8), "a+", stderr)
    }
    
    private func removeLastSavedCrashLog() -> Void {
        let filePath = self.cacheDirectory.appending(ATTAnalytics.crashLogFileName)
        try?self.fileManager.removeItem(atPath:filePath)
    }
    
    /////////////////////////////////////////////////////////////////////////////////////
    // MARK: - Automatic screen change tracking
    // MUST BE CALLED ONLY ONCE
    
    private func swizzileLifecycleMethodImplementation() -> Void {
        let originalClass = UIViewController.self
        let swizzilableClass = ATTAnalytics.self
        
        self.swizzileViewWillAppear(originalClass: originalClass, and: swizzilableClass)
        self.swizzileViewDidDisappear(originalClass: originalClass, and: swizzilableClass)
        // WillAppear and DidDisappear is done to track maximum events
    }
    
    /// ViewWillAppear method exchangeImplementations
    ///
    /// - Parameters:
    ///   - originalClass: originalClass
    ///   - swizzilableClass: swizzilableClass
    private func swizzileViewWillAppear(originalClass:AnyClass?, and swizzilableClass:AnyClass?) -> Void {
        let swizzilableSelector = #selector(ATTAnalytics.trackViewWillAppear(_:))
        self.stateChangeTrackingSelector = #selector(UIViewController.viewWillAppear(_:))
        let originalMethod = class_getInstanceMethod(originalClass, self.stateChangeTrackingSelector!)
        let swizzledMethod = class_getInstanceMethod(swizzilableClass, swizzilableSelector)
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    /// ViewDidDisappear method exchangeImplementations
    ///
    /// - Parameters:
    ///   - originalClass: originalClass
    ///   - swizzilableClass: swizzilableClass
    private func swizzileViewDidDisappear(originalClass:AnyClass?, and swizzilableClass:AnyClass?) -> Void {
        let swizzilableSelector = #selector(ATTAnalytics.trackViewDidDisappear(_:))
        let originalSelector = #selector(UIViewController.viewDidDisappear(_:))
        let originalMethod = class_getInstanceMethod(originalClass, originalSelector)
        let swizzledMethod = class_getInstanceMethod(swizzilableClass, swizzilableSelector)
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    /// viewWillAppear Swizzled methods
    ///
    /// - Parameter animated: is animated
    func trackViewWillAppear(_ animated: Bool) -> Void {
        // Here self refers to the UIViewController, self.autoTrackScreenChanges() will crash
        if "\(self.classForCoder)" != "UINavigationController"
            && "\(self.classForCoder)" != "UITabBarController"
            && "\(self.classForCoder)" != "UIInputWindowController" {
            
            ATTAnalytics.helper.newScreenAppeared(viewController: self)
        }
    }
    
    /// trackViewDidDisappear
    ///
    /// - Parameter animated: is animated
    func trackViewDidDisappear(_ animated: Bool) -> Void {
        // Here self refers to the UIViewController, self.autoTrackScreenChanges() will crash
        if "\(self.classForCoder)" != "UINavigationController"
            && "\(self.classForCoder)" != "UITabBarController"
            && "\(self.classForCoder)" != "UIInputWindowController" {
            ATTAnalytics.helper.screenDisappeared(viewController: self)
        }
    }
    
    /// view Appeared method call
    ///
    /// - Parameter viewController: Appeared viewController
    func newScreenAppeared(viewController:NSObject?) -> Void {
        if let topViewController = viewController as? UIViewController {
            self.presentViewControllerName = "\(topViewController.classForCoder)"
            self.triggerEventForTheVisibleViewController(viewController:topViewController)
            self.createNewScreenView(withClass: topViewController.classForCoder, screenTitle: topViewController.title)
            self.previousViewControllerName = self.presentViewControllerName
            self.previousViewControllerTitle = topViewController.title
        }
    }
    
    /// view Disappeared method call
    ///
    /// - Parameter viewController: Disappeared controller
    func screenDisappeared(viewController:NSObject?) -> Void {
        self.updatePreviousScreenActivityObject()
    }
    
    /// Create screenview event
    ///
    /// - Parameters:
    ///   - aClass: class name
    ///   - title: controller title
    private func createNewScreenView(withClass aClass:AnyClass?, screenTitle title:String?) -> Void {
        self.screenViewID = self.schemaManager.newUniqueID()
        self.screenViewStart = self.currentLocalDate()
        
        ATTMiddlewareSchemaManager.manager.startNewScreenViewWithScreenID(screenViewID: self.screenViewID,
                                                                          screenName: self.presentViewControllerName,
                                                                          screenTitle: title,
                                                                          previousScreen:self.previousViewControllerName,
                                                                          previousScreenTitle: self.previousViewControllerTitle,
                                                                          screenClass:aClass,
                                                                          screenViewBeginAt: self.screenViewStart)
    }
    
    private func updatePreviousScreenActivityObject() -> Void {
        ATTMiddlewareSchemaManager.manager.updateScreenCloseDetails()
    }
    
    // MARK: - Automatic function call tracking
    // MUST BE CALLED ONLY ONCE
    private func swizzileIBActionMethods() -> Void {
        let originalClass:AnyClass = UIApplication.self
        let swizzilableClass = ATTAnalytics.self
        
        let originalMethod = class_getInstanceMethod(originalClass,
                                                     #selector(UIApplication.sendAction(_:to:from:for:)))
        let swizzledMethod = class_getInstanceMethod(swizzilableClass,
                                                     #selector(ATTAnalytics.trackIBActionInvocation(_:to:from:for:)))
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    ///  Swizzled method which will be replacing the original UIApplication's sendAction method
    ///
    /// - Parameters:
    ///   - action: action description
    ///   - target: target description
    ///   - sender: sender description
    ///   - event: event description
    func trackIBActionInvocation(_ action:Selector, to target:Any?, from sender:Any?, for event:UIEvent?) -> Void {
        if let originalObject = target as? NSObject {
            let originalClass:AnyClass = originalObject.classForCoder as AnyClass
            ATTAnalytics.helper.autoTrackMethodInvocationForClass(originalClass:originalClass, selector:action)
        }
        // Inorder to call the original implementation, perform the 3 below steps
        ATTAnalytics.helper.swizzileIBActionMethods()
        UIApplication.shared.sendAction(action, to:target, from:sender, for:event)
        ATTAnalytics.helper.swizzileIBActionMethods()
    }
    
    /// AutoTrackMethodInvocationForClass
    ///
    /// - Parameters:
    ///   - originalClass: originalClass description
    ///   - selector: selector description
    func autoTrackMethodInvocationForClass(originalClass:AnyClass?, selector:Selector?) -> Void {
        self.triggerEventForTheVisibleViewController(originalClass:originalClass, selector:selector)
        ATTMiddlewareSchemaManager.manager.createIBActionEvent(eventName: "\(selector!)", eventStartTime: Date())
    }
    
    func currentLocalDate()-> Date {
        var now = Date()
        var nowComponents = DateComponents()
        let calendar = Calendar.current
        nowComponents.year = Calendar.current.component(.year, from: now)
        nowComponents.month = Calendar.current.component(.month, from: now)
        nowComponents.day = Calendar.current.component(.day, from: now)
        nowComponents.hour = Calendar.current.component(.hour, from: now)
        nowComponents.minute = Calendar.current.component(.minute, from: now)
        nowComponents.second = Calendar.current.component(.second, from: now)
        nowComponents.timeZone = TimeZone(abbreviation: "GMT")!
        now = calendar.date(from: nowComponents)!
        return now as Date
    }
}


