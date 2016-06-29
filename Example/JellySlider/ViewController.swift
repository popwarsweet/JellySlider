//
//  ViewController.swift
//  JellySlider
//
//  Created by Kyle Zaragoza on 06/29/2016.
//  Copyright (c) 2016 Kyle Zaragoza. All rights reserved.
//

import UIKit
import JellySlider

class ViewController: UIViewController {

    /// Label which displays slider value.
    lazy var valueLabel: UILabel = { [unowned self] in
        let label = UILabel()
        label.font = UIFont.systemFontOfSize(130)
        label.textColor = self.uiTintColor
        label.textAlignment = .Center
        label.text = String(format: "%.2f", self.slider.value)
        label.alpha = 0.35
        return label
        }()
    
    /// Used as background layer.
    let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(hue:0.602006689, saturation:0.93, brightness:0.09, alpha:1.00).CGColor,
            UIColor(hue:0.676056338, saturation:0.93, brightness:0.2, alpha:1.00).CGColor
        ]
        layer.startPoint = CGPoint.zero
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()
    
    /// The beginning tint color for slider/label.
    let uiTintColor = UIColor(hue:0.94, saturation:0.93, brightness:0.86, alpha:1.00)
    
    /// The star!
    var slider: JellySlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // background style
        gradientLayer.frame = view.bounds
        view.layer.addSublayer(gradientLayer)
        
        // add slider
        let sliderFrame = CGRect(
            x: 12,
            y: view.bounds.height * 0.75,
            width: view.bounds.width - 24,
            height: 100)
        slider = JellySlider(frame: sliderFrame)
        slider.trackColor = uiTintColor
        slider.sizeToFit()
        view.addSubview(slider)
        
        // add label
        let labelFrame = CGRect(x: 0, y: 0, width: view.bounds.width, height: sliderFrame.maxY)
        valueLabel.frame = labelFrame
        
        // update hue on value change
        slider.onValueChange = { [unowned self] value in
            var hue: CGFloat = 0
            var sat: CGFloat = 0
            var bri: CGFloat = 0
            var alp: CGFloat = 0
            self.uiTintColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alp)
            
            let adjustedColor = UIColor(hue: value/1, saturation: sat, brightness: bri, alpha: alp)
            self.valueLabel.textColor = adjustedColor
            self.valueLabel.text = String(format: "%.2f", value)
            CATransaction.begin()
            CATransaction.setValue(true, forKey: kCATransactionDisableActions)
            self.slider.trackColor = adjustedColor
            CATransaction.commit()
        }
        
        view.addSubview(valueLabel)
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
}

