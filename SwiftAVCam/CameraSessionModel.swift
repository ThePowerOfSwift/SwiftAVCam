//
//  CameraSessionModel.swift
//  SwiftAVCam
//
//  Created by Hooman Mehr on 1/14/16.
//  Copyright © 2016 Hooman Mehr. All rights reserved.
//



import UIKit
import AVFoundation
import Photos



/// The model object that encapsulates camera functionality.

class CameraSessionModel: NSObject, ModelObject, AVCaptureFileOutputRecordingDelegate {

    
    private typealias Camera = CameraSessionModel
    
    
    typealias Result = ActionStatus

    
    
    // ======================================================================================================
    // MARK: Properties
    // ======================================================================================================

    
    
    /// Capture session used by this object
    
    let session: AVCaptureSession
    
    
    /// Capture output used for movie file recording
    
    let movieFileOutput: AVCaptureMovieFileOutput
    
    
    /// Capture output used for still images
    
    let stillImageOutput: AVCaptureStillImageOutput
    
    
    /// The number of cameras available for capture
    
    var cameraCount: Int { return AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count }
    
    
    // How to make the following connection properties work with KVO?
    // As long as movieFileOutput & stillImageOutput are 'let' assigned we are fine.
    
    
    /// Capture connection used for movie file recording
    
    var videoConnection: AVCaptureConnection { return movieFileOutput.connectionWithMediaType(.Video) }
    
    
    /// Capture connection used for still images
    
    var imageConnection: AVCaptureConnection { return stillImageOutput.connectionWithMediaType(.Video) }
    
    
    /// Currently active video capture device input
    
    dynamic var videoDeviceInput: AVCaptureDeviceInput
    
    
    /// Currently active camera device
    
    dynamic var inputDevice: AVCaptureDevice { return videoDeviceInput.device }
    
    
    /// Determines the orientation of the movie recorded when we `startRecording()`.
    
    dynamic var videoOrientation: AVCaptureVideoOrientation {
        
        get { return videoConnection.videoOrientation }
        set { videoConnection.videoOrientation = newValue } }
    
    
    /// Determines the orientation of the image taken by `snapStillImage()`
    
    dynamic var imageOrientation: AVCaptureVideoOrientation {
        
        get { return imageConnection.videoOrientation }
        set { imageConnection.videoOrientation = newValue } }

    
    /// Returns true while still image capture is in progress.
    
    dynamic var isRecording: Bool { return movieFileOutput.recording }
    
    
    /// Returns true while still image capture is in progress. 
    
    dynamic var isCapturingStillImage: Bool { return stillImageOutput.capturingStillImage }
    
    
    /// Returns if camera is currently running (turned on). 
    ///
    /// Camera function only work if the camera is running. To start camera running, use `startRunning()` method.
    
    dynamic var isRunning: Bool { return session.running }
    
    
    // ------------------
    // Private Properties
    // ------------------
    
    
    private var backgroundRecordingID = UIBackgroundTaskInvalid
    
    private static var keyPathsAffectingKey: [String: [String]] { return [
        
        "inputDevice":           ["videoDeviceInput.device"],
        "videoOrientation":      ["videoConnection.videoOrientation"],
        "imageOrientation":      ["imageConnection.videoOrientation"],
        "isRecording":           ["movieFileOutput.recording"],
        "isCapturingStillImage": ["stillImageOutput.capturingStillImage"],
        "isRunning":             ["session.running"] ] }
    
    private var sessionRunningKVOContext = 0
    
    private var capturingStillImageKVOContext = 0
    
    
    
    // ======================================================================================================
    // MARK: Methods
    // ======================================================================================================
    
    
    
    /// Starts recording movie into a file.
    
