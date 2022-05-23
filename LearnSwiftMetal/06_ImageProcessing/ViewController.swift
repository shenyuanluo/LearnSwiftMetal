//
//  ViewController.swift
//  06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/17.
//

import UIKit

class ViewController: UIViewController {
    
    private var context: SYContext = SYContext()
    private var imageProvider: SYTextureProviderProtocol?
    private var desaturateFilter: SYSaturationFilter?
    private var blurFilter: SYGaussianBlurFilter?
    private var renderingQueue = DispatchQueue(label: "com.sy.rendering")
    private var jobIndex: UInt64 = 0
    
    private lazy var imageV: UIImageView = {
        let width = self.view.bounds.size.width
        let imgv = UIImageView(frame: CGRect(x: 0, y: 100, width: width, height: width))
        return imgv
    }()
    private lazy var blurLabel: UILabel = {
        let height          = self.view.bounds.size.height
        let label       = UILabel(frame: CGRect(x: 25, y: height - 150, width: 80, height: 20))
        label.text      = "高斯模糊"
        label.font      = .systemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()
    private lazy var blurSlider: UISlider = {
        let width = self.view.bounds.size.width
        let height          = self.view.bounds.size.height
        let slider          = UISlider(frame: CGRect(x: 100, y: height - 150, width: width - 120, height: 10))
        slider.value        = 1
        slider.minimumValue = 0
        slider.maximumValue = 7
        slider.addTarget(self, action: #selector(blurRadiusDidChange(_:)), for: .valueChanged)
        return slider
    }()
    private lazy var saturationLabel: UILabel = {
        let height          = self.view.bounds.size.height
        let label       = UILabel(frame: CGRect(x: 25, y: height - 100, width: 60, height: 20))
        label.text      = "饱和度"
        label.font      = .systemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()
    private lazy var saturationSlider: UISlider = {
        let width = self.view.bounds.size.width
        let height          = self.view.bounds.size.height
        let slider          = UISlider(frame: CGRect(x: 100, y: height - 100, width: width - 120, height: 10))
        slider.value        = 1
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.addTarget(self, action: #selector(saturationDidChange(_:)), for: .valueChanged)
        return slider
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configUI()
        self.buildFilterGraph()
        self.updateImage()
    }
    
    private func configUI() {
        self.view.addSubview(self.imageV)
        self.view.addSubview(self.blurLabel)
        self.view.addSubview(self.blurSlider)
        self.view.addSubview(self.saturationLabel)
        self.view.addSubview(self.saturationSlider)
    }

    private func buildFilterGraph() {
        self.imageProvider = SYTextureProvider(imageName: "Container.jpg", context: self.context)
        self.desaturateFilter = SYSaturationFilter(saturation: self.saturationSlider.value, context: self.context)
        self.desaturateFilter?.provider = self.imageProvider
        
        self.blurFilter = SYGaussianBlurFilter(radius: self.blurSlider.value, context: self.context)
        self.blurFilter?.provider = self.desaturateFilter
    }
    
    private func updateImage() {
        self.jobIndex += 1
        let curJobIndex = self.jobIndex
        let blurRadius = self.blurSlider.value
        let saturation = self.saturationSlider.value
        
        self.renderingQueue.async {
            if curJobIndex != self.jobIndex {
                return
            }
            self.blurFilter?.radius = blurRadius
            self.desaturateFilter?.saturationFactor = saturation
            
            if let texture = self.blurFilter?.texture,
               let img = UIImage.imageWith(texture: texture) {
                DispatchQueue.main.async {
                    self.imageV.image = img
                }
            }
        }
    }
    
    @objc private func blurRadiusDidChange(_ sender: UISlider) {
        self.updateImage()
    }
    
    @objc private func saturationDidChange(_ sender: UISlider) {
        self.updateImage()
    }

}

