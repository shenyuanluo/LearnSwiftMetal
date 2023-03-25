//
//  ViewController.swift
//  Sec18_SpecularReflection
//
//  Created by ShenYuanLuo on 2022/6/16.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    private var mtkView: MTKView!
    private var renderer: SYRenderer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mtkView        = MTKView(frame: self.view.bounds)
        self.mtkView.device = MTLCreateSystemDefaultDevice()
        if nil == self.mtkView.device { // 设备不支持 Metal
            print("Metal is not support on this device.")
            return
        }
        self.view.insertSubview(self.mtkView, at: 0)
        self.renderer = SYRenderer(mtkView: self.mtkView)
        self.renderer.mtkView(self.mtkView, drawableSizeWillChange: self.mtkView.bounds.size)
        self.mtkView.delegate = self.renderer
    }


}

