//
//  SYMetalRotater.swift
//  Sec22_RotateArray
//
//  Created by ShenYuanLuo on 2023/4/6.
//

import Foundation
import Metal

class SYMetalRotater {
    static var device: MTLDevice!               // 用来计算的设备（即，GPU；一般一个 APP 只用一个对象，所以设置为“类对象”）
    static var commandQueue: MTLCommandQueue!   // 命令队列（控制渲染命令按部就班执行；一般一个 APP 只用一个对象，所以设置为“类对象”）
    static var library: MTLLibrary!             // 着色器源代码程序（从 Bundle 加载所有着色器文件（.metal），一般一个 APP 只用一个对象，所以设置为“类对象”）
    
    private var rotateArrayPipeline: MTLComputePipelineState!   // 旋转数组-内核计算关系
    private var rotateNV12Pipeline: MTLComputePipelineState!    // 旋转NV12-内核计算管线
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary() else {
            fatalError("GPU not available")
        }
        SYMetalRotater.device       = device
        SYMetalRotater.commandQueue = commandQueue
        SYMetalRotater.library      = library
        
        // 创建内核计算函数
        guard let rotateArrayFun = library.makeFunction(name: "RotateArray"),
              let rotateNV12Fun = library.makeFunction(name: "RotateNV12") else {
            fatalError("Can't crate kernel compute funtions")
        }
        do {    // 创建内核计算管线（耗性能，不宜频繁操作）
            self.rotateArrayPipeline = try device.makeComputePipelineState(function: rotateArrayFun)
            self.rotateNV12Pipeline  = try device.makeComputePipelineState(function: rotateNV12Fun)
        } catch let error {
            print("Create rotate-array pipeline error: \(error.localizedDescription)")
        }
    }
    
    /// 旋转数组
    /// - Parameters:
    ///   - data: 数组缓存
    ///   - row: 数组-行数
    ///   - col: 数组-列数
    ///   - isRight: 是否向右旋转（0：向左，1：向右；旋转 90度）
    ///   - completion: 结果回调
    func rotateArray(data: [Float], row: Int, col: Int, isRight: Int, completion: @escaping((UnsafeMutableRawPointer?) -> ())) {
        var row      = row
        var col      = col
        var isRight  = isRight
        let arrayLen = data.count
        let inBuff   = SYMetalRotater.device.makeBuffer(bytes: data,
                                                       length: MemoryLayout<Float>.size * arrayLen,
                                                       options: .storageModeShared)     // 使用共享内存（CPU 和 GPU都可以访问）
        inBuff?.label = "rotate_array_inBuff"
        let outBuffer = SYMetalRotater.device.makeBuffer(length: MemoryLayout<Float>.size * arrayLen,
                                                         options: .storageModeShared)    // 使用共享内存（CPU 和 GPU都可以访问）
        outBuffer?.label = "rotate_array_outBuff"

        guard let commandBuffer = SYMetalRotater.commandQueue.makeCommandBuffer(),  // 创建命令缓存
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { // 创建命令编码器
            print("Create command buffer or encoder failure.")
            return
        }
        computeEncoder.setComputePipelineState(self.rotateArrayPipeline)    // 设置内核计算管线（以调用 shaders.metal 中的内核计算函数）
        // 写入数据
        computeEncoder.setBytes(&row, length: MemoryLayout<Int>.stride, index: 11)      // 数组-行数
        computeEncoder.setBytes(&col, length: MemoryLayout<Int>.stride, index: 12)      // 数组-列数
        computeEncoder.setBytes(&isRight, length: MemoryLayout<Int>.stride, index: 13)  // 数组-旋转方向
        computeEncoder.setBuffer(inBuff, offset: 0, index: 0)       // 原始数组缓存
        computeEncoder.setBuffer(outBuffer, offset: 0, index: 1)    // 结果数组缓存

#if true
        let gridSize   = MTLSize(width: data.count, height: 1, depth: 1)    // GPU 内核计算网格大小
        var maxThreads = self.rotateArrayPipeline.maxTotalThreadsPerThreadgroup // 每组最大线程数
        if maxThreads > arrayLen {
            maxThreads = arrayLen
        }
        let threadSize = MTLSize(width: maxThreads, height: 1, depth: 1)    // 线程大小
        // 设置计算区域（使用非均匀线程组的网格编码计算命令,该方法能够更有效的利用GPU资源， 但是该方法最低支持到A11处理器(芯片)）
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadSize) // 注意：模拟器不支持
#else
        // 使用均匀线程组边界的网格编码计算命令（shader 内部需要判断 thread pos 越界问题）
        let execWidth  = self.rotateArrayPipeline.threadExecutionWidth
        let threadSize = MTLSize(width: execWidth, height: 1, depth: 1)   // 一维数据 height、depth 都是 1
        let groupSize  = MTLSize(width: (arrayLen + execWidth - 1) / execWidth, height: 1, depth: 1)   // 一维数据 height、depth 都是 1
        computeEncoder.dispatchThreadgroups(groupSize, threadsPerThreadgroup: threadSize)
