//
//  BezierView.swift
//  BezierFun
//
//  Created by Kyle Zaragoza on 6/27/16.
//  Copyright © 2016 Kyle Zaragoza. All rights reserved.
//

import UIKit
import SpriteKit

public class JellySlider: UIView {
    
    // MARK: - Public Properties
    
    /// Closure called when user changes value
    public var onValueChange: ((value: CGFloat) -> Void)?
    /// Current value of slider. (ranges: 0-100)
    public var value: CGFloat {
        let trackLength = bounds.width - 2*edgeBoundaryPadding
        let touchMinusBoundary = bubbleCenterX - edgeBoundaryPadding
        return touchMinusBoundary/trackLength
    }
    /// Color of track.
    public var trackColor: UIColor = UIColor.blackColor() {
        didSet {
            shapeLayer.fillColor = trackColor.CGColor
        }
    }
    
    
    // MARK: - Private Properties
    
    /// Determines if bubble is showing above the track.
    private var bubbleHidden = true
    /// The max radius allowed (bubble radius is adjusted w/ force touch)
    private let maxBubbleRadius: CGFloat = 32
    /// The min radius allowed (bubble radius is adjusted w/ force touch)
    private let minBubbleRadius: CGFloat = 16
    /// Height of bubble peeking out of track when collapsed.
    private let peekingBubbleHeight: CGFloat = 4
    /// Radius of bubble when shown above the track.
    private var bubbleRadius: CGFloat = 16
    /// Height of track.
    private let trackHeight: CGFloat = 10
    /// Padding extended to the height of the view, to allow some leniency to touch handling.
    private let bottomTouchPadding: CGFloat = 16
    /// Padding used on either side of the track to restrict bubble from popping off track.
    // TODO: adjust curves of end caps when bubble extends to edge
    private var edgeBoundaryPadding: CGFloat {
        let trackRadius = trackHeight/2
        let minPadding = max(trackRadius, minBubbleRadius) + 10
        return minPadding
    }
    /// Touch position from touch handling event, protects againts `bubbleCenterX` being outside of the track.
    private var touchPositionX: CGFloat = 58 {
        didSet {
            let lerpX = abs((bubbleCenterX - touchPositionX)) * 0.18
            if touchPositionX < bubbleCenterX {
                bubbleCenterX = acceptableXPosition(bubbleCenterX - lerpX)
            } else {
                bubbleCenterX = acceptableXPosition(bubbleCenterX + lerpX)
            }
        }
    }
    /// Center position of the bubble. Updates UI on update.
    private var bubbleCenterX: CGFloat = 58 {
        didSet {
            // use newly generated path
            shapeLayer.path = path()
            
            // move bubble overlay
            let circleCenter = CGPoint(x: bubbleCenterX, y: 2*maxBubbleRadius - bubbleRadius)
            let circleWidth = bubbleRadius*1.2
            
            // we don't need to animate if already floating above the track (not hidden)
            let propertyChanges = {
                self.bubbleOverlay.bounds = CGRect(x: 0, y: 0, width: circleWidth, height: circleWidth)
                self.bubbleOverlay.position = circleCenter
                self.bubbleOverlay.cornerRadius = circleWidth/2
            }
            if bubbleOverlay.position.y < 2*maxBubbleRadius {
                CATransaction.begin()
                CATransaction.setValue(true, forKey: kCATransactionDisableActions)
                propertyChanges()
                CATransaction.commit()
            } else {
                propertyChanges()
            }
            
            // update listener
            onValueChange?(value: value)
        }
    }
    /// Layer which draws the bezier path to screen.
    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.blackColor().CGColor
        return layer
    }()
    /// Layer which is overlayed on bubble, for visual use only.
    private let bubbleOverlay: CALayer = {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        layer.cornerRadius = 8
        layer.backgroundColor = UIColor(white: 1, alpha: 0.35).CGColor
        return layer
    }()
    /// Sprite Kit view used for particles.
    private lazy var skView: SKView = { [unowned self] in
        let view = SKView(frame: self.bounds)
        view.backgroundColor = UIColor.clearColor()
        view.userInteractionEnabled = false
        return view
    }()
    /// Sprite Kit scene used for particles.
    private lazy var skScene: SKScene = { [unowned self] in
        let scene = SKScene(size: self.bounds.size)
        scene.backgroundColor = UIColor.clearColor()
        return scene
    }()
    
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // add sprite kit
        skView.frame = bounds
        addSubview(skView)
        skView.presentScene(skScene)
        // track layer
        shapeLayer.backgroundColor = UIColor.clearColor().CGColor
        layer.addSublayer(shapeLayer)
        shapeLayer.path = path()
        // bubble center layer
        shapeLayer.addSublayer(bubbleOverlay)
        // setup default location
        positionOverlayInTrack()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Animation
    
    private func animationIntoTrackAtPosition(x: CGFloat) {
        // animate path into track
        let animation = CABasicAnimation(keyPath: "path")
        animation.duration = 0.2
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        shapeLayer.addAnimation(animation, forKey: "pathAnimation")
        bubbleHidden = true
        touchPositionX = acceptableXPosition(x)
        bubbleCenterX = acceptableXPosition(x)
        
        // move down bubble overlay
        positionOverlayInTrack()
        
        // show particle
        // sprite kit uses gl coordinate space, we must flip
        let particleY = 2*maxBubbleRadius + 0.1*trackHeight
        skScene.addChild(self.splashParticle(CGPoint(x: bubbleCenterX, y: skView.bounds.height-particleY), color: trackColor))
    }
    
    private func positionOverlayInTrack() {
        let circleCenter = CGPoint(x: bubbleCenterX, y: 2*maxBubbleRadius + 0.5*trackHeight - 0.5*peekingBubbleHeight)
        bubbleOverlay.bounds = CGRect(x: 0, y: 0, width: 0.75*trackHeight, height: 0.75*trackHeight)
        bubbleOverlay.cornerRadius = bubbleOverlay.bounds.height/2
        bubbleOverlay.position = circleCenter
    }
    
    
    // MARK: - Path generation
    
    private func path() -> CGPath {
        let xMax = bounds.width
        let trackRadius = trackHeight/2
        let bezierPath = UIBezierPath()
        let bubbleYMax = 2*maxBubbleRadius
        let bubbleYMin = bubbleYMax - 2*bubbleRadius
        let bubbleYMid = bubbleYMin + bubbleRadius
        
        // left end of track
        bezierPath.moveToPoint(CGPoint(x: trackRadius, y: bubbleYMax))
        bezierPath.addCurveToPoint(CGPoint(x: 0, y: bubbleYMax+trackRadius),
                                   controlPoint1: CGPoint(x: trackRadius, y: bubbleYMax),
                                   controlPoint2: CGPoint(x: 0, y: bubbleYMax))
        
        bezierPath.addCurveToPoint(CGPoint(x: trackRadius, y: bubbleYMax+trackHeight),
                                   controlPoint1: CGPoint(x: 0, y: bubbleYMax+trackRadius),
                                   controlPoint2: CGPoint(x: 0, y: bubbleYMax+trackHeight))
        
        // bottom edge
        bezierPath.addLineToPoint(CGPoint(x: xMax-trackRadius, y: bubbleYMax+trackHeight))
        
        // right end of track
        bezierPath.addCurveToPoint(CGPoint(x: xMax, y: bubbleYMax+trackRadius),
                                   controlPoint1: CGPoint(x: xMax, y: bubbleYMax+trackHeight),
                                   controlPoint2: CGPoint(x: xMax, y: bubbleYMax+trackRadius))
        
        bezierPath.addCurveToPoint(CGPoint(x: xMax-trackRadius, y: bubbleYMax),
                                   controlPoint1: CGPoint(x: xMax, y: bubbleYMax),
                                   controlPoint2: CGPoint(x: xMax-trackRadius, y: bubbleYMax))
        
        // bubble
        if bubbleHidden {
            let maxRight = bubbleCenterX + minBubbleRadius
            let maxLeft = bubbleCenterX - minBubbleRadius
            let pointCount = 2
            let increment = (maxRight - maxLeft)/CGFloat(pointCount)
            bezierPath.addLineToPoint(CGPoint(x: xMax-trackRadius, y: bubbleYMax))
            bezierPath.addCurveToPoint(CGPoint(x: maxRight, y: bubbleYMax),
                                       controlPoint1: CGPoint(x: xMax-trackRadius, y: bubbleYMax),
                                       controlPoint2: CGPoint(x: maxRight, y: bubbleYMax))
            bezierPath.addCurveToPoint(CGPointMake(maxRight-increment, bubbleYMax-peekingBubbleHeight),
                                       controlPoint1: CGPoint(x: maxRight-peekingBubbleHeight, y: bubbleYMax),
                                       controlPoint2: CGPoint(x: maxRight-increment+peekingBubbleHeight*2, y: bubbleYMax-peekingBubbleHeight))
            
            bezierPath.addCurveToPoint(CGPoint(x: maxLeft, y: bubbleYMax),
                                       controlPoint1: CGPoint(x: maxRight-increment-peekingBubbleHeight*2, y: bubbleYMax-peekingBubbleHeight),
                                       controlPoint2: CGPoint(x: maxLeft+peekingBubbleHeight, y: bubbleYMax))
            bezierPath.addLineToPoint(CGPoint(x: trackRadius, y: bubbleYMax))
        } else {
            let innerPointDepth = bubbleRadius*0.285714286
            let outerControlPointDepth = bubbleRadius*0.642857143
            let innerControlPointDepth = bubbleRadius*0.928571429
            bezierPath.addLineToPoint(CGPoint(x: bubbleCenterX+bubbleRadius-innerPointDepth, y: bubbleYMax))
            bezierPath.addCurveToPoint(CGPoint(x: bubbleCenterX+bubbleRadius, y: bubbleYMid),
                                       controlPoint1: CGPoint(x: bubbleCenterX+bubbleRadius-innerControlPointDepth, y: bubbleYMax),
                                       controlPoint2: CGPoint(x: bubbleCenterX+bubbleRadius, y: bubbleYMid+outerControlPointDepth))
            bezierPath.addCurveToPoint(CGPoint(x: bubbleCenterX, y: bubbleYMin),
                                       controlPoint1: CGPoint(x: bubbleCenterX+bubbleRadius, y: bubbleYMin),
                                       controlPoint2: CGPoint(x: bubbleCenterX, y: bubbleYMin))
            bezierPath.addCurveToPoint(CGPoint(x: bubbleCenterX-bubbleRadius, y: bubbleYMid),
                                       controlPoint1: CGPoint(x: bubbleCenterX, y: bubbleYMin),
                                       controlPoint2: CGPoint(x: bubbleCenterX-bubbleRadius, y: bubbleYMin))
            bezierPath.addCurveToPoint(CGPoint(x: bubbleCenterX-bubbleRadius+innerPointDepth, y: bubbleYMax),
                                       controlPoint1: CGPoint(x: bubbleCenterX-bubbleRadius, y: bubbleYMid+outerControlPointDepth),
                                       controlPoint2: CGPoint(x: bubbleCenterX-bubbleRadius+innerControlPointDepth, y: bubbleYMax))
        }
        // close path
        bezierPath.addLineToPoint(CGPoint(x: trackRadius, y: bubbleYMax))
        return bezierPath.CGPath
    }
    
    
    // MARK: - Particles
    
    /// Sprite Kit particle shown after bubble dips back down into the track.
    private func splashParticle(center: CGPoint, color: UIColor) -> SKEmitterNode {
        let particle = SKEmitterNode(fileNamed: "SplashParticle")!
        particle.particleColor = color
        particle.particleColorBlendFactor = 1
        particle.particleColorSequence = nil
        particle.numParticlesToEmit = 4
        particle.position = center
        return particle
    }
    
    
    // MARK: - Layout
    
    override public func layoutSubviews() {
        skView.frame = CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height-bottomTouchPadding)
        skScene.size = skView.bounds.size
        shapeLayer.frame = bounds
    }
    
    override public func sizeThatFits(size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: 2*maxBubbleRadius + trackHeight + bottomTouchPadding)
    }
    
    private func acceptableXPosition(x: CGFloat) -> CGFloat {
        return min(max(x, edgeBoundaryPadding), bounds.width - edgeBoundaryPadding)
    }
    
    
    // MARK: - Touch handling
    
    override public func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.locationInView(self)
            let animation = CASpringAnimation(keyPath: "path")
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            shapeLayer.addAnimation(animation, forKey: "pathAnimation")
            bubbleHidden = false
            touchPositionX = location.x
        }
    }
    
    override public func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            // check if we have force touch, adjust bubble radius to match force
            if traitCollection.forceTouchCapability == .Available {
                let forceValue = min(6, max(1, touch.force))
                let normalForceValue = (forceValue-1)/5
                let additionalValue = normalForceValue * (maxBubbleRadius - minBubbleRadius)
                bubbleRadius = minBubbleRadius + additionalValue
            }
            // update our touch position
            let location = touch.locationInView(self)
            touchPositionX = location.x
        }
    }
    
    override public func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.locationInView(self)
            animationIntoTrackAtPosition(location.x)
        }
    }
    
    override public func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        animationIntoTrackAtPosition(bubbleCenterX)
    }
}