//
//  SYContext.swift
//  06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/17.
//

import Foundation
import Metal

class SYContext {
    var device: MTLDevice!              // 用来渲染的设备（即，GPU）
    var library: MTLLibrary!            // 着色器集合库
    var commandQueue: MTLCommandQueue!  // 命令队列（控制渲染命令按部就班执行）
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {    // 设备不支持 Metal
            print("Metal is not support on this device.")
            return
        }
        // 从 Bundle 加载所有着色器文件（.metal）
        guard let library = device.makeDefaultLibrary() else {
            print("Can not create (.metal) library.")
            return
        }
        guard let commandQueue = device.makeCommandQueue() else {
            print("Can not create command queue.")
            return
        }
        self.device       = device
        self.library      = library
        self.commandQueue = commandQueue
    }
}
