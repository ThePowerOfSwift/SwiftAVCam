//
//  ViewController.swift
//  SwiftAVCam
//
//  Created by Hooman Mehr on 1/14/16.
//  Copyright © 2016 Hooman Mehr. All rights reserved.
//

import UIKit
import AVFoundation
import Photos



// ==========================================================================================================
// View Controller Class
// ==========================================================================================================



/// The UIViewController that controls `Main.storyboard`.

class ViewController: UIViewController {


    
    /// Helps shorten references to the model class.
    typealias Model = CameraSessionModel

    
    
    // ======================================================================================================
    // MARK: Properties
    // ======================================================================================================
    
    
    
    /// The Model object in MVC.
    var camera: Model?

    /// The current status of video media authorization.
    var videoAuthorizationStatus: AVAuthorizationStatus { return AVCaptureDevice.authorizationStatusForMediaType(.Video) }
    
    // The video orientation of `previewView`.
    var videoOrientation: AVCaptureVideoOrientation {
        get { return previewView.layer.connection.videoOrientation }
        set { previewView.layer.connection.videoOrientation = newValue }}
    
    lazy var cameraCount = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count
    
    private var setupResult = Model.Result.Pending
    private var sessionDidStartRunning = false
    private lazy var modelQueue = dispatch_queue_create( "CameraSessionModel serial queue", DISPATCH_QUEUE_SERIAL )

    
    
    // ======================================================================================================
    // MARK: IBOutlets
    // ======================================================================================================
    
    
    
    @IBOutlet var previewView: VideoPreview!
    @IBOutlet var cameraUnavailableLabel: UILabel!
    @IBOutlet var resumeButton: UIButton!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var cameraButton: UIButton!
    @IBOutlet var stillButton: UIButton!
    
    
    
    // ======================================================================================================
    // MARK: IBActions
    // ======================================================================================================
    
    
    @IBAction func resumeInterruptedSession(sender: NSObject) {
        
        guard let camera = camera else { return }
        
        modelQueue.async {
            
            camera.startRunning()
            self.sessionDidStartRunning = camera.isRunning
            
            guard camera.isRunning else { self.present(self.resumeFailedAlert, actions: self.okAction); return }
            
            uiQueue.async { self.recordButton.hidden = true }
        }
    }
    
    
    @IBAction func toggleMovieRecording(sender: NSObject) {
        
        guard let camera = camera else { return }
        
        // Disable the Camera button until recording finishes, and disable the Record button until recording starts or finishes. 
        // Buttons are enabled in observers of Model.didStartRecordingNotification & Model.didFinishRecordingNotification
        
        enableButtons(camera: false, record: false)
        
        modelQueue.async {
        
            if camera.isRecording {
                camera.stopMovieRecording()
            } else {
                camera.startMovieRecording(self.videoOrientation)
            }
        }
    }
    
    
    @IBAction func changeCamera(sender: NSObject) {
        
        enableButtons(false)
        
        modelQueue.async {
            
            self.camera?.changeCamera()
            
            uiQueue.async { self.enableButtons(true) }
        }
    }
    
    
    @IBAction func snapStillImage(sender: NSObject) {
        
        modelQueue.async { self.camera?.snapStillImage(self.videoOrientation) }
    }
    
    
    @IBAction func focusAndExposeTap(gestureRecognizer: UIGestureRecognizer) {
        
        let tappedPoint = gestureRecognizer.locationInView(gestureRecognizer.view)
        let devicePoint = previewView.layer.captureDevicePointOfInterestForPoint(tappedPoint)
        
        modelQueue.async { _ = try? self.camera?.adjustCamera(subjectPoint: devicePoint, monitorSubjectChange: true) }
    }
    
    
    
    // ======================================================================================================
    // MARK: Methods
    // ======================================================================================================
    
    
    
    /// Construct and present an alert using the provided alert and action descriptors.
    
    func present(alertDesc: AlertControllerDescriptor, actions alertActionDesc: AlertActionDescriptor...) {
        
        uiQueue.async {
            
            let alert   = UIAlertController(alertDesc)
            
            for actionDesc in alertActionDesc {
                
                let action = UIAlertAction(actionDesc)
                alert.add(action)
            }
            self.present(alert, animated: true)
        }
    }
    
    
    /// Registers a selector to observe the specified notification.
    
    func observe(subject: NotificationSource, using selector: Selector) {
        
        notificationCenter.addObserver(self, selector: selector, subject: subject)
    }
    
    
    /// Creates and sets up the model object asynchronously.
    
