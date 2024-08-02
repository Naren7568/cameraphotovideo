//
//  VideoPlayerView.swift
//  cameraMultiplePhotos
//
//  Created by matraex naren on 01/08/24.
//

import Foundation
import UIKit
import AVFoundation
import MobileCoreServices

public class VideoPlayerView: UIView {
    //MARK: Outlets
    var videoView: PlayerView!
    var playPauseButton: UIButton!
    var timeLabel: UILabel!
    var timeLabelView: UIView!
    internal var isPlaying = false
    var sliderVideoPlaying: UISlider!
    
    private var timeObserverToken: Any?
    //MARK: Internal Properties
    public var isMuted = true {
        didSet {
            self.player?.isMuted = self.isMuted
        }
    }
    
    var currentItemUrl:URL?
    //MARK: Private Properties
    private var player: AVPlayer?
    private var isSeeking = false
    var topSpace: CGFloat = 44
    //MARK: Lifecycle Methods
    override public func layoutSubviews() {
        super.layoutSubviews()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        //        player = nil
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpView()
        //initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUpView()
        //initialize()
    }
    func setUpView()
    {
        self.videoView = PlayerView(frame: self.bounds)
        self.addSubview(self.videoView)
        self.playPauseButton = UIButton(frame: CGRect(x: (self.bounds.size.width - 70)/2, y: (self.bounds.size.height - 70)/2, width: 70, height: 70))
        self.playPauseButton.backgroundColor = .white
        let playImage = UIImage(systemName: "play.circle.fill",withConfiguration:UIImage.SymbolConfiguration(pointSize: 76, weight: .bold, scale: .medium))

        let pauselImage = UIImage(systemName: "pause.circle.fill",withConfiguration:UIImage.SymbolConfiguration(pointSize: 76, weight: .bold, scale: .medium))

        self.playPauseButton.tintColor = UIColor.darkGray
        self.playPauseButton.setImage(playImage, for: .normal)
        self.playPauseButton.setImage(pauselImage, for: .selected)
        self.playPauseButton.addTarget(self, action:#selector(self.onTapPlayPauseVideoButton(sender:)), for: .touchUpInside)
        self.playPauseButton.layer.cornerRadius = 35
        self.playPauseButton.clipsToBounds = true
        self.addSubview(self.playPauseButton)
        
        self.timeLabelView = UIView(frame: CGRect(x: self.bounds.size.width - 176, y: topSpace + 8, width: 176, height: 95))
        self.timeLabelView.backgroundColor = UIColor.gray
        self.timeLabelView.layer.borderWidth = 5.0
        self.timeLabelView.layer.borderColor = UIColor.white.cgColor
        self.timeLabelView.isHidden = true
        self.addSubview(self.timeLabelView)
        
        let timemarginView = UIView(frame:CGRect(x: self.timeLabelView.bounds.size.width-8, y: topSpace + 8, width: 8, height: 95))
        timemarginView.backgroundColor = UIColor.white
        self.timeLabelView.addSubview(timemarginView)
        
        self.timeLabel = UILabel()
        self.timeLabel.text = ""
        
        self.timeLabel.backgroundColor = .clear
        self.timeLabel.font = UIFont.systemFont(ofSize: 14)
        self.timeLabel.textColor = UIColor.white
        self.timeLabel.textAlignment = .right
        self.timeLabel.frame = CGRect(x: self.bounds.size.width - 150-16, y: topSpace + 13, width: 150, height: 40)
        self.timeLabel.shadowOffset = CGSize(width: 1, height: 1)
        self.timeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.timeLabel.adjustsFontSizeToFitWidth = true

        
        self.addSubview(self.timeLabel)
 
        
        sliderVideoPlaying = UISlider(frame:CGRect(x: self.bounds.size.width - 150-16, y: 53 + topSpace, width: 150, height: 20))
                    self.sliderVideoPlaying.minimumValue = 0
                    self.sliderVideoPlaying.maximumValue = 1
                    self.sliderVideoPlaying.isContinuous = true
                    self.sliderVideoPlaying.tintColor = UIColor.white
                    self.sliderVideoPlaying.minimumTrackTintColor = UIColor.white
                    self.sliderVideoPlaying.maximumTrackTintColor = UIColor.white
                    self.sliderVideoPlaying.backgroundColor = UIColor.black.withAlphaComponent(0.5)
                    self.sliderVideoPlaying.isHidden = false
        self.sliderVideoPlaying.addTarget(self, action: #selector(self.slideVideoAction(_:)), for: .valueChanged)
                    self.addSubview(self.sliderVideoPlaying)

        
        
    }
    
    
    @objc func slideVideoAction(_ sender: UISlider) {
        seekVideoTo(seconds: Double(sender.value))
    }
    
    private func seekVideoTo(seconds:Double){
        guard let item = self.player?.currentItem else {
            return
        }
//        print("pop video slider debug: sliderValue = \(seconds)")
        let seektime = (seconds * (item.duration.seconds * 1000))/1000
        print("pop video slider debug: seektime = \(seektime)")

        isSeeking = true
        let slideTime = CMTime(seconds: seektime, preferredTimescale: Int32(NSEC_PER_SEC))
//        print("pop video slider debug: slideTime = \(slideTime.seconds)")
        player?.seek(to: slideTime, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { [weak self](finish) in
            self?.isSeeking = !finish
            if finish
            {
                if let currentItem = self?.player?.currentItem
                {
                    let currentTime = currentItem.currentTime()
//                    print("pop video slider debug: currentTime after seeking = \(currentTime.seconds)")

                    self?.timeLabel?.text = "\(currentTime.positionalTimemilis)/\(currentItem.duration.positionalTimemilis)"

                }
                
            }
            
        })

    }
    
    //MARK: Public Methods
    
    
    public func loadVideo(with url: URL) {
        
        self.loadVideos(with: url)
    }
    
    
    public func loadVideos(with urls: URL) {
        
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        guard let player = self.player(with: urls) else {
            print("🚫 AVPlayer not created.")
            return
        }
        self.player?.pause()
        self.player?.replaceCurrentItem(with: nil)
        self.player = nil
        self.player = player
        self.videoView.player = self.player
        self.videoView.playerLayer.videoGravity = .resizeAspectFill
        self.videoView.clipsToBounds = true
        //        self.videoView.playerLayer.contentsGravity = .resizeAspect
        self.playPauseButton.isSelected = false
        
        self.currentItemUrl = urls
        
    }
    
    public func playVideo() {
        self.player?.play()
        self.playPauseButton.isSelected = true
        isPlaying = true
        self.sliderVideoPlaying.isHidden = true
        self.timeLabelView.isHidden = true
        self.timeLabel.backgroundColor = .clear
        
    }
    
    public func pauseVideo() {
        self.player?.pause()
        self.playPauseButton.isSelected = false
        isPlaying = false
        self.timeLabel.backgroundColor = .black.withAlphaComponent(0.5)
        self.sliderVideoPlaying.isHidden = false
        
        
    }
    
    //MARK: Button Action Methods
    @objc func onTapPlayPauseVideoButton(sender: UIButton) {
        if sender.isSelected {
            self.pauseVideo()
        } else {
            self.playVideo()
        }
        
        
    }
    
    func finishVideo(){
        player?.seek(to: CMTime.zero)
        pauseVideo()
    }
    
    
}
private extension VideoPlayerView {
    
    
    func player(with url: URL) -> AVPlayer? {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        
        
        let player = AVPlayer(playerItem: playerItem)
        let interval: CMTime = CMTimeMakeWithSeconds(0.001, preferredTimescale: Int32(NSEC_PER_SEC))


        self.timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) {[weak self] time in
            guard let self = self, let item = self.player?.currentItem else {
                return
            }
            let current = (time.seconds * 1000) / (item.duration.seconds * 1000)
            print("pop video slider debug: current = \(current)")
            guard !(current.isNaN || current.isInfinite) else {
                print("pop video slider debug: current is NAN")
                return
                
            }
            if !self.isSeeking
            {
                self.sliderVideoPlaying.value = Float(current)
            }
            
            self.timeLabel?.text = "\(time.positionalTimemilis)/\(item.duration.positionalTimemilis)"
            
            
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerEndedPlaying), name: Notification.Name("AVPlayerItemDidPlayToEndTimeNotification"), object: nil)
        let duration : CMTime = (player.currentItem!.asset.duration)
        self.timeLabel.text = "\(duration.positionalTimemilis)"
        
        return player
    }
    
    
    
