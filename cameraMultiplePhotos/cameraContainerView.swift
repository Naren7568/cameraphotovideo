//
//  cameraContainerView.swift
//  cameraMultiplePhotos
//
//  Created by Narendra jain on 11/05/23.
//


import Foundation
import UIKit
import AVFoundation

import MobileCoreServices
import AVKit
import Photos



class cameraContainerView: UIView {
    
    // MARK: - Initialization
    @IBOutlet weak var camOptionContainerView: UIStackView!
    @IBOutlet weak var camera_Preview: CameraManagerView!
    @IBOutlet weak var bottomContainerView: UIView!
    @IBOutlet weak var photoCaptureButton:CameraCustomButton!
    @IBOutlet weak var cancelButton:UIButton!
    @IBOutlet weak var doneButton:UIButton!
    @IBOutlet weak var flashMenuButton:UIButton!
    @IBOutlet weak var cameraSwitchButton:UIButton!
    @IBOutlet weak var videoSwitchButton:UIButton!
    @IBOutlet weak var photoSwitchButton:UIButton!
    @IBOutlet weak var videoTimerLabel: UILabel!
    @IBOutlet weak var mediaStackView: ImageStackView!
    // used to keep track of recording duration
    var videoTimer: Timer?
    
    // current video duration in seconds
    var videoTimerSeconds = 0
    weak var delegate: cameraContainerViewDelegate?
    
    @IBAction func cameraDidCancelled(_ sender: UIButton) {
        if let runningMovieOutput = camera_Preview.movieOutput,
           runningMovieOutput.isRecording {
            return
        }
        self.delegate?.cameraContainerViewDidCancelled(self)
    }
    
    
    @IBAction func cameraDidDone(_ sender: UIButton) {
        if let runningMovieOutput = camera_Preview.movieOutput,
           runningMovieOutput.isRecording {
            return
        }
        self.delegate?.cameraContainerViewDidFinished(self)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        //initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        //initialize()
    }
    // MARK: basic setup
    
    var isVideoEnabled = true
    var isPhotoEnabled = true
    var isReviewEnabled = true
    var showFlashSetting = true
    var showRotateCamera = true
    
    
    func setUp() {
        
        self.checkCameraPermission()
        
    }
    
    
    
    // MARK: permission view setup
    var permissionContainerView = UIView()
    var permissionContainerWidth:CGFloat = 288
    var permissionContainerheight:CGFloat = 210
    