    func setupModel(completionHandler handler: ((ActionStatus)->Void)? = nil) { modelQueue.async {
        
        do { try self.camera = Model(session: self.previewView.session!)
            self.setupResult = .Success(self.camera)
            uiQueue.async {
                self.videoOrientation = app.statusBarOrientation.videoOrientation ?? .Portrait
            }
        } catch {
            self.setupResult = error as! ActionStatus
        }
        uiQueue.async { handler?(self.setupResult) }
        }}
    
    
    /// Used to enables/disable UI buttons. Enforces static rules.
    
    func enableButtons(all: Bool? = nil, camera: Bool? = nil, record: Bool? = nil, still: Bool? = nil) {
        
        let haveModel = self.camera != nil // Only enable if we have a camera to perform actions
        
        cameraButton.enabled = (camera ?? all ?? cameraButton.enabled) && haveModel && cameraCount > 1 // See Note
        recordButton.enabled = (record ?? all ?? recordButton.enabled) && haveModel
        stillButton.enabled  = (still  ?? all ?? stillButton.enabled)  && haveModel
        
        // Note: Only enable the ability to change camera if the device has more than one camera.
    }
   
    
    
    // ======================================================================================================
    // MARK: View Lifecycle
    // ======================================================================================================
    
    
    
    /// Called after the controller's view is loaded into memory.
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Disable UI. The UI is enabled if and only if the session starts running.
        
        enableButtons(false)
        
        // Asynchronously create the the camera (our model object):
        // The model instantiation is slow, the model only supports async instantiation to avoid UI lockup.
        
        previewView.session = AVCaptureSession()
        
        switch videoAuthorizationStatus {
            
        case .Authorized: break
            
        case .NotDetermined:
            
            // The user has not yet been presented with the option to grant video access.
            // We suspend the camera model serial queue to delay model setup until the access request
            // has completed to avoid asking the user for audio access if video access is denied.
            // Note that audio access will be implicitly requested when we create an
            // AVCaptureDeviceInput for audio during model construction.
            
            modelQueue.suspend()
            AVCaptureDevice.requestAccessForMediaType(.Video) { granted in
                
                if !granted { self.setupResult = .Denied(nil) }
                
                // Resume model construction once access is determined:
                self.modelQueue.resume()
            }
            
        default:
            
            // Camera access is restricted or the user has previously denied access.
            setupResult = .Denied(nil)
        }

        if setupResult == .Denied(nil) { return }
        