    @objc func playerEndedPlaying(_ notification: Notification) {
        DispatchQueue.main.async {[weak self] in
            if let playerItem = notification.object as? AVPlayerItem {
                //                self?.player?.remove(playerItem)
                playerItem.seek(to: CMTime.zero, completionHandler: nil)
                //                self?.player?.insert(playerItem, after: nil)
                let duration : CMTime = (self?.player?.currentItem!.asset.duration)!
                self?.timeLabel.text = "\(duration.positionalTimemilis)"
                self?.pauseVideo()
                self?.sliderVideoPlaying.value = 0
                
            }
        }
    }
}


class PlayerView: UIView {
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    override class var layerClass: AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }
    
}
extension CMTime {
    var durationText:String {
        let totalSeconds = Int(CMTimeGetSeconds(self))
        let hours:Int = Int(totalSeconds / 3600)
        let minutes:Int = Int(totalSeconds % 3600 / 60)
        let seconds:Int = Int((totalSeconds % 3600) % 60)

        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }
    var roundedSeconds: TimeInterval {
        return seconds.rounded()
    }
    var hours:  Int { return Int(roundedSeconds / 3600) }
    var minute: Int { return Int(roundedSeconds.truncatingRemainder(dividingBy: 3600) / 60) }
    var second: Int { return Int(roundedSeconds.truncatingRemainder(dividingBy: 60)) }
    var millisecondsInt:Int{
        return Int((seconds.truncatingRemainder(dividingBy: 1) * 1000))
    }

    var positionalTime: String {
        return hours > 0 ?
            String(format: "%d:%02d:%02d",
                   hours, minute, second) :
            String(format: "%02d:%02d",
                   minute, second)
    }
    var positionalTimemilis: String {
        return hours > 0 ?
            String(format: "%d:%02d:%02d.%03d",
                   hours, minute, second,millisecondsInt) :
            String(format: "%02d:%02d.%03d",
                   minute, second,millisecondsInt)
    }
}