    func startMovieRecording(orientation: AVCaptureVideoOrientation) {
        
        guard isRunning && !isRecording else { return }

        if hostDevice.multitaskingSupported {
            
            // Setup background task. This is needed because the -[captureOutput:didFinishRecordingToOutputFileAtURL:fromConnections:error:]
            // callback is not received until AVCam returns to the foreground unless you request background execution time.
            // This also ensures that there will be time to write the file to the photo library when AVCam is backgrounded.
            // To conclude this background execution, -endBackgroundTask is called in
            // -[captureOutput:didFinishRecordingToOutputFileAtURL:fromConnections:error:] after the recorded file has been saved.
            backgroundRecordingID = app.beginBackgroundTaskWithExpirationHandler(nil)
        }
        
        // Update the orientation on the movie file output video connection before starting recording.
        videoOrientation = orientation
        
        // Turn OFF flash for video recording.
        _ = try? setFlashMode(.Off, forDevice: inputDevice)
        
        // Start recording to a temporary file.
        let outputFileURL = NSURL.temporaryFileURLWithExtension("mov")
        movieFileOutput.startRecordingToOutputFileURL(outputFileURL, recordingDelegate: self)
    }
    
    
    /// Stop the recording in progress, if any.
    
    func stopMovieRecording() {
        
        guard isRunning && isRecording else { return }
        
        movieFileOutput.stopRecording()
        
        // Reset flash mode to the default mode of Auto:
        _ = try? setFlashMode(.Auto, forDevice: inputDevice)

    }

    
    /// Snap a still image, even if a video recording is in progress.
    
