//
//  Helpers.swift
//  SwiftAVCam
//
//  Created by Hooman Mehr on 1/19/16.
//  Copyright © 2016 Hooman Mehr. All rights reserved.
//
//  A grab bag of potentially resusable helper extensions


import UIKit
import AVFoundation
import Photos



// ==========================================================================================================
// MARK: Globals
// ==========================================================================================================



var app: UIApplication { return .sharedApplication() }

var hostDevice: UIDevice { return .currentDevice() }

var notificationCenter: NSNotificationCenter { return .defaultCenter() }

var photoLibrary: PHPhotoLibrary { return .sharedPhotoLibrary() }

var processInfo: NSProcessInfo { return .processInfo() }

var uiQueue: dispatch_queue_t { return dispatch_get_main_queue() }



// ==========================================================================================================
// MARK: Generic/StdLib/Darwin/Foundation Extensions
// ==========================================================================================================



class Box<Type> {
    
    let unbox: Type
    
    init(_ value: Type) { unbox = value }
}


extension Range {
    
    init(one: Element) { self = one ... one }
    init(empty: Element) { self = empty ..< empty }
}


extension String {
    
    var initialCapitalString: String {
        
        var us = self.unicodeScalars
        us.replaceRange(Range(one: us.startIndex), with: String(us.first!).uppercaseString.unicodeScalars)
        return String(us)
    }
    
    func substringBefore(str: String) -> String {
        
        guard let index = rangeOfString(str)?.first  else { return self }
        
        return substringToIndex(index)
    }
    
}


typealias OId = ObjectIdentifier


extension ObjectIdentifier {
    
    func unsafePointer<T>() -> UnsafePointer<T> { return UnsafePointer<T>(bitPattern: uintValue) }
}


typealias DispatchQueue = dispatch_queue_t


extension dispatch_queue_t {
    
    func async(block: ()->Void) { dispatch_async(self, block) }
    
    func sync(block: ()->Void) { dispatch_sync(self, block) }
    
    func asyncBarrier(block: ()->Void) { dispatch_barrier_async(self, block) }
    
    func syncBarrier(block: ()->Void) { dispatch_barrier_sync(self, block) }
    
    func suspend() { dispatch_suspend(self) }
    
    func resume() { dispatch_resume(self) }
}


typealias UserInfo = [NSObject: AnyObject]
typealias NotificationSource = (name: String, object: AnyObject)



extension NSNotificationCenter {
    
    func addObserver(observer: AnyObject, selector aSelector: Selector, subject source: NotificationSource) {
        
        addObserver(observer, selector: aSelector, name: source.name, object: source.object)
    }
}


extension NSURL {
    
    class func temporaryFileURLWithExtension(ext: String) -> NSURL {
        
        return NSURL(fileURLWithPath: NSTemporaryDirectory())
            . URLByAppendingPathComponent(processInfo.globallyUniqueString)
            . URLByAppendingPathExtension(ext)
    }
}



// ==========================================================================================================
// MARK: UIKit Extensions
// ==========================================================================================================



extension UIApplication {
    
    
    var openSettingsURL: NSURL { return NSURL(string: UIApplicationOpenSettingsURLString)! }
}


extension UIInterfaceOrientation {
    
    var videoOrientation: AVCaptureVideoOrientation? {
        
        switch self {
        case .Unknown:               return nil
        case .Portrait:              return .Portrait
        case .PortraitUpsideDown:    return .PortraitUpsideDown
        case .LandscapeLeft:         return .LandscapeLeft
        case .LandscapeRight:        return .LandscapeRight
        }
    }
    
}


extension UIDeviceOrientation {
    
    var videoOrientation: AVCaptureVideoOrientation? {
        
        switch self {
        case .Unknown:               return nil
        case .Portrait:              return .Portrait
        case .PortraitUpsideDown:    return .PortraitUpsideDown
        case .LandscapeLeft:         return .LandscapeRight // WTF??!!
        case .LandscapeRight:        return .LandscapeLeft  // WTF??!!
        case .FaceUp:                return nil
        case .FaceDown:              return nil
        }
    }
    
    
    func isLandscape() -> Bool { return UIDeviceOrientationIsLandscape(self) }
    
    
    func isPortrait() -> Bool { return UIDeviceOrientationIsPortrait(self) }
}

