//
//  CameraManagerView.swift
//  cameraMultiplePhotos
//
//  Created by Narendra jain  on 30/07/24.


import Foundation
import AVFoundation
import CoreImage
import UIKit

public enum CameraState {
    case ready, accessDenied, noDeviceFound, notDetermined
}

public enum CameraDevice {
    case front, back
}

public enum CameraFlashMode: Int {
    case off, on, auto
}

public enum CameraOutputMode {
    case stillImage, videoWithMic, videoOnly
}

public enum ImageQualityType{
    case high, medium, low
}

public enum CaptureError: Error {
    case noImageData
    case invalidImageData
    case noVideoConnection
    case noSampleBuffer
    case assetNotSaved
}
class CameraManagerView: UIView,UIGestureRecognizerDelegate {
    
    weak var delegate: CameraManagerViewDelegate?
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        //initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        //initialize()
    }
    
    var isVideoEnabled = false
    var isPhotoEnabled = true
    
    fileprivate var initialzoom = CGFloat(1.0)
    fileprivate var maxzoom = CGFloat(1.0)
    
    fileprivate var videoError: ((_ videoURL: URL?, _ error: NSError?) -> Void)?
    
    
    func setup() {
        
        // configactions
        var newCameraOutputMode = CameraOutputMode.stillImage
        if !self.isPhotoEnabled
        {
            newCameraOutputMode = CameraOutputMode.videoWithMic
        }
        let _ = self.addPreviewLayerToView(newCameraOutputMode: newCameraOutputMode)
        
        
        
    }
    fileprivate func _showCameraLoadError(_ title: String, message: String) {
        DispatchQueue.main.async { () -> Void in
            if let validCompletion = self.videoError {
                validCompletion(nil, nil)
                self.videoError = nil
            }
        }
    }
    fileprivate var sessionQueue: DispatchQueue = DispatchQueue(label: "CameraSessionQueue", attributes: [])
    fileprivate var cameraIsSetup = false
    
    
    var recordedDuration: CMTime { return movieOutput?.recordedDuration ?? .zero }
    var recordedFileSize: Int64 { return movieOutput?.recordedFileSize ?? 0 }
    
    
    
    
    // Setup Camera
    fileprivate func _setupCamera(_ completion: @escaping () -> Void) {
        captureSession = AVCaptureSession()
        
        sessionQueue.async {
            if let validCaptureSession = self.captureSession {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = AVCaptureSession.Preset.high
                
                self._updateCameraDevice(self.cameraDevice)
                self._setupOutputs()
                self._setupOutputMode(self.cameraOutputMode, oldCameraOutputMode: nil)
                self._setupPreviewLayer()
                
                
                validCaptureSession.commitConfiguration()
                self._updateIlluminationMode(self.flashMode)
                self._updateCameraQualityMode(self.cameraOutputQuality)
                
                
                validCaptureSession.startRunning()
                self.cameraIsSetup = true
                
                completion()
            }
        }
    }
    
    
    // Camera Property
    var captureSession: AVCaptureSession?
    var showAccessPermissionPopupAutomatically = false
    var shouldFlipFrontCameraImage = false
    var animateCameraDeviceChange: Bool = true
    var animateShutter: Bool = true
    
    
    var cameraIsReady: Bool {
        return cameraIsSetup
    }
    fileprivate lazy var frontCameraDevice: AVCaptureDevice? = {
        AVCaptureDevice.videoDevices.filter { $0.position == .front }.first
    }()
    
    fileprivate lazy var backCameraDevice: AVCaptureDevice? = {
        AVCaptureDevice.videoDevices.filter { $0.position == .back }.first
    }()
    
    var hasFrontCamera: Bool = {
        let frontDevices = AVCaptureDevice.videoDevices.filter { $0.position == .front }
        return !frontDevices.isEmpty
    }()
    
    var hasFlash: Bool = {
        let hasFlashDevices = AVCaptureDevice.videoDevices.filter { $0.hasFlash }
        return !hasFlashDevices.isEmpty
    }()
    
    // Property to change camera device between front and back.
    var cameraDevice: CameraDevice = .back {
        didSet {
            if cameraIsSetup, cameraDevice != oldValue {
                if animateCameraDeviceChange {
                    _doFlipAnimation()
                }
                _updateCameraDevice(cameraDevice)
                _updateIlluminationMode(flashMode)
                _setupMaxZoomScale()
                _zoom(0)
                
            }
        }
    }
    // Property to change camera flash mode.
    var flashMode: CameraFlashMode = .off {
        didSet {
            if cameraIsSetup && flashMode != oldValue {
                _updateIlluminationMode(flashMode)
            }
        }
    }
    // Property to change camera output.
    var cameraOutputMode: CameraOutputMode = .stillImage {
        didSet {
            if cameraIsSetup {
                if cameraOutputMode != oldValue {
                    _setupOutputMode(cameraOutputMode, oldCameraOutputMode: oldValue)
                }
                _setupMaxZoomScale()
                _zoom(0)
            }
        }
    }
    func currentCameraStatus() -> CameraState {
        return _checkIfCameraIsAvailable()
    }
    // Property to change camera output quality.
    open var cameraOutputQuality: AVCaptureSession.Preset = .high {
        didSet {
            if cameraIsSetup && cameraOutputQuality != oldValue {
                _updateCameraQualityMode(cameraOutputQuality)
            }
        }
    }
    
    //    func changeFlashMode() -> CameraFlashMode {
    //        guard let newFlashMode = CameraFlashMode(rawValue: (flashMode.rawValue + 1) % 3) else { return flashMode }
    //        flashMode = newFlashMode
    //        return flashMode
    //    }
    func changeFlashMode(newFlashMode:CameraFlashMode)  {
        flashMode = newFlashMode
    }
    func hasFlash(for cameraDevice: CameraDevice) -> Bool {
        let devices = AVCaptureDevice.videoDevices
        for device in devices {
            if device.position == .back, cameraDevice == .back {
                return device.hasFlash
            } else if device.position == .front, cameraDevice == .front {
                return device.hasFlash
            }
        }
        return false
    }
    func canSetPreset(preset: AVCaptureSession.Preset) -> Bool? {
        if let validCaptureSession = captureSession {
            return validCaptureSession.canSetSessionPreset(preset)
        }
        return nil
    }
    
    var videoStabilisationMode: AVCaptureVideoStabilizationMode = .auto {
        didSet {
            if oldValue != videoStabilisationMode {
                _setupVideoConnection()
            }
        }
    }
    
    // Property to get the stabilization mode currently active
    var activeVideoStabilisationMode: AVCaptureVideoStabilizationMode {
        if let movieOutput = movieOutput {
            for connection in movieOutput.connections {
                for port in connection.inputPorts {
                    if port.mediaType == AVMediaType.video {
                        let videoConnection = connection as AVCaptureConnection
                        return videoConnection.activeVideoStabilizationMode
                    }
                }
            }
        }
        
        return .off
    }
    fileprivate func _canLoadCamera() -> Bool {
        let currentCameraState = _checkIfCameraIsAvailable()
        return currentCameraState == .ready || (currentCameraState == .notDetermined && showAccessPermissionPopupAutomatically)
    }
    
    fileprivate func _checkIfCameraIsAvailable() -> CameraState {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.front)
        if deviceHasCamera {
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            let userAgreedToUseIt = authorizationStatus == .authorized
            if userAgreedToUseIt {
                return .ready
            } else if authorizationStatus == AVAuthorizationStatus.notDetermined {
                return .notDetermined
            } else {
                self._showCameraLoadError("Camera access denied", message: "You need to go to settings app and grant acces to the camera device to use it.")
                return .accessDenied
            }
        } else {
            self._showCameraLoadError("Camera unavailable", message: "The device does not have a camera.")
            return .noDeviceFound
        }
    }
    
    // Update Camera Property
    
    fileprivate func _updateCameraDevice(_: CameraDevice) {
        if let validCaptureSession = captureSession {
            validCaptureSession.beginConfiguration()
            defer { validCaptureSession.commitConfiguration() }
            let inputs: [AVCaptureInput] = validCaptureSession.inputs
            
            for input in inputs {
                if let deviceInput = input as? AVCaptureDeviceInput, deviceInput.device != mic {
                    validCaptureSession.removeInput(deviceInput)
                }
            }
            
            switch cameraDevice {
            case .front:
                if hasFrontCamera {
                    if let validFrontDevice = _deviceInputFromDevice(frontCameraDevice),
                       !inputs.contains(validFrontDevice) {
                        validCaptureSession.addInput(validFrontDevice)
                    }
                }
            case .back:
                if let validBackDevice = _deviceInputFromDevice(backCameraDevice),
                   !inputs.contains(validBackDevice) {
                    validCaptureSession.addInput(validBackDevice)
                }
            }
        }
    }
    
    fileprivate func _updateIlluminationMode(_ mode: CameraFlashMode) {
        if cameraOutputMode != .stillImage {
            _updateTorch(mode)
        }
    }
    
    fileprivate func _updateTorch(_: CameraFlashMode) {
        captureSession?.beginConfiguration()
        defer { captureSession?.commitConfiguration() }
        for captureDevice in AVCaptureDevice.videoDevices {
            guard let avTorchMode = AVCaptureDevice.TorchMode(rawValue: flashMode.rawValue) else { continue }
            if captureDevice.isTorchModeSupported(avTorchMode), cameraDevice == .back {
                do {
                    try captureDevice.lockForConfiguration()
                    
                    captureDevice.torchMode = avTorchMode
                    captureDevice.unlockForConfiguration()
                    
                } catch {
                    return
                }
            }
        }
    }
    private var photoflashMode: AVCaptureDevice.FlashMode = .auto
    
    fileprivate func _updateFlash(_ flashMode: CameraFlashMode) {
        if flashMode == .auto
        {
            photoflashMode = .auto
        }
        else if flashMode == .on
        {
            photoflashMode = .on
        }
        else
        {
            photoflashMode = .off
        }
    }
    fileprivate func _updateCameraQualityMode(_ newCameraOutputQuality: AVCaptureSession.Preset) {
        if let validCaptureSession = captureSession {
            var sessionPreset = newCameraOutputQuality
            if newCameraOutputQuality == .high {
                if cameraOutputMode == .stillImage {
                    sessionPreset = AVCaptureSession.Preset.photo
                } else {
                    sessionPreset = AVCaptureSession.Preset.high
                }
            }
            
            if validCaptureSession.canSetSessionPreset(sessionPreset) {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = sessionPreset
                validCaptureSession.commitConfiguration()
            } else {
                self._showCameraLoadError("Preset not supported", message: "Camera preset not supported. Please try another one.")
                
            }
        } else {
            self._showCameraLoadError("Camera error", message: "No valid capture session found, I can't take any pictures or videos.")
        }
    }
    fileprivate lazy var mic: AVCaptureDevice? = {
        AVCaptureDevice.default(for: AVMediaType.audio)
    }()
    
    // Preview Layer
    
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer?
    
    fileprivate func _addPreviewLayerToView() {
        attachZoom()
        attachFocus()
        attachExposure()
        
        DispatchQueue.main.async { () -> Void in
            guard let previewLayer = self.previewLayer else { return }
            previewLayer.frame = self.layer.bounds
            self.clipsToBounds = true
            self.layer.addSublayer(previewLayer)
        }
    }
    
    func addPreviewLayerToView() -> CameraState {
        return addPreviewLayerToView( newCameraOutputMode: cameraOutputMode)
    }
    
    func addPreviewLayerToView( newCameraOutputMode: CameraOutputMode) -> CameraState {
        return addLayerPreviewToView( newCameraOutputMode: newCameraOutputMode, completion: nil)
    }
    
    func addLayerPreviewToView( newCameraOutputMode: CameraOutputMode, completion: (() -> Void)?) -> CameraState {
        if _canLoadCamera() {
            if let validPreviewLayer = previewLayer {
                validPreviewLayer.removeFromSuperlayer()
            }
            if cameraIsSetup {
                _addPreviewLayerToView()
                cameraOutputMode = newCameraOutputMode
                if let validCompletion = completion {
                    validCompletion()
                }
            } else {
                _setupCamera {
                    self._addPreviewLayerToView()
                    self.cameraOutputMode = newCameraOutputMode
                    if let validCompletion = completion {
                        validCompletion()
                    }
                }
            }
        }
        return _checkIfCameraIsAvailable()
    }
    fileprivate func _setupPreviewLayer() {
        if let validCaptureSession = captureSession {
            previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
    }
    
    
    // Zoom Property
    
    fileprivate var zoomScale = CGFloat(1.0)
    fileprivate var beginZoomScale = CGFloat(1.0)
    fileprivate var maxZoomScale = CGFloat(1.0)
    
    fileprivate lazy var zoomGesture = UIPinchGestureRecognizer()
    
    fileprivate func attachZoom() {
        DispatchQueue.main.async {
            self.zoomGesture.addTarget(self, action: #selector(self._zoomStart(_:)))
            self.addGestureRecognizer(self.zoomGesture)
            self.zoomGesture.delegate = self
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            beginZoomScale = zoomScale
        }
        
        return true
    }
    
    func zoom(_ scale: CGFloat) {
        _zoom(scale)
    }
    
    var shouldEnablePinchToZoom = true {
        didSet {
            zoomGesture.isEnabled = shouldEnablePinchToZoom
        }
    }
    
    @objc fileprivate func _zoomStart(_ recognizer: UIPinchGestureRecognizer) {
        guard
            let previewLayer = previewLayer
        else { return }
        
        var allTouchesOnPreviewLayer = true
        let numTouch = recognizer.numberOfTouches
        
        for i in 0 ..< numTouch {
            let location = recognizer.location(ofTouch: i, in: self)
            let convertedTouch = previewLayer.convert(location, from: previewLayer.superlayer)
            if !previewLayer.contains(convertedTouch) {
                allTouchesOnPreviewLayer = false
                break
            }
        }
        if allTouchesOnPreviewLayer {
            _zoom(recognizer.scale)
        }
    }
    fileprivate func _setupMaxZoomScale() {
        var maxZoom = CGFloat(1.0)
        beginZoomScale = CGFloat(1.0)
        
        if cameraDevice == .back, let backCameraDevice = backCameraDevice {
            maxZoom = backCameraDevice.activeFormat.videoMaxZoomFactor
        } else if cameraDevice == .front, let frontCameraDevice = frontCameraDevice {
            maxZoom = frontCameraDevice.activeFormat.videoMaxZoomFactor
        }
        if maxZoom >= self.initialzoom
        {
            beginZoomScale = self.initialzoom
        }
        maxZoomScale = maxZoom
        
        if maxZoom >= self.maxzoom
        {
            maxZoomScale = self.maxzoom
            
        }
    }
    fileprivate func _zoom(_ scale: CGFloat) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = backCameraDevice
        case .front:
            device = frontCameraDevice
        }
        
        do {
            let captureDevice = device
            try captureDevice?.lockForConfiguration()
            
            zoomScale = max(1.0, min(beginZoomScale * scale, maxZoomScale))
            
            captureDevice?.videoZoomFactor = zoomScale
            
            captureDevice?.unlockForConfiguration()
            
        } catch {
            print("Error locking configuration")
        }
    }
    
    // Focus Property
    
    fileprivate var lastFocusRectangle: CAShapeLayer?
    fileprivate var lastFocusPoint: CGPoint?
    fileprivate lazy var focusGesture = UITapGestureRecognizer()
    var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    
    fileprivate func attachFocus() {
        DispatchQueue.main.async {
            self.focusGesture.addTarget(self, action: #selector(self._focusStart(_:)))
            self.addGestureRecognizer(self.focusGesture)
            self.focusGesture.delegate = self
        }
    }
    
    var shouldEnableTapToFocus = true {
        didSet {
            focusGesture.isEnabled = shouldEnableTapToFocus
        }
    }
    
    @objc fileprivate func _focusStart(_ recognizer: UITapGestureRecognizer) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = backCameraDevice
        case .front:
            device = frontCameraDevice
        }
        
        _changeExposureMode(mode: .continuousAutoExposure)
        translationY = 0
        exposureValue = 0.5
        
        if let validDevice = device,
           let validPreviewLayer = previewLayer,
           let view = recognizer.view {
            let pointInPreviewLayer = view.layer.convert(recognizer.location(in: view), to: validPreviewLayer)
            let pointOfInterest = validPreviewLayer.captureDevicePointConverted(fromLayerPoint: pointInPreviewLayer)
            
            do {
                try validDevice.lockForConfiguration()
                
                _showFocusRectangleAtPoint(pointInPreviewLayer, inLayer: validPreviewLayer)
                
                if validDevice.isFocusPointOfInterestSupported {
                    validDevice.focusPointOfInterest = pointOfInterest
                }
                
                if validDevice.isExposurePointOfInterestSupported {
                    validDevice.exposurePointOfInterest = pointOfInterest
                }
                
                if validDevice.isFocusModeSupported(focusMode) {
                    validDevice.focusMode = focusMode
                }
                
                if validDevice.isExposureModeSupported(exposureMode) {
                    validDevice.exposureMode = exposureMode
                }
                
                validDevice.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
    
    
    fileprivate func _showFocusRectangleAtPoint(_ focusPoint: CGPoint, inLayer layer: CALayer, withBrightness brightness: Float? = nil) {
        if let lastFocusRectangle = lastFocusRectangle {
            lastFocusRectangle.removeFromSuperlayer()
            self.lastFocusRectangle = nil
        }
        
        let size = CGSize(width: 75, height: 75)
        let rect = CGRect(origin: CGPoint(x: focusPoint.x - size.width / 2.0, y: focusPoint.y - size.height / 2.0), size: size)
        
        let endPath = UIBezierPath(rect: rect)
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY + 5.0))
        endPath.move(to: CGPoint(x: rect.maxX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.maxX - 5.0, y: rect.minY + size.height / 2.0))
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY - 5.0))
        endPath.move(to: CGPoint(x: rect.minX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.minX + 5.0, y: rect.minY + size.height / 2.0))
        if brightness != nil {
            endPath.move(to: CGPoint(x: rect.minX + size.width + size.width / 4, y: rect.minY))
            endPath.addLine(to: CGPoint(x: rect.minX + size.width + size.width / 4, y: rect.minY + size.height))
            
            endPath.move(to: CGPoint(x: rect.minX + size.width + size.width / 4 - size.width / 16, y: rect.minY + size.height - CGFloat(brightness!) * size.height))
            endPath.addLine(to: CGPoint(x: rect.minX + size.width + size.width / 4 + size.width / 16, y: rect.minY + size.height - CGFloat(brightness!) * size.height))
        }
        
        let startPath = UIBezierPath(cgPath: endPath.cgPath)
        let scaleAroundCenterTransform = CGAffineTransform(translationX: -focusPoint.x, y: -focusPoint.y).concatenating(CGAffineTransform(scaleX: 2.0, y: 2.0).concatenating(CGAffineTransform(translationX: focusPoint.x, y: focusPoint.y)))
        startPath.apply(scaleAroundCenterTransform)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = endPath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor(red: 1, green: 0.83, blue: 0, alpha: 0.95).cgColor
        shapeLayer.lineWidth = 1.0
        
        layer.addSublayer(shapeLayer)
        lastFocusRectangle = shapeLayer
        lastFocusPoint = focusPoint
        
        CATransaction.begin()
        
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        CATransaction.setCompletionBlock {
            if shapeLayer.superlayer != nil {
                shapeLayer.removeFromSuperlayer()
                self.lastFocusRectangle = nil
            }
        }
        if brightness == nil {
            let appearPathAnimation = CABasicAnimation(keyPath: "path")
            appearPathAnimation.fromValue = startPath.cgPath
            appearPathAnimation.toValue = endPath.cgPath
            shapeLayer.add(appearPathAnimation, forKey: "path")
            
            let appearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
            appearOpacityAnimation.fromValue = 0.0
            appearOpacityAnimation.toValue = 1.0
            shapeLayer.add(appearOpacityAnimation, forKey: "opacity")
        }
        
        let disappearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        disappearOpacityAnimation.fromValue = 1.0
        disappearOpacityAnimation.toValue = 0.0
        disappearOpacityAnimation.beginTime = CACurrentMediaTime() + 0.8
        disappearOpacityAnimation.fillMode = .forwards
        disappearOpacityAnimation.isRemovedOnCompletion = false
        shapeLayer.add(disappearOpacityAnimation, forKey: "opacity")
        
        CATransaction.commit()
    }
    
    // Exposure Property
    
    fileprivate lazy var exposureGesture = UIPanGestureRecognizer()
    var exposureValue: Float = 0.1 // E
    var translationY: Float = 0
    var startPanPointInPreviewLayer: CGPoint?
    var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    let exposureDurationPower: Float = 4.0 // the exposure slider gain
    let exposureMininumDuration: Float64 = 1.0 / 2000.0
    
    var shouldEnableExposure = false {
        didSet {
            exposureGesture.isEnabled = shouldEnableExposure
        }
    }
    
    fileprivate func attachExposure() {
        DispatchQueue.main.async {
            self.exposureGesture.addTarget(self, action: #selector(self._exposureStart(_:)))
            self.addGestureRecognizer(self.exposureGesture)
            self.exposureGesture.delegate = self
        }
    }
    
    
    @objc fileprivate func _exposureStart(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else { return }
        let view = gestureRecognizer.view!
        
        _changeExposureMode(mode: .custom)
        
        let translation = gestureRecognizer.translation(in: view)
        let currentTranslation = translationY + Float(translation.y)
        if gestureRecognizer.state == .ended {
            translationY = currentTranslation
        }
        if currentTranslation < 0 {
            // up - brighter
            exposureValue = 0.5 + min(abs(currentTranslation) / 400, 1) / 2
        } else if currentTranslation >= 0 {
            // down - lower
            exposureValue = 0.5 - min(abs(currentTranslation) / 400, 1) / 2
        }
        _changeExposureDuration(value: exposureValue)
        
        // UI Visualization
        if gestureRecognizer.state == .began {
            if let validPreviewLayer = previewLayer {
                startPanPointInPreviewLayer = view.layer.convert(gestureRecognizer.location(in: view), to: validPreviewLayer)
            }
        }
        
        if let validPreviewLayer = previewLayer, let lastFocusPoint = self.lastFocusPoint {
            _showFocusRectangleAtPoint(lastFocusPoint, inLayer: validPreviewLayer, withBrightness: exposureValue)
        }
    }
    
    func _changeExposureMode(mode: AVCaptureDevice.ExposureMode) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = backCameraDevice
        case .front:
            device = frontCameraDevice
        }
        if device?.exposureMode == mode {
            return
        }
        
        do {
            try device?.lockForConfiguration()
            
            if device?.isExposureModeSupported(mode) == true {
                device?.exposureMode = mode
            }
            device?.unlockForConfiguration()
            
        } catch {
            return
        }
    }
    
    func _changeExposureDuration(value: Float) {
        if cameraIsSetup {
            let device: AVCaptureDevice?
            
            switch cameraDevice {
            case .back:
                device = backCameraDevice
            case .front:
                device = frontCameraDevice
            }
            
            guard let videoDevice = device else {
                return
            }
            
            do {
                try videoDevice.lockForConfiguration()
                
                let p = Float64(pow(value, exposureDurationPower)) // Apply power function to expand slider's low-end range
                let minDurationSeconds = Float64(max(CMTimeGetSeconds(videoDevice.activeFormat.minExposureDuration), exposureMininumDuration))
                let maxDurationSeconds = Float64(CMTimeGetSeconds(videoDevice.activeFormat.maxExposureDuration))
                let newDurationSeconds = Float64(p * (maxDurationSeconds - minDurationSeconds)) + minDurationSeconds // Scale from 0-1 slider range to actual duration
                
                if videoDevice.exposureMode == .custom {
                    let newExposureTime = CMTimeMakeWithSeconds(Float64(newDurationSeconds), preferredTimescale: 1000 * 1000 * 1000)
                    
                    videoDevice.setExposureModeCustom(duration: newExposureTime, iso: AVCaptureDevice.currentISO, completionHandler: nil)
                }
                
                videoDevice.unlockForConfiguration()
            } catch {
                return
            }
        }
    }
    
    // Movie output
    var movieOutput: AVCaptureMovieFileOutput?
    
    fileprivate func _getMovieOutput() -> AVCaptureMovieFileOutput {
        if movieOutput == nil {
            _createMovieOutput()
        }
        
        return movieOutput!
    }
    
    fileprivate func _createMovieOutput() {
        
        let newMovieOutput = AVCaptureMovieFileOutput()
        newMovieOutput.movieFragmentInterval = .invalid
        movieOutput = newMovieOutput
        
        _setupVideoConnection()
        
        if let captureSession = captureSession, captureSession.canAddOutput(newMovieOutput) {
            captureSession.beginConfiguration()
            captureSession.addOutput(newMovieOutput)
            captureSession.commitConfiguration()
        }
    }
    
    fileprivate func _setupVideoConnection() {
        if let movieOutput = movieOutput {
            for connection in movieOutput.connections {
                for port in connection.inputPorts {
                    if port.mediaType == AVMediaType.video {
                        let videoConnection = connection as AVCaptureConnection
                        // setup video mirroring
                        if videoConnection.isVideoMirroringSupported {
                            videoConnection.isVideoMirrored = (cameraDevice == CameraDevice.front && shouldFlipFrontCameraImage)
                        }
                        
                        if videoConnection.isVideoStabilizationSupported {
                            videoConnection.preferredVideoStabilizationMode = videoStabilisationMode
                        }
                    }
                }
                
                
            }
        }
    }
    
    // Image output
    
    private var photoOutput : AVCapturePhotoOutput!
    
    fileprivate func _getStillImageOutput() -> AVCapturePhotoOutput {
        if let stillImageOutput = photoOutput, let connection = stillImageOutput.connection(with: AVMediaType.video),
           connection.isActive {
            return stillImageOutput
        }
        let newStillImageOutput = AVCapturePhotoOutput()
        photoOutput = newStillImageOutput
        if let captureSession = captureSession,
           captureSession.canAddOutput(newStillImageOutput) {
            captureSession.beginConfiguration()
            captureSession.addOutput(newStillImageOutput)
            captureSession.commitConfiguration()
        }
        return newStillImageOutput
    }
    
    
    
    fileprivate func _setupOutputMode(_ newCameraOutputMode: CameraOutputMode, oldCameraOutputMode: CameraOutputMode?) {
        captureSession?.beginConfiguration()
        
        if let cameraOutputToRemove = oldCameraOutputMode {
            // remove current setting
            switch cameraOutputToRemove {
            case .stillImage:
                if let validStillImageOutput = photoOutput {
                    captureSession?.removeOutput(validStillImageOutput)
                }
            case .videoOnly, .videoWithMic:
                if let validMovieOutput = movieOutput {
                    captureSession?.removeOutput(validMovieOutput)
                }
                if cameraOutputToRemove == .videoWithMic {
                    _removeMicInput()
                }
            }
        }
        
        _setupOutputs()
        
        // configure new devices
        switch newCameraOutputMode {
        case .stillImage:
            let validStillImageOutput = _getStillImageOutput()
            if let captureSession = captureSession,
               captureSession.canAddOutput(validStillImageOutput) {
                captureSession.addOutput(validStillImageOutput)
            }
        case .videoOnly, .videoWithMic:
            let videoMovieOutput = _getMovieOutput()
            if let captureSession = captureSession,
               captureSession.canAddOutput(videoMovieOutput) {
                captureSession.addOutput(videoMovieOutput)
            }
            
            if newCameraOutputMode == .videoWithMic,
               let validMic = _deviceInputFromDevice(mic) {
                captureSession?.addInput(validMic)
            }
        }
        captureSession?.commitConfiguration()
        _updateCameraQualityMode(cameraOutputQuality)
    }
    
    fileprivate func _setupOutputs() {
        if photoOutput == nil {
            photoOutput = AVCapturePhotoOutput()
        }
        if movieOutput == nil {
            movieOutput = _getMovieOutput()
        }
        
    }
    
    // Camera Property Transition & Animation
    
    fileprivate var cameraTransitionView: UIView?
    fileprivate var transitionAnimating = false
    
    open func _doFlipAnimation() {
        if transitionAnimating {
            return
        }
        
        if let validPreviewLayer = previewLayer {
            var tempView = UIView()
            
            if self._blurSupported() {
                let blurEffect = UIBlurEffect(style: .light)
                tempView = UIVisualEffectView(effect: blurEffect)
                tempView.frame = self.bounds
            } else {
                tempView = UIView(frame: self.bounds)
                tempView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            }
            
            self.insertSubview(tempView, at: Int(validPreviewLayer.zPosition + 1))
            
            cameraTransitionView = self.snapshotView(afterScreenUpdates: true)
            
            if let cameraTransitionView = cameraTransitionView {
                self.insertSubview(cameraTransitionView, at: Int(self.layer.zPosition + 1))
            }
            tempView.removeFromSuperview()
            
            transitionAnimating = true
            
            validPreviewLayer.opacity = 0.0
            
            DispatchQueue.main.async {
                self._flipCameraTransitionView()
            }
        }
    }
    fileprivate func _flipCameraTransitionView() {
        if let cameraTransitionView = cameraTransitionView {
            UIView.transition(with: cameraTransitionView,
                              duration: 0.5,
                              options: UIView.AnimationOptions.transitionFlipFromLeft,
                              animations: nil,
                              completion: { (_) -> Void in
                self._removeCameraTransistionView()
            })
        }
    }
    fileprivate func _removeCameraTransistionView() {
        if let cameraTransitionView = cameraTransitionView {
            if let validPreviewLayer = previewLayer {
                validPreviewLayer.opacity = 1.0
            }
            
            UIView.animate(withDuration: 0.5,
                           animations: { () -> Void in
                
                cameraTransitionView.alpha = 0.0
                
            }, completion: { (_) -> Void in
                
                self.transitionAnimating = false
                
                cameraTransitionView.removeFromSuperview()
                self.cameraTransitionView = nil
            })
        }
    }
    func _blurSupported() -> Bool {
        var supported = Set<String>()
        supported.insert("iPad")
        supported.insert("iPad1,1")
        supported.insert("iPhone1,1")
        supported.insert("iPhone1,2")
        supported.insert("iPhone2,1")
        supported.insert("iPhone3,1")
        supported.insert("iPhone3,2")
        supported.insert("iPhone3,3")
        supported.insert("iPod1,1")
        supported.insert("iPod2,1")
        supported.insert("iPod2,2")
        supported.insert("iPod3,1")
        supported.insert("iPod4,1")
        supported.insert("iPad2,1")
        supported.insert("iPad2,2")
        supported.insert("iPad2,3")
        supported.insert("iPad2,4")
        supported.insert("iPad3,1")
        supported.insert("iPad3,2")
        supported.insert("iPad3,3")
        
        return !supported.contains(_hardwareString())
    }
    
    func _hardwareString() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        guard let deviceName = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) else {
            return ""
        }
        return deviceName
    }
    fileprivate func _performShutterAnimation(_ completion: (() -> Void)?) {
        if let validPreviewLayer = previewLayer {
            DispatchQueue.main.async {
                let duration = 0.1
                
                CATransaction.begin()
                
                if let completion = completion {
                    CATransaction.setCompletionBlock(completion)
                }
                
                let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
                fadeOutAnimation.fromValue = 1.0
                fadeOutAnimation.toValue = 0.0
                validPreviewLayer.add(fadeOutAnimation, forKey: "opacity")
                
                let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
                fadeInAnimation.fromValue = 0.0
                fadeInAnimation.toValue = 1.0
                fadeInAnimation.beginTime = CACurrentMediaTime() + duration * 2.0
                validPreviewLayer.add(fadeInAnimation, forKey: "opacity")
                
                CATransaction.commit()
            }
        }
    }
    
    
    
    // Stops running capture session and removes all setup devices, inputs and outputs.
    
    open func stopAndRemoveCaptureSession() {
        stopCaptureSession()
        let oldAnimationValue = animateCameraDeviceChange
        animateCameraDeviceChange = false
        cameraDevice = .back
        cameraIsSetup = false
        previewLayer = nil
        captureSession = nil
        frontCameraDevice = nil
        backCameraDevice = nil
        mic = nil
        photoOutput = nil
        movieOutput = nil
        animateCameraDeviceChange = oldAnimationValue
    }
    
    open func stopCaptureSession() {
        captureSession?.stopRunning()
    }
    open func resumeCaptureSession() {
        if let validCaptureSession = captureSession {
            if !validCaptureSession.isRunning, cameraIsSetup {
                sessionQueue.async {
                    validCaptureSession.startRunning()
                }
            }
        } else {
            if _canLoadCamera() {
                if cameraIsSetup {
                    stopAndRemoveCaptureSession()
                }
                _setupCamera {
                    self._addPreviewLayerToView()
                    
                }
            }
        }
    }
    
    fileprivate func _removeMicInput() {
        guard let inputs = captureSession?.inputs else { return }
        
        for input in inputs {
            if let deviceInput = input as? AVCaptureDeviceInput,
               deviceInput.device == mic {
                captureSession?.removeInput(deviceInput)
                break
            }
        }
    }
    
    fileprivate func _deviceInputFromDevice(_ device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let outError {
            self._showCameraLoadError("Device setup error occured", message: "\(outError)")
            return nil
        }
    }
    
    deinit {
        stopAndRemoveCaptureSession()
    }
    
    fileprivate func _tempFilePath() -> URL {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMovie\(Date().timeIntervalSince1970)").appendingPathExtension("mp4")
        return tempURL
    }
    fileprivate func _executeVideoCompletionWithURL(_ url: URL?, error: NSError?) {
        if let videoUrl = url
        {
            if let validCompletion = self.videoError {
                validCompletion(nil, nil)
                self.videoError = nil
            }
            self.delegate?.CameraManagerViewDidFinishedRecording(videoUrl)
            
        }
        else
        {
            DispatchQueue.main.async { () -> Void in
                if let validCompletion = self.videoError {
                    validCompletion(nil, nil)
                    self.videoError = nil
                }
            }
            
        }
        
    }
    /**
     Starts recording a video with or without voice as in the session preset.
     */
    open func startRecordingVideo(_ completion: ((_ videoURL: URL?, _ error: NSError?) -> Void)?) {
        videoError = completion
        
        guard cameraOutputMode != .stillImage else {
            self._showCameraLoadError("Capture session output still image", message: "I can only take pictures")
            
            return
        }
        
        let videoOutput = _getMovieOutput()
        let movieFileOutputConnection = videoOutput.connection(with: .video)
        
        let availableVideoCodecTypes = videoOutput.availableVideoCodecTypes
        print("debug cam: availableVideoCodecTypes = \(availableVideoCodecTypes)")
        
        
        if availableVideoCodecTypes.contains(.h264) {
            videoOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264], for: movieFileOutputConnection!)
        }
        
        if let connection = movieFileOutputConnection, (connection.isVideoOrientationSupported) {
            connection.videoOrientation = currentVideoOrientation()
        }
        
        _updateIlluminationMode(flashMode)
        
        videoOutput.startRecording(to: _tempFilePath(), recordingDelegate: self)
    }
    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation
        
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = AVCaptureVideoOrientation.portrait
        case .landscapeRight:
            orientation = AVCaptureVideoOrientation.landscapeLeft
        case .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation.portraitUpsideDown
        default:
            orientation = AVCaptureVideoOrientation.landscapeRight
        }
        print("debug orientation:\(orientation) ")
        return orientation
    }
    /**
     Stop recording a video. Save it to the cameraRoll and give back the url.
     */
    open func stopVideoRecording() {
        if let runningMovieOutput = movieOutput,
           runningMovieOutput.isRecording {
            runningMovieOutput.stopRecording()
        }
    }
    func handleTakePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        if let photoOutputConnection = self.photoOutput.connection(with: AVMediaType.video) {
            photoOutputConnection.videoOrientation = currentVideoOrientation()
        }
        if hasFlash
        {
            photoSettings.flashMode = self.photoflashMode
        }
        if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    func photoCapturedWithData(imageData:Data)
    {
        self.delegate?.CameraManagerViewDidProcessedPhoto(imageData)
        
    }
    
    func getCameraOutputResolution() -> CGSize? {
        if !cameraIsSetup
        {
            return nil
        }
        
        if self.cameraDevice == .front,let currentAVCaptureDevice = self.frontCameraDevice
        {
            let format = currentAVCaptureDevice.activeFormat.formatDescription
            let resolution = CMVideoFormatDescriptionGetDimensions(format)
            
            return CGSize(width: CGFloat(resolution.width), height: CGFloat(resolution.height))
        }
        else if self.cameraDevice == .back,let currentAVCaptureDevice = self.backCameraDevice
        {
            let format = currentAVCaptureDevice.activeFormat.formatDescription
            let resolution = CMVideoFormatDescriptionGetDimensions(format)
            
            return CGSize(width: CGFloat(resolution.width), height: CGFloat(resolution.height))
        }
        return nil
    }
}
extension CameraManagerView:AVCapturePhotoCaptureDelegate
{
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        self.photoCapturedWithData(imageData: imageData)
        
        
    }
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // dispose system shutter sound
        //            AudioServicesDisposeSystemSoundID(1108)
    }
}
extension CameraManagerView:AVCaptureFileOutputRecordingDelegate
{
    public func fileOutput(_: AVCaptureFileOutput, didStartRecordingTo _: URL, from _: [AVCaptureConnection]) {
        captureSession?.beginConfiguration()
        if flashMode != .off {
            _updateIlluminationMode(flashMode)
        }
        
        captureSession?.commitConfiguration()
        
    }
    
    open func fileOutput(_: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from _: [AVCaptureConnection], error: Error?) {
        
        if let videodata = try? Data(contentsOf: outputFileURL),videodata.count > 0  {
            
            DispatchQueue.main.async { () -> Void in
                self._executeVideoCompletionWithURL(outputFileURL, error: error as NSError?)
            }
        }
        else
        {
            DispatchQueue.main.async { () -> Void in
                if let validCompletion = self.videoError {
                    validCompletion(nil, nil)
                    self.videoError = nil
                }
                
            }
        }
        
    }
}
private extension AVCaptureDevice {
    static var videoDevices: [AVCaptureDevice] {
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified).devices
        
    }
}