#endif

        // 设置处理完成回调
        commandBuffer.addCompletedHandler { buff in
            completion(outBuffer?.contents())
        }
        // 结束编码过程以关闭计算传递
        computeEncoder.endEncoding()
        // 交命令缓冲区后，Metal 会异步准备执行的命令，然后调度命令缓冲区在 GPU 上执行。
        // 当 GPU 执行完命令缓冲区中的所有命令后，将命令缓冲区标记为完成。
        commandBuffer.commit()
    }
    
    
    /// 旋转 YUV-nv12 图像
    /// - Parameters:
    ///   - data: yuv 数据
    ///   - width: 图像-宽度
    ///   - height: 图像-高度
    ///   - isRight: 是否向右旋转（0：向左，1：向右；旋转 90度）
    ///   - completion: 结果回调
    func rotateNV12(data: UnsafeRawPointer, width: Int, height: Int, isRight: Int, completion: @escaping((UnsafeMutableRawPointer?) -> ())) {
        var width     = width
        var height    = height
        let dataSize  = Int(Float(width * height) * 1.5)
        var isRight   = isRight
        let inYUVBuff = SYMetalRotater.device.makeBuffer(bytes: data,
                                                        length: MemoryLayout<UInt8>.size * dataSize,
                                                        options: .storageModeShared)    // 使用共享内存（CPU 和 GPU都可以访问）
        inYUVBuff?.label = "rotate_nv12_inYUV"
        let outYUVBuff = SYMetalRotater.device.makeBuffer(length: MemoryLayout<UInt8>.size * dataSize,
                                                         options: .storageModeShared)   // 使用共享内存（CPU 和 GPU都可以访问）
        outYUVBuff?.label = "rotate_nv12_outYUV"
        guard let commandBuffer = SYMetalRotater.commandQueue.makeCommandBuffer(),   // 创建命令缓存
            let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {    // 创建命令编码器
            print("Can not execute compute.")
            return
        }
        computeEncoder.setComputePipelineState(self.rotateNV12Pipeline) // 设置内核计算管线
        computeEncoder.setBytes(&width, length: MemoryLayout<Int>.stride, index: 11)    // 图像-宽度
        computeEncoder.setBytes(&height, length: MemoryLayout<Int>.stride, index: 12)   // 图像-高度
        computeEncoder.setBytes(&isRight, length: MemoryLayout<Int>.stride, index: 13)  // 图像-旋转方向
        computeEncoder.setBuffer(inYUVBuff, offset: 0, index: 0)    // 原始图像数据缓存
        computeEncoder.setBuffer(outYUVBuff, offset: 0, index: 1)   // 结果图像数据缓存
        
#if true
        let gridSize   = MTLSize(width: dataSize, height: 1, depth: 1)  // GPU 内核计算网格大小
        var maxThreads = self.rotateNV12Pipeline.maxTotalThreadsPerThreadgroup  // 每组最大线程数
        if maxThreads > dataSize {
            maxThreads = dataSize
        }
        let threadSize = MTLSize(width: maxThreads, height: 1, depth: 1)    // 线程大小
        // 使用非均匀线程组的网格编码计算命令,该方法能够更有效的利用GPU资源， 但是该方法最低支持到A11处理器(芯片)
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadSize) // 注意：模拟器不支持
#else
        // 使用均匀线程组边界的网格编码计算命令（shader 内部需要判断 thread pos 越界问题）
        let execWidth  = self.rotateNV12Pipeline.threadExecutionWidth
        let threadSize = MTLSize(width: execWidth, height: 1, depth: 1)   // 一维数据 height、depth 都是 1
        let groupSize  = MTLSize(width: (dataSize + execWidth - 1) / execWidth, height: 1, depth: 1)   // 一维数据 height、depth 都是 1
        computeEncoder.dispatchThreadgroups(groupSize, threadsPerThreadgroup: threadSize)
#endif

        // 设置处理完成回调
        commandBuffer.addCompletedHandler { buff in
            completion(outYUVBuff?.contents())
        }

        computeEncoder.endEncoding()
        commandBuffer.commit()
    }
}

