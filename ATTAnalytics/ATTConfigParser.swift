//
//  ATTConfigParser.swift
//  TrackingSampple
//
//  Created by Sreekanth R on 23/11/16.
//  Copyright © 2016 Sreekanth R. All rights reserved.
//
/// Do visit http://www.jsoneditoronline.org/?id=7eabb6c0d615aeef65c40af1bf1c4a4b for config pattern

import UIKit

class ATTConfigParser: NSObject {
    // MARK: - Private members
    var configurations:[String: Any]?
    
    // MARK: - deinit
    deinit {
        self.configurations = nil
    }
    
    override init() {
        super.init()
    }
    convenience init(configurations:[String: Any]?) {
        self.init()
        self.configurations = configurations
    }
    
    // MARK: - Public methods
    
    /// Find configuration for class
    ///
    /// - Parameters:
    ///   - aClass: aClass
    ///   - selector: selector
    ///   - type: type description
    ///   - keyword: keyword description
    /// - Returns: return value description
    func findConfigurationForClass(aClass:AnyClass?,
                                   withSelector selector:Selector?,
                                   ofStateType type:String?,
                                   havingAppSpecificKeyword keyword:String?) -> [AnyObject]? {
        
        guard let analyticsConfigurations = self.configurations,let root = analyticsConfigurations[ATTConfigConstants.Analytics] as? [AnyObject] else {
            return nil
        }
        
        var resultArray: [AnyObject] = []
        for eachAgent in root {
            if let agentEnabled = eachAgent[ATTConfigConstants.AgentEnabled] as? Bool,  agentEnabled == true,let dataField = eachAgent[ATTConfigConstants.AgentDataField] as? [AnyObject] {
                
                var resultConfig:[String:AnyObject]?
                
                if type == ATTConfigConstants.AgentKeyTypeState {
                    resultConfig = self.stateConfigFromDataField(dataFieldArray:dataField,
                                                                 agent:eachAgent as? [String: AnyObject],
                                                                 aClass:aClass,
                                                                 selector:selector,
                                                                 appSpecificKeyword:keyword)
                } else {
                    resultConfig = self.eventConfigFromDataField(dataFieldArray:dataField,
                                                                 agent:eachAgent as? [String: AnyObject],
                                                                 aClass:aClass,
                                                                 selector:selector,
                                                                 appSpecificKeyword:keyword)
                }
                
                if let resultConfig = resultConfig, resultConfig.count > 0 {
                    resultArray.append(resultConfig as AnyObject)
                }
            }
            
            
        }
        
        return resultArray
    }
    
    // MARK: - Private methods
    
    /// Filtering state change configurations
    ///
    /// - Parameters:
    ///   - dataFieldArray: dataFieldArray
    ///   - agent: agent description
    ///   - aClass: aClass description
    ///   - selector: selector description
    ///   - appSpecificKeyword: appSpecificKeyword description
    /// - Returns: return value description
    private func stateConfigFromDataField(dataFieldArray:[AnyObject],
                                          agent:[String:AnyObject]?,
                                          aClass:AnyClass?,
                                          selector:Selector?,
                                          appSpecificKeyword:String?) -> [String:AnyObject]? {
        
        var resultConfig: [String:AnyObject] = [:]
        for eachData in dataFieldArray {
            
            if let keyType = eachData[ATTConfigConstants.AgentKeyType] as? String,keyType == ATTConfigConstants.AgentKeyTypeState {
                if let appSpecificClass    = eachData[ATTConfigConstants.AppSpecificClass] as? String,let aClass = aClass , appSpecificClass == "\(aClass)" {
                    let result = self.appendAgentDetails(agent:agent,
                                                         dataField:eachData as? Dictionary<String, AnyObject>)
                    resultConfig = result
                    break
                }
            }
        }
        
        return resultConfig
    }
    
    
    ///  Filtering event configurations
    ///
    /// - Parameters:
    ///   - dataFieldArray: dataFieldArray description
    ///   - agent: agent description
    ///   - aClass: aClass description
    ///   - selector: selector description
    ///   - appSpecificKeyword: appSpecificKeyword description
    /// - Returns: return value description
    private func eventConfigFromDataField(dataFieldArray:[AnyObject],
                                          agent:[String:AnyObject]?,
                                          aClass:AnyClass?,
                                          selector:Selector?,
                                          appSpecificKeyword:String?) -> [String:AnyObject]? {
        
        var resultConfiguration: [String:AnyObject]?
        
        for eachData in dataFieldArray {
            if let keyType = eachData[ATTConfigConstants.AgentKeyType] as? String, keyType == ATTConfigConstants.AgentKeyTypeEvent    {
                if let appSpecificClass = eachData[ATTConfigConstants.AppSpecificClass] as? String,let appSpecificMethod = eachData[ATTConfigConstants.AppSpecificMethod] as? String,let aClass = aClass,let selector = selector,appSpecificClass == "\(aClass)",appSpecificMethod == "\(selector)" {
                    let result = self.appendAgentDetails(agent:agent,
                                                         dataField:eachData as? Dictionary<String, AnyObject>)
                    resultConfiguration = result
                    break
                }
                else {
                    if  let appSpecificKey = eachData[ATTConfigConstants.AppSpecificKey] as? String , appSpecificKey == appSpecificKeyword {
                        let result = self.appendAgentDetails(agent:agent,
                                                             dataField:eachData as? [String:AnyObject])
                        resultConfiguration = result
                        break
                    }
                }
            }
        }
        
        return resultConfiguration
    }
    
    /// Description
    ///
    /// - Parameters:
    ///   - agent: agent description
    ///   - dataField: dataField description
    /// - Returns: return value description
    private func appendAgentDetails(agent:[String:AnyObject]?,
                                    dataField:[String:AnyObject]?) -> [String:AnyObject] {
        
        var resultDictionary: [String:AnyObject] = [:]
        
        if let agentDictionary = agent {
            resultDictionary[ATTConfigConstants.AgentName]            = agentDictionary[ATTConfigConstants.AgentName]
            resultDictionary[ATTConfigConstants.AgentType]            = agentDictionary[ATTConfigConstants.AgentType]
            resultDictionary[ATTConfigConstants.AgentURL]             = agentDictionary[ATTConfigConstants.AgentURL]
            resultDictionary[ATTConfigConstants.AgentFlushInterval]   = agentDictionary[ATTConfigConstants.AgentFlushInterval]
            resultDictionary[ATTConfigConstants.AgentPostToURL]       = agentDictionary[ATTConfigConstants.AgentPostToURL]
            resultDictionary[ATTConfigConstants.AgentEnabled]         = agentDictionary[ATTConfigConstants.AgentEnabled]
        }
        if let dataFieldDictionary = dataField {
            resultDictionary[ATTConfigConstants.AgentKey]             = dataFieldDictionary[ATTConfigConstants.AgentKey]
            resultDictionary[ATTConfigConstants.AgentKeyType]         = dataFieldDictionary[ATTConfigConstants.AgentKeyType]
            resultDictionary[ATTConfigConstants.AppSpecificMethod]    = dataFieldDictionary[ATTConfigConstants.AppSpecificMethod]
            resultDictionary[ATTConfigConstants.AppSpecificClass]     = dataFieldDictionary[ATTConfigConstants.AppSpecificClass]
            resultDictionary[ATTConfigConstants.AppSpecificKey]       = dataFieldDictionary[ATTConfigConstants.AppSpecificKey]
            resultDictionary[ATTConfigConstants.AgentParam]           = dataFieldDictionary[ATTConfigConstants.AgentParam]
        }
        
        return resultDictionary
    }
}
