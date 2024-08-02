//
//  CameraCustomButton.swift
//  cameraMultiplePhotos
//
//  Created by matraex naren on 30/07/24.
//

import Foundation
import UIKit

@IBDesignable
open class CameraCustomButton: UIButton {
    
    // MARK: - Colors
    
    @IBInspectable
    public var photoColor: UIColor = .clear {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable
    public var videoColor: UIColor = .clear {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // MARK: - Ring
    
    @IBInspectable
    public var ringOffset: CGFloat = 3 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable
    public var ringLineWidth: CGFloat = 4 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable
    public var ringColor: UIColor = .white {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // MARK: Inner large circle
    
    @IBInspectable
    public var innerLargeCircleOffset: CGFloat = 8 {
        didSet {
            configureLayer()
        }
    }
    
    // MARK: - Inner small circle
    
    @IBInspectable
    public var innerSmallCircleOffset: CGFloat = 13 {
        didSet {
            configureLayer()
        }
    }
    
    // MARK: - Inner square
    
    @IBInspectable
    public var innerSquare: CGFloat = 17 {
        didSet {
            configureLayer()
        }
    }
    
    @IBInspectable
    public var squareCornerRadius: CGFloat = 8 {
        didSet {
            configureLayer()
        }
    }
    
    // MARK: - Properties
    // MARK: - Open properties
    
    override open var isSelected: Bool {
        didSet {
            let morph = CABasicAnimation(keyPath: "path")
            morph.duration = animateDuration
            morph.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            morph.toValue = currentInnerPath().cgPath
            morph.fillMode = .forwards
            morph.isRemovedOnCompletion = false
            pathLayer.add(morph, forKey: "")
            setNeedsDisplay()
        }
    }
    
    // MARK: - Public properties
    
    public var type: CameraType = .photo {
        didSet {
            pathLayer.removeAllAnimations()
            pathLayer.fillColor = configureColor().cgColor
            isSelected = false
        }
    }
    
    // MARK: - Private properties
    
    private let pathLayer = CAShapeLayer()
    private let animateDuration = 0.3
    private let colorChangeAnimator = CABasicAnimation(keyPath: "fillColor")
    
    // MARK: - UIButton life cycle
    
    public init() {
        super.init(frame: .zero)
        
        configureButton()
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        configureButton()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        configureButton()
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        
        addConstraint(NSLayoutConstraint(item: self,
                                         attribute: .width,
                                         relatedBy: .equal,
                                         toItem: nil,
                                         attribute: .width,
                                         multiplier: 1,
                                         constant: frame.width))
        addConstraint(NSLayoutConstraint(item: self,
                                         attribute: .height,
                                         relatedBy: .equal,
                                         toItem: nil,
                                         attribute: .width,
                                         multiplier: 1,
                                         constant: frame.height))
    }
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let ringRect = CGRect(x: ringOffset,
                              y: ringOffset,
                              width: frame.width - ringOffset * 2,
                              height: frame.height - ringOffset * 2)
        let outerRing = UIBezierPath(ovalIn: ringRect)
        outerRing.lineWidth = ringLineWidth
        ringColor.setStroke()
        outerRing.stroke()
        pathLayer.fillColor = configureColor().cgColor
    }
    
    // MARK: - Custom methos
    // MARK: - Private methods
    
    private func configureLayer() {
        pathLayer.removeAllAnimations()
        pathLayer.removeFromSuperlayer()
        pathLayer.path = currentInnerPath().cgPath
        pathLayer.strokeColor = nil
        layer.addSublayer(pathLayer)
    }
    
    private func configureButton() {
        configureLayer()
        setTitle("", for: .normal)
        tintColor = .clear
        addTarget(self, action: #selector(touchUpInside(_:)), for: .touchUpInside)
        addTarget(self, action: #selector(touchDown(_:)), for: .touchDown)
        addTarget(self, action: #selector(touchCancel(_:)), for: .touchDragExit)
    }
    
    private func currentInnerPath() -> UIBezierPath {
        return isSelected ? innerSquarePath() : innerCirclePath()
    }
    
    private func innerCirclePath() -> UIBezierPath {
        let rect = CGRect(x: innerLargeCircleOffset,
                          y: innerLargeCircleOffset,
                          width: frame.width - innerLargeCircleOffset * 2,
                          height: frame.height - innerLargeCircleOffset * 2)
        
        return UIBezierPath(roundedRect: rect, cornerRadius: rect.width / 2)
    }
    
    private func innerSquarePath() -> UIBezierPath {
        switch type {
        case .photo:
            let rect = CGRect(x: innerSmallCircleOffset,
                              y: innerSmallCircleOffset,
                              width: frame.width - innerSmallCircleOffset * 2,
                              height: frame.height - innerSmallCircleOffset * 2)
            
            return UIBezierPath(roundedRect: rect, cornerRadius: rect.width / 2)
        case .video:
            let rect = CGRect(x: innerCirclePath().currentPoint.x / 2,
                              y: innerCirclePath().currentPoint.x / 2,
                              width: frame.width / 2,
                              height: frame.height / 2)
            
            return UIBezierPath(roundedRect: rect, cornerRadius: squareCornerRadius)
        }
    }
    
    private func configureColor() -> UIColor {
        switch type {
        case .photo: return photoColor == .clear ? type.color : photoColor
        case .video: return videoColor == .clear ? type.color : videoColor
        }
    }
    
    // MARK: - Actions
    
    @objc private func touchCancel(_ sender: UIButton) {
        isSelected = !isSelected
        colorChangeAnimator.toValue = configureColor().cgColor
        pathLayer.add(colorChangeAnimator, forKey: "darkColor")
    }
    
    @objc private func touchDown(_ sender: UIButton) {
        colorChangeAnimator.duration = animateDuration
        colorChangeAnimator.toValue = type == .photo && photoColor == .clear ? UIColor.white.cgColor : configureColor().cgColor
        
        colorChangeAnimator.fillMode = .forwards
        colorChangeAnimator.isRemovedOnCompletion = false
        
        colorChangeAnimator.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pathLayer.add(colorChangeAnimator, forKey: "darkColor")
        if type == .photo {
            isSelected = !isSelected
        }
    }
    
    @objc private func touchUpInside(_ sender: UIButton) {
        colorChangeAnimator.duration = animateDuration
        colorChangeAnimator.toValue = configureColor().cgColor
        
        colorChangeAnimator.fillMode = .forwards
        colorChangeAnimator.isRemovedOnCompletion = false
        
        colorChangeAnimator.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pathLayer.add(colorChangeAnimator, forKey: "darkColor")
        isSelected = !isSelected
    }
    
}
public enum CameraType {
    
    case photo, video
    
    public var color: UIColor {
        switch self {
        case .photo: return UIColor(white: 1, alpha: 1.0)
        case .video: return .red
        }
    }
    
    public init(withValue value: Int) {
        switch value {
        case 0: self = .photo
        case 1: self = .video
        default: self = .photo
        }
    }
    
    public var index: Int {
        switch self {
        case .photo: return 0
        case .video: return 1
        }
    }
}
