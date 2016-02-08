//
//  AppDelegate.swift
//  SwiftAVCam
//
//  Created by Hooman Mehr on 1/14/16.
//  Copyright © 2016 Hooman Mehr. All rights reserved.
//

import UIKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
            
        hostDevice.beginGeneratingDeviceOrientationNotifications()
            
        return true
        
    }

    func applicationWillEnterForeground(application: UIApplication) {
        
        hostDevice.beginGeneratingDeviceOrientationNotifications()
    }

    func applicationDidEnterBackground(application: UIApplication) {
        
        hostDevice.endGeneratingDeviceOrientationNotifications()
    }

    func applicationWillTerminate(application: UIApplication) {
        
        hostDevice.endGeneratingDeviceOrientationNotifications()
    }

}