        setupModel()
    }
    
    
    /// Notifies the view controller that its view is about to be added to a view hierarchy.
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        modelQueue.async {
            
            switch self.setupResult {
                
            case .Success(_): break
                
            case .Pending:
                
                // This happens if we did not have camera permission but user clicked "Open Settings" button, so we may have it now.
                if self.videoAuthorizationStatus == .Authorized {
                    
                    self.setupModel { result in
                        
                        if case .Failed(_) = result { self.present(self.setupFailedAlert, actions: self.okAction) }
                    }
                    
                } else {
                    
                    self.setupResult = .Denied(nil)
                    fallthrough
                }
                
            case .Denied(_): self.present(self.cameraAuthorizationAlert, actions: self.okAction, self.settingsAction)
                
            case .Failed(_):
                
                self.present(self.setupFailedAlert, actions: self.okAction)
                // We keep resetting setupResult to Pending, hoping we may have permission the next time.
                self.setupResult = .Pending

                
            default: fatalError("Unexpected setupResult")
                
            }
            
            guard let camera = self.camera else { return }
            
            self.startObservingModel()
            camera.startRunning()
            self.sessionDidStartRunning = camera.isRunning
        }
        
    }
    
    
    /// Notifies the view controller that its view was removed from a view hierarchy.
    
    override func viewDidDisappear(animated: Bool) {
        
        defer { super.viewDidDisappear(animated) }
        
        modelQueue.async {
            
            self.camera?.stopRunning()
            self.sessionDidStartRunning = self.camera?.isRunning ?? false
            self.stopObservingModel()
        }
    }

    
    
    // ======================================================================================================
    // MARK: Orientation Handling
    // ======================================================================================================

    
    
    /// Disable autorotation of the interface when recording is in progress.
    
    override func shouldAutorotate() -> Bool {
        
        // Disable autorotation of the interface when recording is in progress.
        return !(camera?.isRecording ?? false)

    }
    
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        
        return UIInterfaceOrientationMask.All
    }
    
    
    override func viewWillTransitionToSize  (size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        // Note that the app delegate controls the device orientation notifications required to use the device orientation.
        
        if hostDevice.orientation.isPortrait() ||  hostDevice.orientation.isLandscape() {
            
            let orientation = hostDevice.orientation.videoOrientation!
            
            self.videoOrientation = orientation
        }
    }
    

    
    // ======================================================================================================
    // MARK: Monitoring the camera model with KVO and Notifications
    // ======================================================================================================

    
    
    // KVO Observation Contexts
    // -----------------------------------------------------------------
    
    private var sessionRunningKVOContext = 0
    private var capturingStillImageKVOContext = 0
    
    
    // Add/Remove Observers
    // -----------------------------------------------------------------
   
    
    /// Starts observing the camera model object.
    
    func startObservingModel() {
        
        guard let camera = camera else { return }
        
        camera.addObserver(self, forKeyPath: "isRunning", options: .New, context: &sessionRunningKVOContext)
        
        camera.addObserver(self, forKeyPath: "isCapturingStillImage", options: .New, context: &capturingStillImageKVOContext)
        

        notificationCenter.addObserver(self, selector: "sessionRuntimeError:",
                                    name: AVCaptureSessionRuntimeErrorNotification, object: camera)
        
        notificationCenter.addObserver(self, selector: "sessionWasInterrupted:",
                                         name: AVCaptureSessionWasInterruptedNotification, object: camera)
        
        notificationCenter.addObserver(self, selector: "sessionInterruptionEnded:",
                                         name: AVCaptureSessionInterruptionEndedNotification, object: camera)
        
        observe(camera.didStartRecordingMovieNotification(), using: "didStartRecordingMovie:")
        
        observe(camera.didFinishRecordingMovieNotification(), using: "didFinishRecordingMovie:")
        
        observe(camera.didFinishSavingMovieNotification(), using: "didFinishSavingMovie:")
  
    }

    
    /// Stops observing the camera model object.

    func stopObservingModel() {
        
        camera?.removeObserver(self, forKeyPath: "running", context: &sessionRunningKVOContext)
        
        camera?.removeObserver(self, forKeyPath: "capturingStillImage", context: &capturingStillImageKVOContext)
        
        notificationCenter.removeObserver(self)
    }

    
    // Observer Methods:
    // -----------------------------------------------------------------
    
    
    /// KVO notifications handler; provides UI feedback for image capture, and adjusts UI buttons according to camera session status.
    
    override func observeValueForKeyPath(keyPath: String?,
                                 ofObject object: AnyObject?,
                                          change: [String : AnyObject]?,
                                         context: UnsafeMutablePointer<Void>)
    {
        
        switch context {
            
        case &capturingStillImageKVOContext:
            
            guard let isCapturing = change?[NSKeyValueChangeNewKey]?.boolValue where isCapturing else { return }
            
            // Provide visual feedback for capturing image:
            
            uiQueue.async {
                
                self.previewView.layer.opacity = 0.0
                UIView.animateWithDuration(0.25) { self.previewView.layer.opacity = 1.0 }
            }
            
        case &sessionRunningKVOContext:
            
            guard let isSessionRunning = change?[NSKeyValueChangeNewKey]?.boolValue else { return }
            
            uiQueue.async {
                self.enableButtons(isSessionRunning)
            }
            
        default:
            
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    
    /// Handler for Model.sessionRuntimeErrorNotification() to provide UI feedback about errors in camera session.
    
    dynamic func sessionRuntimeError(notification: NSNotification) {

        guard let error = notification.error else { return }
        
        // Automatically try to restart the session running if media services were reset and the last start running succeeded.
        // Otherwise, enable the user to try to resume the session running.
        
        if error.code == AVError.MediaServicesWereReset.rawValue {
            
            modelQueue.async {
                
                if self.sessionDidStartRunning {
                    
                    self.camera?.startRunning()
                    self.sessionDidStartRunning = self.camera?.isRunning ?? false
                    
                } else {
                    
                    uiQueue.async { self.resumeButton.hidden = false }
                }
            }
            
        } else {
            
            uiQueue.async { self.resumeButton.hidden = false }
        }
        
    }

    
    /// Handler for Model.sessionWasInterruptedNotification() to provide UI response when a session interruption starts.
    
    dynamic func sessionWasInterrupted(notification: NSNotification) {
        
        // In some scenarios we want to enable the user to resume the session running.
        // For example, if music playback is initiated via control center while using AVCam,
        // then the user can let AVCam resume the session running, which will stop music playback.
        // Note that stopping music playback in control center will not automatically resume the session running.
        // Also note that it is not always possible to resume, see -[resumeInterruptedSession:].

        var showResumeButton = false
        
        if #available(iOS 9, *) {
            
            if let reason = notification.reason {
                
                switch reason {
                    
                case .AudioDeviceInUseByAnotherClient, .VideoDeviceInUseByAnotherClient:
                    
                    showResumeButton = true
                    
                case .VideoDeviceNotAvailableWithMultipleForegroundApps:
                    
                    cameraUnavailableLabel.fadeIn()
                    
                default: break
                }
            }
            
        } else { // Pre-iOS 9
            
            showResumeButton = app.applicationState == .Inactive
        }
        
        if showResumeButton { resumeButton.fadeIn() }
    }

    
    /// Handler for Model.sessionInterruptionEndedNotification() to provide UI response when a session interruption ends.
    
    dynamic func sessionInterruptionEnded(notification: NSNotification) {
    
        if !resumeButton.hidden { resumeButton.fadeOut() }
        
        if !cameraUnavailableLabel.hidden { cameraUnavailableLabel.fadeOut() }
    }

    
    /// Handler for Model.didStartRecordingMovieNotification() to provide UI response to start of recording movie on camera.
    
    dynamic func didStartRecordingMovie(notification: NSNotification) {
        
        // Change label and enable the record button to let the user stop the recording.
        self.enableButtons(record: true)
        self.recordButton.setTitle (NSLocalizedString( "Stop", comment: "Recording button stop title"), forState: .Normal)
    }
    
    
    /// Handler for Model.didFinishRecordingMovieNotification() to provide UI response to end of recording movie on camera.

    dynamic func didFinishRecordingMovie(notification: NSNotification) {

        self.enableButtons(true)
        self.recordButton.setTitle (NSLocalizedString( "Record", comment: "Recording button record title"), forState: .Normal)
    }
    
    
    /// Handler for Model.didFinishSavingMovieNotification() to provide UI feedback about errors while saving movie to Photo Library.
    
    dynamic func didFinishSavingMovie(notification: NSNotification) {
        
        //FIXME: Check for photo library permission denial and present an alert.
        //FIXME: Check storage full error and provide feedback.
    }

    
    
    // ==========================================================================================================
    // MARK: Alert Descriptors
    // ==========================================================================================================
    
    
    /// Parameter values to display camera authorization alert.
    
    private var cameraAuthorizationAlert: AlertControllerDescriptor {
        
        return ( title: "AVCam",
                 message: NSLocalizedString ("AVCam doesn't have permission to use the camera, please change privacy settings",
                    comment: "Alert message when the user has denied access to the camera"),
                 preferredStyle: .Alert)
    }
    
    
    /// Parameter values to display setup failed alert.
    
    private var setupFailedAlert: AlertControllerDescriptor {
        
        return ( title: "AVCam",
                 message: NSLocalizedString ("Unable to capture media",
                    comment: "Alert message when something goes wrong during capture session configuration"),
                 preferredStyle: .Alert)
    }
    
    
    /// Parameter values to display resume failed alert.
    
    private var resumeFailedAlert: AlertControllerDescriptor {
        
        return ( title: "AVCam",
                 message: NSLocalizedString ("Unable to resume",
                    comment: "Alert message when unable to resume the session running"),
                 preferredStyle: .Alert)
    }
    
    
    /// Parameter values that define a cancelling "OK" action for an alert.
    
    private var okAction: AlertActionDescriptor {
        
        return (title: NSLocalizedString("OK", comment: "Alet OK Button"), style: .Cancel, handler: nil)
    }
    
    
    /// Parameter values that define a "Settings" action that opens Settings app.
    
    private var settingsAction: AlertActionDescriptor {
        
        return (title: NSLocalizedString("Settings", comment: "Alet Button to open iOS 'Settings' App"), style: .Default,
                handler: { _ in
                    _ = app.openURL(app.openSettingsURL)
                })
    }
}



// ==========================================================================================================
// MARK: Utility Extensions
// ==========================================================================================================



extension NSNotification {
    
    
    var error: NSError? { return userInfo?[AVCaptureSessionErrorKey] as? NSError }
    
    
    @available(iOS 9, *)
    var reason: AVCaptureSessionInterruptionReason? {
        
        guard let value = userInfo?[AVCaptureSessionInterruptionReasonKey]?.integerValue else { return nil }
        return AVCaptureSessionInterruptionReason(rawValue: value) }
}
