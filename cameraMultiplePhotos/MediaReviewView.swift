//
//  MediaReviewView.swift
//  cameraMultiplePhotos
//
//  Created by matraex naren on 30/07/24.
//

import Foundation
import UIKit
import AVFoundation

class MediaReviewView: UIView {
    
    // MARK: - Initialization
    var use_video_button_text = "Use Video"
    var use_photo_button_text = "Use Photo"
    var cancel_button_text = "Cancel"
    
    var imageview = UIImageView()
    var videoPlayerView : VideoPlayerView?
    var topSpace: CGFloat = 0

    var imgData:Data?
    var videoUrl:URL?
    weak var delegate: MediaReviewViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        //initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        //initialize()
    }
    func setUp()
    {
        addOptionsButton()
        
    }
    func loadVideoFrom(url:URL,isVideo:Bool = true)
    {
        self.imgData = nil
        self.videoUrl = nil
        self.imageview.isHidden = true
        self.videoPlayerView?.isHidden = false
        useMediaButton.setTitle(self.use_video_button_text, for: .normal)
        useMediaButton.setTitle(self.use_video_button_text, for: .selected)
        self.videoUrl = url
        videoPlayerView?.loadVideo(with: url)
        
    }
    func loadImageFromData(data:Data)
    {
        self.imgData = nil
        self.videoUrl = nil
        self.imageview.isHidden = false
        self.imageview.contentMode = .scaleAspectFill
        self.videoPlayerView?.isHidden = true
        
        useMediaButton.setTitle(self.use_photo_button_text, for: .normal)
        useMediaButton.setTitle(self.use_photo_button_text, for: .selected)
        self.imageview.image = UIImage(data: data)
        
        self.imgData = data
    }
    var OptionContainerView = UIStackView()
    
    func addOptionsButton()
    {
        let buttonSize:CGFloat = 64
        
        var mediaframe = self.bounds
        mediaframe.size.height = mediaframe.size.height - buttonSize
        imageview.frame = mediaframe
        self.imageview.backgroundColor = .clear
        self.addSubview(self.imageview)
        let cellPlayerView = VideoPlayerView(frame: mediaframe)
        cellPlayerView.backgroundColor = .white
        cellPlayerView.isHidden = true
        self.addSubview(cellPlayerView)
        videoPlayerView = cellPlayerView
        
        
        let viewwidth = self.bounds.size.width
        self.OptionContainerView = UIStackView(frame: CGRect(x: 0 , y: mediaframe.size.height, width: viewwidth, height: buttonSize))
        self.OptionContainerView.axis = .horizontal
        self.OptionContainerView.backgroundColor = .white
        self.addSubview(self.OptionContainerView)
        self.OptionContainerView.alignment = .fill
        self.OptionContainerView.distribution = .fillEqually
        addCancelButton()
        addUseButton()
    }
    
    var cancelButton = UIButton()
    
    func addCancelButton()
    {
        let view1 = UIView(frame: CGRect(x: 0 , y: 0 , width: self.OptionContainerView.frame.size.width/2, height: self.OptionContainerView.frame.size.height))
        view1.backgroundColor = UIColor.clear
        view1.clipsToBounds = true
        
        cancelButton.frame  =  CGRect(x: 8 , y: 10, width: 100, height: 44)
        cancelButton.addTarget(self, action: #selector(self.cancelTapped(sender:)), for: .touchUpInside)
        cancelButton.tintColor = .black
        cancelButton.setTitleColor(.black, for: .normal)
        cancelButton.setTitleColor(.black, for: .selected)
        
        cancelButton.setTitle(self.cancel_button_text, for: .normal)
        cancelButton.setTitle(self.cancel_button_text, for: .selected)
        
        view1.addSubview(cancelButton)
        self.OptionContainerView.addArrangedSubview(view1)
    }
    @objc func cancelTapped(sender: UIButton) {
        self.removeFromSuperview()
    }
    var useMediaButton = UIButton()
    
    func addUseButton()
    {
        let view1 = UIView(frame: CGRect(x: 0 , y: 0 , width: self.OptionContainerView.frame.size.width/2, height: self.OptionContainerView.frame.size.height))
        view1.backgroundColor = UIColor.clear
        view1.clipsToBounds = true
        
        useMediaButton.frame  =  CGRect(x: view1.frame.size.width - 108 , y: 10, width: 100, height: 44)
        useMediaButton.addTarget(self, action: #selector(self.useMediaTapped(sender:)), for: .touchUpInside)
        useMediaButton.setTitle(self.use_photo_button_text, for: .normal)
        useMediaButton.setTitle(self.use_photo_button_text, for: .selected)
        useMediaButton.tintColor = .black
        useMediaButton.setTitleColor(.black, for: .normal)
        useMediaButton.setTitleColor(.black, for: .selected)
        
        view1.addSubview(useMediaButton)
        self.OptionContainerView.addArrangedSubview(view1)
    }
    @objc func useMediaTapped(sender: UIButton) {
        self.removeFromSuperview()
        if let imageData = self.imgData
        {
            self.delegate?.MediaReviewViewDidProcessedPhoto(imageData)
        }
        else if let videoUrl
        {
            self.delegate?.MediaReviewViewDidFinishedRecording(videoUrl)
        }
        
    }
    
    func imagePreview(from moviePath: URL, in seconds: Double,completion: @escaping (UIImage?) -> Void) {
        let imagename = moviePath.deletingPathExtension().lastPathComponent
        let imageURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(imagename).jpeg")
        if FileManager.default.fileExists(atPath: imageURL.path)
        {
            let data = try? Data(contentsOf: imageURL)
            
            if let imageData = data {
                let image = UIImage(data: imageData)
                completion(image)
            }
            
        }
        
        let timestamp = CMTime(seconds: seconds, preferredTimescale: 60)
        let asset = AVURLAsset(url: moviePath)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        guard let imageRef = try? generator.copyCGImage(at: timestamp, actualTime: nil) else {
            completion(nil)
            return
        }
        let thumbnail = UIImage(cgImage: imageRef)
        
        completion(thumbnail)
        
    }
    
}
