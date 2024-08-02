//
//  ImageStackView.swift
//  cameraMultiplePhotos
//
//  Created by matraex naren on 01/08/24.
//

import Foundation
import UIKit
import AVFoundation

class ImageStackView: UIView {
    
    // MARK: - Initialization
    public var sepeatorDistance : CGFloat = 4
    var imageArray = [UIImage]()
    var videoUrlArray = [URL]()
    var cardCount: CGFloat = 0
    var bufferSize:CGFloat = 10
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        //initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        //initialize()
    }
    func addImageCard(imageData:Data)
    {
        var xPosition = cardCount * sepeatorDistance
        var yPosition = (bufferSize - cardCount) * sepeatorDistance
        if bufferSize - cardCount < 1
        {
            yPosition =  sepeatorDistance
            xPosition = bufferSize * sepeatorDistance
        }
        let cardSize = bounds.size.width - (bufferSize * sepeatorDistance)
        let card = UIImageView(frame: CGRect(x: xPosition, y: yPosition, width: cardSize, height: cardSize))
        if let image = UIImage(data: imageData)
        {
            self.imageArray.append(image)
            card.image = image
        }
        card.layer.cornerRadius = 8
        card.clipsToBounds = true
        card.layer.shadowOpacity = 0.5
        card.layer.shadowOffset = CGSize(width: 1.0, height: 1.0)
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.masksToBounds = false
        cardCount += 1
        self.addSubview(card)
    }
    func addVideoCard(videoUrl:URL)
    {
        var xPosition = cardCount * sepeatorDistance
        var yPosition = (bufferSize - cardCount) * sepeatorDistance
        if bufferSize - cardCount < 1
        {
            yPosition =  sepeatorDistance
            xPosition = bufferSize * sepeatorDistance
        }
        let cardSize = bounds.size.width - (bufferSize * sepeatorDistance)
        let card = UIImageView(frame: CGRect(x: xPosition, y: yPosition, width: cardSize, height: cardSize))
        self.imagePreview(from: videoUrl, in: 0.0, completion: { image in
            if let image
            {
                self.imageArray.append(image)
                card.image = image
            }
        })
        cardCount += 1
        card.layer.cornerRadius = 8
        card.clipsToBounds = true
        card.layer.shadowOpacity = 0.5
        card.layer.shadowOffset = CGSize(width: 1.0, height: 1.0)
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.masksToBounds = false
        self.videoUrlArray.append(videoUrl)
        self.addSubview(card)
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
