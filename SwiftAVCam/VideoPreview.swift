//
//  VideoPreview.swift
//  SwiftAVCam
//
//  Created by Hooman Mehr on 1/14/16.
//  Copyright © 2016 Hooman Mehr. All rights reserved.
//

import UIKit
import AVFoundation

class VideoPreview: UIView {
    
    override class func layerClass() -> AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override var layer: AVCaptureVideoPreviewLayer {
        
        return super.layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        
        get { return layer.session }
        
        set { layer.session = newValue }
            
    }
    
}