extension UIViewController {
    
    
    func present(viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        
        presentViewController(viewControllerToPresent, animated: flag, completion: completion)
    }
}


extension UIView {
    
    
    func fadeIn(duration: NSTimeInterval = 0.25) {
        
        alpha = 0.0
        hidden = false
        self.dynamicType.animateWithDuration(duration) {
            self.alpha = 1.0
        }
    }
    
    
    func fadeOut(duration: NSTimeInterval = 0.25) {
        
        self.dynamicType.animateWithDuration (duration,
                                              animations: { self.alpha = 0.0 },
                                              completion: { _ in self.hidden = true })
    }
    
}

typealias AlertActionDescriptor = (title: String?, style: UIAlertActionStyle, handler: ((UIAlertAction) -> Void)?)


typealias AlertControllerDescriptor = (title: String?, message: String?, preferredStyle: UIAlertControllerStyle)


extension UIAlertController {
    
    
    func add(action: UIAlertAction) {
        addAction(action)
    }
}


extension UIAlertAction {
    
    
    convenience init(title: String? = nil, style: UIAlertActionStyle = .Default, handler: ((UIAlertAction) -> Void)? = nil) {
        self.init(title: title, style: style, handler: handler)
    }
}



// ==========================================================================================================
// MARK: AVFoundation Extensions
// ==========================================================================================================


enum AVMediaType: String {
    
    case Video          = "vide"
    case Audio          = "soun"
    case Text           = "text"
    case ClosedCaption  = "clcp"
    case Subtitle       = "sbtl"
    case Timecode       = "tmcd"
    case Metadata       = "meta"
    case Muxed          = "muxx"
    
}


enum AVMetadataObjectType: String {
    
    case Face                = "face"
    case UPCECode            = "org.gs1.UPC-E"
    case Code39Code          = "org.iso.Code39"
    case Code39Mod43Code     = "org.iso.Code39Mod43"
    case EAN13Code           = "org.gs1.EAN-13"
    case EAN8Code            = "org.gs1.EAN-8"
    case Code93Code          = "com.intermec.Code93"
    case Code128Code         = "org.iso.Code128"
    case PDF417Code          = "org.iso.PDF417"
    case QRCode              = "org.iso.QRCode"
    case AztecCode           = "org.iso.Aztec"
    case Interleaved2of5Code = "org.ansi.Interleaved2of5"
    case ITF14Code           = "org.gs1.ITF14"
    case DataMatrixCode      = "org.iso.DataMatrix"
}


extension AVCaptureOutput {
    
    func connectionWithMediaType(mediaType: AVMediaType) -> AVCaptureConnection {
        
        return connectionWithMediaType(mediaType.rawValue)
    }
}

extension AVCaptureDevice {
    
    
    static func defaultFor(mediaType: AVMediaType) -> AVCaptureDevice? {
        
        return AVCaptureDevice.defaultDeviceWithMediaType(mediaType.rawValue)
    }
    
    
    static func devicesWithMediaType(mediaType: AVMediaType) -> [AVCaptureDevice] {
        
        let type = mediaType.rawValue
        
        return (devicesWithMediaType(type) ?? Array<AVCaptureDevice>()) as! [AVCaptureDevice]
    }
    
    
    static func forMediaType(mediaType: AVMediaType,
                preferredPosition position: AVCaptureDevicePosition = .Unspecified) -> AVCaptureDevice?
    {
        let devices = devicesWithMediaType(AVMediaTypeVideo)
        
        for device in devices where device.position == position { return device as? AVCaptureDevice }
        
        return AVCaptureDevice.defaultFor(mediaType)
    }
    
    static func authorizationStatusForMediaType(mediaType: AVMediaType) -> AVAuthorizationStatus {
        
        return authorizationStatusForMediaType(mediaType.rawValue)
    }
    
    static func requestAccessForMediaType(mediaType: AVMediaType,
                completionHandler handler: (Bool)->Void) {
        
        requestAccessForMediaType(mediaType.rawValue, completionHandler: handler)
    }
}

