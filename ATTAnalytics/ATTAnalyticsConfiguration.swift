//
//  ATTAnalyticsConfiguration.swift
//  TrackingHelper
//
//  Created by Adarsh GJ on 14/08/17.
//  Copyright © 2017 Sreekanth R. All rights reserved.
//

import UIKit

/// TrackingTypes Enum
///
/// - Automatic: Track event automatically
/// - Manual: Track event maually
public enum TrackingTypes {
    case Automatic
    case Manual
}

public class ATTAnalyticsConfiguration: NSObject {
    
    // For Objective - C support since the converted framework not supporting swift enums
    public static let TrackingTypeAuto          = "Auto"
    public static let TrackingTypeManual        = "Manual"
    
    ///   - appID: application ID
    public var appID:String!
    
    /// configure URL by end user
    public var serverURL: String?

    /// trackingMethodTypes : It TrackingTypes enum value
    public var trackingStateTypes: TrackingTypes?   = .Manual
    
    /// trackingMethodTypes : It TrackingTypes enum value
    public var trackingMethodTypes: TrackingTypes?  = .Manual
    
    /// trackingStateTypesString : This for Objc for setting state tracking type it may Auto or Manual
    public var trackingStateTypesString: String? {
        didSet {
            trackingStateTypes =  trackingStateTypesString == ATTAnalyticsConfiguration.TrackingTypeAuto ? TrackingTypes.Automatic : TrackingTypes.Manual
        }
    }
    
    /// trackingMethodTypesString : This for Objc for setting method tracking type it may Auto or Manual
    public var trackingMethodTypesString: String? {
        didSet {
            trackingStateTypes =  trackingMethodTypesString == ATTAnalyticsConfiguration.TrackingTypeAuto ? TrackingTypes.Automatic : TrackingTypes.Manual
        }
    }
    
    /// appInformationDictionary: App information dictionary
    public var appInformationDictionary: [String:Any]?
    
    /// appConfigurationDictionary : App configuration Dictionary
    public var appConfigurationDictionary: [String:Any]?
    
    
    ///   isfrmaeWorkDebug: Bool parameter.Default will be false
    public var isDebugFrameWork    = false
    
    /// Custom initialise
    ///
    /// - Parameter applicationID: application ID
    init(_ applicationID: String) {
        super.init()
        appID = applicationID
    }
    override init() {
        trackingStateTypes  = .Manual
        trackingMethodTypes = .Manual
        isDebugFrameWork    = false
    }
    
}
