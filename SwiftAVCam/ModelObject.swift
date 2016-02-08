//
//  ModelObject.swift
//  SwiftAVCam
//
//  Created by Hooman Mehr on 2/1/16.
//  Copyright © 2016 Hooman Mehr. All rights reserved.
//
//  Common functionality for model objects


import Foundation


enum ActionStatus: ErrorType, Equatable {
    
    case Pending            // Action pending.
    
    case Cancelled          // Action cancelled

    case Success(AnyObject?) // Action suceeded with optional action result.
    
    case Denied(ErrorType?) // Action failed because of an access restriction.
    
    case Failed(ErrorType?) // Action failed because of an error other than access permission.
}


func ==(lhs: ActionStatus, rhs: ActionStatus) -> Bool {
    
    switch (lhs,rhs) {
        
    case let (.Success(.Some(l)),.Success(.Some(r))) where l===r:
                                                fallthrough
    case (.Success(.None),.Success(.None)):     fallthrough
    case (.Pending,.Pending):                   fallthrough
    case (.Cancelled,.Cancelled):               fallthrough
    case (.Denied(.Some(_)),.Denied(.Some(_))): fallthrough
    case (.Denied(.None),.Denied(.None)):       fallthrough
    case (.Failed(.Some(_)),.Failed(.Some(_))): fallthrough
    case (.Failed(.None),.Failed(.None)):
    
                            return true
        
    default: return false }
}


protocol ModelObject: class {
    
    static var notificationNamePrefix: String { get }
    static var notificationNameSuffix: String { get }
    
    func errorInfo(context context: String, error: NSError?, actionResult: ActionStatus?, caller: String) -> UserInfo
    
    func post(notification name: String, userInfo: UserInfo?, object: AnyObject?, caller: String) -> NotificationSource
    
    /*func repostNotification(notification: NSNotification)*/
    
}

extension ModelObject {
    
    static var notificationNamePrefix: String { return "" }
    static var notificationNameSuffix: String { return "" }

    func errorInfo(context context: String = "", error: NSError? = nil, actionResult: ActionStatus? = nil, caller: String = __FUNCTION__) -> UserInfo {
    
        let errorContext = context != "" ? context : caller.initialCapitalString
        
        var userInfo: UserInfo = ["ErrorContext": errorContext]
        if let error = error { userInfo["Error"] = error }
        if let result = actionResult { userInfo["ActionResult"] = Box(result) }
        
        return userInfo
    }
    
    
    func post(notification name: String = "", userInfo: UserInfo? = nil, object: AnyObject? = nil, caller: String = __FUNCTION__) -> NotificationSource {
        
        let Type = self.dynamicType
        
        let notificationName
              = name != "" ? name : Type.notificationNamePrefix + caller.substringBefore("(").initialCapitalString + Type.notificationNameSuffix
        
        let sender = object ?? self
        
        if let info = userInfo {
            
            notificationCenter.postNotification(NSNotification(
                name: notificationName, object: sender, userInfo: info))
        }
        
        return (name: notificationName, object: sender)
    }

    /* Useless, since it will not have a selector
    func repostNotification(notification: NSNotification) {
        
        notificationCenter.postNotificationName(notification.name, object: self, userInfo: notification.userInfo)
    }
    */
}