    func snapStillImage(orientation: AVCaptureVideoOrientation) {
        
        guard isRunning else { return }
        
        // Update the orientation on the still image output video connection before capturing.
        imageOrientation = orientation
        
        // Flash set to Auto for Still Capture.
        _ = try? setFlashMode(.Auto, forDevice: inputDevice)
        
        // Capture a still image.
        stillImageOutput.captureStillImageAsynchronouslyFromConnection(imageConnection) { buffer, error in
            
            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
            
            // If we are authorized...
            PHPhotoLibrary.requestAuthorization { status in
                
                guard status == .Authorized else {return}
                
                // ...save the image file to the photo library.
                
                // To preserve the metadata, we create an asset from the JPEG NSData representation.
                // Note that creating an asset from a UIImage discards the metadata.
                
                if #available(iOS 9, *) {
                    
                    // In iOS 9, we can use -[PHAssetCreationRequest addResourceWithType:data:options].
                    
                    photoLibrary.performChanges ( {
                        
                        PHAssetCreationRequest.creationRequestForAsset()
                            . addResourceWithType(.Photo, data: imageData, options: nil)
                        
                        },
                        completionHandler:  { _, error in
                            if let error = error {
                                self.didEncounterErrorNotification(userInfo: self.errorInfo(error: error))
                            }
                    } )
                    
                } else {
                    
                    // In iOS 8, we save the image to a temporary file and use
                    // +[PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:].
                    
                    let imageFileURL = NSURL.temporaryFileURLWithExtension("jpg")
                    do {
                        try imageData.writeToURL(imageFileURL, options: .AtomicWrite) }
                    catch {
                        self.didEncounterErrorNotification(userInfo: self.errorInfo(error: error as NSError))
                        return
                    }
                    
                    photoLibrary.performChanges ( {
                        
                        PHAssetChangeRequest.creationRequestForAssetFromImageAtFileURL(imageFileURL)
                        },
                        completionHandler: { _, error in
                            if let error = error {
                                self.didEncounterErrorNotification(userInfo: self.errorInfo(error: error))
                            }
                    } )
                    
                } // #available
                
            } // requestAuthorization
            
        } // captureStillImageAsynchronouslyFromConnection
    }

    
    /// Switch to the other camera, if there is more than one camera on the device.
    
    func changeCamera() {
        
        guard isRunning else { return }
        
        let currentVideoDevice = inputDevice
        let currentPosition = currentVideoDevice.position
        
        var preferredPosition: AVCaptureDevicePosition
        
        switch currentPosition {
        case .Unspecified, .Front: preferredPosition = .Back
        case .Back: preferredPosition = .Front
        }
        
        guard
            let newVideoDevice = AVCaptureDevice.forMediaType(.Video, preferredPosition: preferredPosition)
            else { return }
        
        let newVideoDeviceInput = try! AVCaptureDeviceInput(device: newVideoDevice)

        session.beginConfiguration(); defer { session.commitConfiguration() }
        
        // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
        session.removeInput(videoDeviceInput)
        
        guard session.canAddInput(newVideoDeviceInput)
            else { session.addInput(videoDeviceInput); return }
        
        _ = try? setFlashMode(.Auto, forDevice: newVideoDevice)
        
        notificationCenter.removeObserver(self, name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: inputDevice)

        session.addInput(newVideoDeviceInput)
        videoDeviceInput = newVideoDeviceInput
        
        notificationCenter.addObserver(self, selector: "subjectAreaDidChange",
            name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: inputDevice)

        // Use auto video stabilization, if available.
        if  videoConnection.supportsVideoStabilization {
            
            videoConnection.preferredVideoStabilizationMode = .Auto
        }
    }
    
    
    /// Adjust camera focus and exposue modes; also set subject point and subject tracking mode.
    
    func adjustCamera(
        focusMode focusMode: AVCaptureFocusMode = .AutoFocus,
                  exposureMode: AVCaptureExposureMode = .AutoExpose,
                  subjectPoint   point: CGPoint,
                                 monitorSubjectChange: Bool = false) throws
    {
        try inputDevice.lockForConfiguration()
        defer { inputDevice.unlockForConfiguration() }
        
        // Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
        // set focusMode/exposureMode to apply the new point of interest.
        
        if inputDevice.focusPointOfInterestSupported &&
            inputDevice.isFocusModeSupported(focusMode)
        {
            inputDevice.focusPointOfInterest = point
            inputDevice.focusMode = focusMode
        }
        if inputDevice.exposurePointOfInterestSupported &&
            inputDevice.isExposureModeSupported(exposureMode)
        {
            inputDevice.exposurePointOfInterest = point
            inputDevice.exposureMode = exposureMode
        }
        inputDevice.subjectAreaChangeMonitoringEnabled = monitorSubjectChange
    }
    
    
    /// Set camera flash mode.
    
    func setFlashMode(flashMode: AVCaptureFlashMode, forDevice device: AVCaptureDevice) throws
    {
        if device.hasFlash && device.isFlashModeSupported(flashMode) {
            
            try device.lockForConfiguration()
            device.flashMode = flashMode
            device.unlockForConfiguration()
        }
    }
    
    
    /// Activate (turn on) the camera. The camera needs to be running, before any of the other functions work.
    
    func startRunning() {
        
        guard !isRunning else { return }
        
        addObservers()
        session.startRunning()       
    }
    
    
    /// Deactivates (turn off) the camera. None of the camera function work while it is not running.
    
    func stopRunning() {
            
        session.stopRunning()
        removeObservers()
    }
    
    
    
    // ======================================================================================================
    // MARK: Observers & Observables
    // ======================================================================================================
    
    
    
    /// Indicates our dependant keys for KVO auto-notifications.
    
    override class func keyPathsForValuesAffectingValueForKey(key: String) -> Set<String> {
        
        var keys = super.keyPathsForValuesAffectingValueForKey(key)
        
        if let affectingPaths = keyPathsAffectingKey[key] { keys.unionInPlace(affectingPaths) }
        
        return keys
    }
    
    
    /// Reposts the given notification, updating its origin to `self`.
    
    dynamic func repostNotification(notification: NSNotification) {
        
        notificationCenter.postNotificationName(notification.name, object: self, userInfo: notification.userInfo)
    }

    
    /// Adds `self` via the specified selector to the observers of the specified subject (notification name + source object pair).
    
    func observe(subject: NotificationSource, using selector: Selector) {
        
        notificationCenter.addObserver(self, selector: selector, subject: subject)
    }

    
    /// Installs KVO and notification observers
    
    func addObservers() {
    
        session.addObserver(self, forKeyPath: "isRunning", options: .New, context: &sessionRunningKVOContext)
        
        stillImageOutput.addObserver(self, forKeyPath: "capturingStillImage", options: .New, context: &capturingStillImageKVOContext)
    
        notificationCenter.addObserver(self, selector: "subjectAreaDidChange:",
                name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: inputDevice)
        
        observe(sessionRuntimeErrorNotification(object: session), using: "repostNotification:")
        
        observe(sessionWasInterruptedNotification(object: session), using: "repostNotification:")
        
        observe(sessionInterruptionEndedNotification(object: session), using: "repostNotification:")
    }
    
    
    /// Removes KVO and notification observers
    
    func removeObservers() {
        
        notificationCenter.removeObserver(self)
    }
    
    
    /// Handler for `AVCaptureDeviceSubjectAreaDidChangeNotification`.
    
    dynamic func subjectAreaDidChange(notification: NSNotification) {
        
        do { try adjustCamera(
            focusMode: .ContinuousAutoFocus,
            exposureMode: .ContinuousAutoExposure,
            subjectPoint: CGPoint(x: 0.5, y: 0.5),
            monitorSubjectChange: false)
        } catch { /*ignore*/ }
    }

    
    /// HAndler for KVO notifications
    
    override func observeValueForKeyPath(keyPath: String?,
                  ofObject object: AnyObject?,
                           change: [String : AnyObject]?,
                           context: UnsafeMutablePointer<Void>)
    {
        
        switch context {
            
        case &capturingStillImageKVOContext:
            
            guard let isCapturing = change?[NSKeyValueChangeNewKey]?.boolValue else { return }
            
            if isCapturing {
                
                didStartSnappingImageNotification()
                
            } else {
                
                didFinishSnappingImageNotification()
            }
            
        case &sessionRunningKVOContext:
            
            guard let isSessionRunning = change?[NSKeyValueChangeNewKey]?.boolValue else { return }
            
            if isSessionRunning {
                
                didStartRunningNotification()
                
            } else {
                
                didFinishRunningNotification()
            }
            
        default:
            
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    
    
    // ======================================================================================================
    // MARK: Posted Notifications
    // ======================================================================================================
    
    
    
    static let notificationNamePrefix = "CameraSessionModel"
    
    func sessionRuntimeErrorNotification        (userInfo info: UserInfo? = nil, object: AnyObject? = nil) -> NotificationSource
                                                { return post(notification: AVCaptureSessionRuntimeErrorNotification, userInfo: info, object: object) }
    
    func sessionWasInterruptedNotification      (userInfo info: UserInfo? = nil, object: AnyObject? = nil) -> NotificationSource
                                                { return post(notification: AVCaptureSessionWasInterruptedNotification, userInfo: info, object: object) }

    func sessionInterruptionEndedNotification   (userInfo info: UserInfo? = nil, object: AnyObject? = nil) -> NotificationSource
                                                { return post(notification: AVCaptureSessionInterruptionEndedNotification, userInfo: info, object: object) }
    
    func didStartRecordingMovieNotification  (userInfo info: UserInfo? = nil) -> NotificationSource { return post(userInfo: info) }
    
    func didFinishRecordingMovieNotification (userInfo info: UserInfo? = nil) -> NotificationSource { return post(userInfo: info) }
    
    func didFinishSavingMovieNotification    (userInfo info: UserInfo? = nil) -> NotificationSource { return post(userInfo: info) }
   
    func didStartSnappingImageNotification   (userInfo info: UserInfo? = nil) -> NotificationSource { return post(userInfo: info) }
    
    func didFinishSnappingImageNotification  (userInfo info: UserInfo? = nil) -> NotificationSource { return post(userInfo: info) }

    func didStartRunningNotification         (userInfo info: UserInfo? = nil) -> NotificationSource { return post(userInfo: info) }

    func didFinishRunningNotification        (userInfo info: UserInfo? = nil) -> NotificationSource { return post(userInfo: info) }
    
    func didEncounterErrorNotification       (userInfo info: UserInfo? = nil) -> NotificationSource { return post(userInfo: info) }

    
    
    // ======================================================================================================
    // MARK: AVCaptureFileOutputRecordingDelegate
    // ======================================================================================================
    
    
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        
        var info: UserInfo = [:]

        if let captureOutput = captureOutput { info["AVCaptureFileOutput"] = captureOutput }
        if let fileURL = captureOutput { info["OutputFileURL"] = fileURL }
        if let connections = connections as? [AVCaptureConnection] { info["AVCaptureConnectionsArray"] = connections }

        didStartRecordingMovieNotification(userInfo: info)
    }
    
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        
        var result: NSError? = error
        
        var info: UserInfo {
            
            var userInfo: UserInfo = [:]
            if let captureOutput = captureOutput { userInfo["AVCaptureFileOutput"] = captureOutput }
            if let fileURL = captureOutput { userInfo["OutputFileURL"] = fileURL }
            if let connections = connections as? [AVCaptureConnection] { userInfo["AVCaptureConnectionsArray"] = connections }
            if let result = result { userInfo["ResultError"] = result }
            return userInfo
        }
        
        didFinishRecordingMovieNotification(userInfo: info)
        
        let currentBackgroundRecordingID = backgroundRecordingID
        backgroundRecordingID = UIBackgroundTaskInvalid
        
        if currentBackgroundRecordingID != UIBackgroundTaskInvalid { app.endBackgroundTask(currentBackgroundRecordingID) }
        
        // Assuming that the recording successfully finished...
        
        guard result?.userInfo[AVErrorRecordingSuccessfullyFinishedKey]?.boolValue ?? true
            
            else { return }
        
        // ...lets deal with the actual recording:
        
        // If we are authorized...
        PHPhotoLibrary.requestAuthorization { status in
            
            guard status == .Authorized
                
                else {
                    // TODO: Set an error result
                    self.didFinishSavingMovieNotification(userInfo: info)
                    return
                }
            
            // ...save the movie file to the photo library.
            photoLibrary.performChanges ( {
                
                // In iOS 9 and later, it's possible to move the file into the photo library without duplicating the file data.
                // This avoids using double the disk space during save, which can make a difference on devices with limited free disk space.
                if #available(iOS 9, *) {
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = true
                    let changeRequest = PHAssetCreationRequest.creationRequestForAsset()
                    changeRequest.addResourceWithType(.Video, fileURL: fileURL, options: options)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(fileURL)
                }
                
            }, completionHandler: { _, error in
                
                if let error = error { result = error }
                
                // TODO: Set an error result
                self.didFinishSavingMovieNotification(userInfo: info)
            })
            
        }

    }
    
    

    // ======================================================================================================
    // MARK: Constructor
    // ======================================================================================================
    
    
    
    private typealias Input = AVCaptureDeviceInput
    private typealias MovieOutput = AVCaptureMovieFileOutput
    private typealias ImageOutput = AVCaptureStillImageOutput
    private typealias Device = AVCaptureDevice
    
    
    init(session: AVCaptureSession = AVCaptureSession()) throws {
        
        var videoDeviceInput: Input
        var movieFileOutput: MovieOutput
        var stillImageOutput: ImageOutput
        
        session.beginConfiguration()
        
        ////// VIDEO INPUT
        
        let videoDevice = Device.forMediaType(.Video, preferredPosition: .Back)
            
        do { videoDeviceInput = try Input(device: videoDevice) } catch { throw Result.Failed(error as NSError) }
        
        guard session.canAddInput(videoDeviceInput) else { throw Result.Failed(nil) }
        
        session.addInput(videoDeviceInput)
        
        ////// AUDIO INPUT
        
        let audioDevice = Device.defaultFor(.Audio)
        if let audioInput = try? Input.init(device: audioDevice)
           where session.canAddInput(audioInput)
        {
            session.addInput(audioInput)
        }
        
        ////// MOVIE OUTPUT
        
        movieFileOutput = MovieOutput()
        
        guard session.canAddOutput(movieFileOutput) else { throw Result.Failed(nil) }
        
        session.addOutput(movieFileOutput)
        
        // Use auto video stabilization, if available.
        let connection = movieFileOutput.connectionWithMediaType(.Video)
        if connection.supportsVideoStabilization { connection.preferredVideoStabilizationMode = .Auto }
        
        ////// STILL IMAGE OUTPUT
        
        stillImageOutput = ImageOutput()
        
        guard session.canAddOutput(stillImageOutput) else { throw Result.Failed(nil) }
        
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        
        session.addOutput(stillImageOutput)
        
        //////
        
        session.commitConfiguration()
        
        self.session = session
        self.videoDeviceInput = videoDeviceInput
        self.movieFileOutput = movieFileOutput
        self.stillImageOutput = stillImageOutput
        
        super.init()
    }
    
    
    
    // ======================================================================================================
    // MARK: De-Init
    // ======================================================================================================
    
    
    
    deinit {
        
        if isRunning { stopRunning() } // Don't use self.stopRunning(), because it is async
    }
    
}
