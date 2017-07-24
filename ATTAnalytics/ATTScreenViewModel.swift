//
//  ATTScreenViewModel.swift
//  TrackingHelper
//
//  Created by Sreekanth R on 20/01/17.
//  Copyright © 2017 Sreekanth R. All rights reserved.
//

import UIKit
import CoreLocation

class ATTScreenViewModel: NSObject {
    public var screenViewID:String?
    public var screenName:String?
    public var screenTitle:String?
    public var screenViewBeginTime:Date?
    public var previousScreenName:String?
    public var previousScreenTitle:String?
    public var screeViewDuration:Double?
    public var screenEventsArray:Array<AnyObject>?
    public var latitude:CLLocationDegrees?
    public var longitude:CLLocationDegrees?
    
    //If its false dont pass screenview event
    public var isNeedToPassScreenViewEvent:Bool = true

    
    override init() {
        super.init()
    }
    
    convenience init(screenViewID:String?,
                     screenName name:String?,
                     screenTitle title:String?,
                     previousScreen previousScreenName:String?,
                     previousScreenTitle previousTitle:String?,
                     screenViewBeginAt screenViewBeginTime:Date?,
                     latitude lat:CLLocationDegrees?,
                     longitude log:CLLocationDegrees?) {
        self.init()
        
        self.screenViewID = screenViewID
        self.previousScreenName = previousScreenName
        self.previousScreenTitle = previousTitle
        self.screenName = name
        self.screenTitle = title
        self.screenViewBeginTime = screenViewBeginTime
        self.latitude = lat
        self.longitude = log
    }
}