    func showPermissionInterface()
    {
        self.permissionContainerView.frame = CGRect(x: 0, y: 0, width: permissionContainerWidth, height: permissionContainerheight)
        
        self.permissionContainerView.backgroundColor = .clear
        self.addSubview(self.permissionContainerView)
        self.permissionContainerView.center = self.center
        self.permissionContainerView.layer.masksToBounds = false
        self.permissionContainerView.layer.shadowOffset = CGSize(width: 0, height: 0)
        self.permissionContainerView.layer.shadowOpacity =  0.7
        self.permissionContainerView.layer.shadowColor = UIColor.lightGray.cgColor
        self.addCameraPermissionButton()
        if self.isVideoEnabled
        {
            self.addmicPermissionButton()
        }
        self.addPermissionCancelButton()
    }
    var cameraPermissionBtn = UIButton()
    var cameraPermissionIcon = UIButton()
    var cameraAllowed = false
    var micAllowed = false
    let largeConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold, scale: .medium)
    
    let cancelImage = UIImage(systemName: "xmark.circle.fill",withConfiguration:UIImage.SymbolConfiguration(pointSize: 24, weight: .bold, scale: .medium))
    let checkMarkCircleFill = UIImage(systemName: "checkmark.circle.fill",withConfiguration:UIImage.SymbolConfiguration(pointSize: 24, weight: .bold, scale: .medium))
    
    func addCameraPermissionButton()
    {
        let margin:CGFloat = 16
        
        let view1 = UIView(frame: CGRect(x: margin , y: margin, width: permissionContainerWidth - 32, height: 54))
        view1.backgroundColor = UIColor.white
        view1.layer.cornerRadius = margin
        view1.clipsToBounds = true
        
        cameraPermissionIcon.frame  =  CGRect(x: 8 , y: 5, width: 44, height: 44)
        cameraPermissionIcon.imageView?.tintColor = UIColor.darkGray
        cameraPermissionIcon.imageView?.contentMode = .scaleAspectFit
        cameraPermissionIcon.setImage(cancelImage, for: .normal)
        
        view1.addSubview(cameraPermissionIcon)
        
        cameraPermissionBtn.setTitleColor(.black, for: .normal)
        cameraPermissionBtn.setTitle("Request Camera Access", for: .normal)
        cameraPermissionBtn.addTarget(self, action: #selector(self.askCameraPermission(sender:)), for: .touchUpInside)
        cameraPermissionIcon.addTarget(self, action: #selector(self.askCameraPermission(sender:)), for: .touchUpInside)
        
        cameraPermissionBtn.frame = CGRect(x: 60 , y: 0, width: permissionContainerWidth - 60, height: 54)
        cameraPermissionBtn.backgroundColor = .white
        cameraPermissionBtn.contentHorizontalAlignment = .left
        view1.addSubview(cameraPermissionBtn)
        cameraPermissionBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        cameraPermissionBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        self.permissionContainerView.addSubview(view1)
        
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == .authorized
        {
            cameraAllowed = true
            self.cameraPermissionBtn.isEnabled = false
            self.cameraPermissionIcon.isEnabled = false
            cameraPermissionIcon.setImage(checkMarkCircleFill, for: .normal)
            
            
        }
    }
    var micPermissionBtn = UIButton()
    var micPermissionIcon = UIButton()
    func addmicPermissionButton()
    {
        let margin:CGFloat = 16
        
        let view1 = UIView(frame: CGRect(x: margin , y: 54 + (2*margin), width: permissionContainerWidth - 32, height: 54))
        view1.backgroundColor = UIColor.white
        view1.layer.cornerRadius = margin
        view1.clipsToBounds = true
        
        micPermissionIcon.frame  =  CGRect(x: 8 , y: 5, width: 44, height: 44)
        micPermissionIcon.imageView?.tintColor = UIColor.darkGray
        micPermissionIcon.imageView?.contentMode = .scaleAspectFit
        
        micPermissionIcon.setImage(cancelImage, for: .normal)
        
        view1.addSubview(micPermissionIcon)
        
        micPermissionBtn.setTitleColor(.black, for: .normal)
        micPermissionBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        micPermissionBtn.backgroundColor = UIColor.white
        micPermissionBtn.setTitle("Request Microphone Access", for: .normal)
        
        micPermissionBtn.frame = CGRect(x: 60 , y: 0, width: permissionContainerWidth - 60, height: 54)
        micPermissionBtn.contentHorizontalAlignment = .left
        view1.addSubview(micPermissionBtn)
        micPermissionBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        self.permissionContainerView.addSubview(view1)
        
        
        if AVAudioSession.sharedInstance().recordPermission == .granted
        {
            self.micPermissionBtn.isEnabled = false
            self.micPermissionIcon.isEnabled = false
            micAllowed = true
            micPermissionIcon.setImage(checkMarkCircleFill, for: .normal)
            
        }
        micPermissionBtn.addTarget(self, action: #selector(self.askMicPermission(sender:)), for: .touchUpInside)
        micPermissionIcon.addTarget(self, action: #selector(self.askMicPermission(sender:)), for: .touchUpInside)
    }
    var permissioncancelButton = UIButton()
    func addPermissionCancelButton()
    {
        
        let margin:CGFloat = 16
        var marginMultiplier:CGFloat = 2
        if self.isVideoEnabled
        {
            marginMultiplier = 3
        }
        let view1 = UIView(frame: CGRect(x: margin , y: (54 * (marginMultiplier - 1)) + (marginMultiplier * margin), width: permissionContainerWidth - 32, height: 54))
        view1.backgroundColor = UIColor.white
        view1.layer.cornerRadius = margin
        view1.clipsToBounds = true
        
        
        
        permissioncancelButton.setTitleColor(.black, for: .normal)
        permissioncancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        permissioncancelButton.backgroundColor = UIColor.white
        permissioncancelButton.setTitle("Cancel", for: .normal)
        
        
        permissioncancelButton.frame = CGRect(x: 0 , y: 0, width: view1.frame.size.width , height: 54)
        permissioncancelButton.contentHorizontalAlignment = .center
        view1.addSubview(permissioncancelButton)
        permissioncancelButton.titleLabel?.adjustsFontSizeToFitWidth = true
        self.permissionContainerView.addSubview(view1)
        
        
        
        permissioncancelButton.addTarget(self, action: #selector(self.cancelPermissionClicked(sender:)), for: .touchUpInside)
    }
    @objc func cancelPermissionClicked(sender:UIButton)
    {
        self.delegate?.cameraContainerViewDidCancelled(self)
    }
    @objc func askCameraPermission(sender:UIButton)
    {
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == .notDetermined
        {
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { granted in
                DispatchQueue.main.async {
                    
                    if granted{
                        print(granted)
                        self.cameraPermissionBtn.isEnabled = false
                        self.cameraPermissionIcon.isEnabled = false
                        self.cameraPermissionIcon.setImage(self.checkMarkCircleFill, for: .normal)
                        self.cameraAllowed = true
                        if self.micAllowed
                        {
                            self.showCameraInterface()
                        }
                        
                    }
                    else
                    {
                        self.cameraPermissionIcon.setImage(self.cancelImage, for: .normal)
                        
                        
                    }
                }
            })
        }
        else{
            let url = URL(string: UIApplication.openSettingsURLString)!
            
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            
            
        }
    }
    
    @objc func askMicPermission(sender:UIButton)
    {
        if AVAudioSession.sharedInstance().recordPermission == .undetermined
        {
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                DispatchQueue.main.async
                {
                    
                    if granted{
                        print(granted)
                        self.micPermissionBtn.isEnabled = false
                        self.micPermissionIcon.isEnabled = false
                        self.micPermissionIcon.setImage(self.checkMarkCircleFill, for: .normal)
                        self.micAllowed = true
                        if self.cameraAllowed
                        {
                            self.showCameraInterface()
                        }
                        
                    }
                    else
                    {
                        self.micPermissionIcon.setImage(self.cancelImage, for: .normal)
                        
                    }
                }
            })
        }
        else
        {
            let url = URL(string: UIApplication.openSettingsURLString)!
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            
            
        }
    }
    
    
    func checkCameraPermission()
    {
        
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch cameraAuthorizationStatus {
        case .authorized:
            DispatchQueue.main.async {
                if self.isVideoEnabled
                {
                    self.checkMicPermission()
                }
                else
                {
                    self.showCameraInterface()
                }
                
            }
        case .notDetermined:
            DispatchQueue.main.async {
                
                self.showPermissionInterface()
            }
        case .denied,.restricted:
            DispatchQueue.main.async {
                
                
                self.showPermissionInterface()
            }
        default:
            DispatchQueue.main.async {
                self.showPermissionInterface()
            }
        }
    }
    func checkMicPermission() {
        
        
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            DispatchQueue.main.async {
                self.showCameraInterface()
            }
        case .denied:
            DispatchQueue.main.async {
                self.showPermissionInterface()
                
            }
        case .undetermined:
            DispatchQueue.main.async {
                self.showPermissionInterface()
            }
        default:
            DispatchQueue.main.async {
                self.showPermissionInterface()
            }
            break
        }
        
    }
    
    func showCameraInterface()
    {
        self.permissionContainerView.isHidden = true
        self.camera_Preview.isHidden = false
        self.camera_Preview.delegate = self
        mediaReviewView.frame = self.bounds
        mediaReviewView.backgroundColor = .red
        mediaReviewView.setUp()
        mediaReviewView.delegate = self
        self.mediaReviewView.topSpace = self.camOptionContainerView.frame.origin.y
        
        if !self.isPhotoEnabled
        {
            self.camera_Preview.cameraOutputMode = .videoWithMic
        }
        
        self.camera_Preview.setup()
        self.addCameraOptionsButton()
        setupVideoTimerLabel()
    }
    func setupVideoTimerLabel() {
        
        // make video label start as invisible and round corners
        videoTimerLabel.alpha = 0
        videoTimerLabel.layer.cornerRadius = 5
        videoTimerLabel.clipsToBounds = true
    }
    
    
    func addCameraOptionsButton()
    {
        self.camOptionContainerView.isHidden = false
        addFlashButton()
        addPhotoCaptureButton()
    }
    
    func addPhotoCaptureButton()
    {
        self.bottomContainerView.isHidden = false
        photoCaptureButton.backgroundColor = .clear
        photoCaptureButton.setTitle("", for: .normal)
        
        if self.isPhotoEnabled
        {
            photoCaptureButton.type = .photo
        }
        else
        {
            photoCaptureButton.type = .video
        }
        
        photoCaptureButton.addTarget(self, action: #selector(self.takePhoto(sender:)), for: .touchUpInside)
    }
    @objc func takePhoto(sender:CameraCustomButton)
    {
        if camera_Preview.cameraOutputMode == .stillImage  {
            camera_Preview.handleTakePhoto()
        } else {
            // start or stop video depending on recording status
            if let runningMovieOutput = camera_Preview.movieOutput,
               runningMovieOutput.isRecording {
                runningMovieOutput.stopRecording()
                
                // reset and dismiss timer
                videoTimer?.invalidate()
                videoTimer = nil
                UIView.animate(withDuration: 0.5) {
                    self.videoTimerLabel.alpha = 0
                }
            } else {
                self.startVideoRecording()
                
                // configure and reveal timer
                videoTimerLabel.alpha = 0
                UIView.animate(withDuration: 0.5) {
                    self.videoTimerLabel.alpha = 1.0
                }
                videoTimerSeconds = 0
                videoTimerLabel.text = "00:00"
                videoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.videoTimerSeconds += 1
                    let minutes = self!.videoTimerSeconds / 60
                    let remainingSeconds = self!.videoTimerSeconds % 60
                    self!.videoTimerLabel.text = String(format: "%02d:%02d", minutes, remainingSeconds)
                }
            }
        }
        
    }
    
    
    func addFlashButton()
    {
        if self.showFlashSetting
        {
            self.flashMenuButton.isHidden = false
            let menuClosure = {(action: UIAction) in
                
                self.changeFlashMode(senderActionTitle: action.title)
            }
            self.flashMenuButton.menu = UIMenu(children: [
                UIAction(title: "Off", state: .on, handler:
                            menuClosure),
                UIAction(title: "On", handler: menuClosure),
                UIAction(title: "Auto", handler: menuClosure),
            ])
            self.flashMenuButton.showsMenuAsPrimaryAction = true
            if #available(iOS 15.0, *) {
                self.flashMenuButton.changesSelectionAsPrimaryAction = true
            } else {
                // Fallback on earlier versions
            }
        }
        else
        {
            self.flashMenuButton.isHidden = true
        }
    }
    func changeFlashMode(senderActionTitle: String) {
        if senderActionTitle == "Off"
        {
            camera_Preview.changeFlashMode(newFlashMode: .off)
            let flashOffImage = UIImage(systemName: "bolt.slash.fill",withConfiguration:largeConfig)
            flashMenuButton.setImage(flashOffImage, for: .normal)
            
        }
        else if senderActionTitle == "On"
        {
            camera_Preview.changeFlashMode(newFlashMode: .on)
            let flashOnImage = UIImage(systemName: "bolt.fill",withConfiguration:largeConfig)
            flashMenuButton.setImage(flashOnImage, for: .normal)
        }
        else
        {
            camera_Preview.changeFlashMode(newFlashMode: .auto)
            let flashautoImage = UIImage(systemName: "bolt.badge.a.fill",withConfiguration:largeConfig)
            flashMenuButton.setImage(flashautoImage, for: .normal)
        }
        
    }
    @objc func changeFlashMode(sender: UIButton) {
        
    }
    
    func addCameraSwitchButton()
    {
        self.cameraSwitchButton.isHidden = !self.showRotateCamera
        
    }
    @IBAction func cameraRotateDidClicked(_ sender: UIButton) {
        self.changeCameraDevice(sender: sender)
    }
    @objc func changeCameraDevice(sender: UIButton) {
        camera_Preview.cameraDevice = camera_Preview.cameraDevice == CameraDevice.front ? CameraDevice.back : CameraDevice.front
    }
    @IBAction func switchToPhotoView(_ sender: UIButton) {
        if let runningMovieOutput = camera_Preview.movieOutput,
           runningMovieOutput.isRecording {
            return
        }
        if camera_Preview.cameraOutputMode == .stillImage
        {
            return
        }
        self.outputModeButtonTapped(sender: sender)
    }
    @IBAction func switchToVideoView(_ sender: UIButton) {
        if let runningMovieOutput = camera_Preview.movieOutput,
           runningMovieOutput.isRecording {
            return
        }
        if camera_Preview.cameraOutputMode != .stillImage
        {
            return
        }
        self.outputModeButtonTapped(sender: sender)
    }
    @objc func outputModeButtonTapped(sender: UIButton) {
        if let runningMovieOutput = camera_Preview.movieOutput,
           runningMovieOutput.isRecording {
            return
        }
        
        camera_Preview.cameraOutputMode = camera_Preview.cameraOutputMode == CameraOutputMode.videoWithMic ? CameraOutputMode.stillImage : CameraOutputMode.videoWithMic
        DispatchQueue.main.async {
            switch self.camera_Preview.cameraOutputMode {
            case .stillImage:
                if let photoCaptureButton = self.photoCaptureButton
                {
                    photoCaptureButton.type = .photo
                    
                }
                self.videoSwitchButton.isSelected = false
                self.photoSwitchButton.isSelected = true
            case .videoWithMic, .videoOnly:
                
                if let photoCaptureButton = self.photoCaptureButton
                {
                    photoCaptureButton.type = .video
                    
                }
                self.videoSwitchButton.isSelected = true
                self.photoSwitchButton.isSelected = false
            }
        }
    }
    
    
    func startVideoRecording()
    {
        self.camera_Preview.startRecordingVideo { url, error in
            self.photoCaptureButton?.isSelected = false
        }
    }
    func stopVideoRecording()
    {
        self.camera_Preview.stopVideoRecording()
    }
    func takepicture()
    {
        self.camera_Preview.handleTakePhoto()
    }
    func stopAndRemoveCaptureSession() {
        self.camera_Preview.stopAndRemoveCaptureSession()
    }
    func addImageToImageStack(_ imagedata: Data)
    {
        self.mediaStackView.addImageCard(imageData: imagedata)
    }
    func addVideoThumbnailToImageStack(videoTempUrl: URL)
    {
        self.mediaStackView.addVideoCard(videoUrl: videoTempUrl)
    }
    var mediaReviewView = MediaReviewView()
    
}
extension cameraContainerView:MediaReviewViewDelegate
{
    func MediaReviewViewDidProcessedPhoto(_ imagedata: Data)
    {
        self.addImageToImageStack(imagedata)
        self.delegate?.cameraContainerViewDidProcessedPhoto(imagedata)
    }
    func MediaReviewViewDidFinishedRecording(_ videoTempUrl: URL)
    {
        self.addVideoThumbnailToImageStack(videoTempUrl: videoTempUrl)
        self.delegate?.cameraContainerViewDidFinishedRecording(videoTempUrl)
    }
}
extension cameraContainerView:CameraManagerViewDelegate
{
    func CameraManagerViewDidProcessedPhoto(_ imagedata: Data)
    {
        if self.isReviewEnabled
        {
            self.mediaReviewView.loadImageFromData(data: imagedata)
            self.addSubview(self.mediaReviewView)
        }
        else
        {
            self.addImageToImageStack(imagedata)
            self.delegate?.cameraContainerViewDidProcessedPhoto(imagedata)
        }
    }
    func CameraManagerViewDidFinishedRecording(_ videoTempUrl: URL)
    {
        
        if self.isReviewEnabled
        {
            self.mediaReviewView.loadVideoFrom(url: videoTempUrl)
            self.addSubview(self.mediaReviewView)
        }
        else
        {
            self.addVideoThumbnailToImageStack(videoTempUrl: videoTempUrl)
            self.delegate?.cameraContainerViewDidFinishedRecording(videoTempUrl)
        }
    }
}



protocol cameraContainerViewDelegate: AnyObject
{
    
    func cameraContainerViewDidCancelled(_ cameraContainer: cameraContainerView)
    func cameraContainerViewDidFinished(_ cameraContainer: cameraContainerView)
    func cameraContainerViewDidProcessedPhoto(_ imagedata: Data)
    func cameraContainerViewDidFinishedRecording(_ videoTempUrl: URL)
    
}
protocol CameraManagerViewDelegate: AnyObject
{
    
    func CameraManagerViewDidProcessedPhoto(_ imagedata: Data)
    func CameraManagerViewDidFinishedRecording(_ videoTempUrl: URL)
    
}
protocol MediaReviewViewDelegate: AnyObject
{
    
    func MediaReviewViewDidProcessedPhoto(_ imagedata: Data)
    func MediaReviewViewDidFinishedRecording(_ videoTempUrl: URL)
    
}



