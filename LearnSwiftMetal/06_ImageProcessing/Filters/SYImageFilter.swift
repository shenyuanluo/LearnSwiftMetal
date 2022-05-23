//
//  SYImageFilter.swift
//  06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/18.
//

import Foundation
import Metal


/// 图像滤镜处理器
class SYImageFilter: SYTextureProviderProtocol, SYTextureConsumerProtocol {
    /// 上下文
    var context: SYContext
    /// Uniform 缓存
    var uniformBuffer: MTLBuffer?
    /// 是否需要滤镜处理
    var needApply: Bool = false
    /// 纹理提供
    var provider: SYTextureProviderProtocol?
    /// 纹理对象（实现）
    var texture: MTLTexture? {
        if self.needApply {
            self.applyFilter()
        }
        return self.outputTexture
    }
    
    private var pipeline: MTLComputePipelineState!  // 内核计算管线
    private var outputTexture: MTLTexture?          // 处理结果纹理
    private var kernelFunction: MTLFunction!        // 内核着色器函数
    
    init(funtionName: String, context: SYContext) {
        self.context = context
        guard let kernelFun = self.context.library.makeFunction(name: funtionName) else {
            print("Can not create kernel function.")
            return
        }
        self.kernelFunction = kernelFun
        do {
            // 创建内核计算管线（耗性能，不宜频繁操作）
            self.pipeline = try self.context.device.makeComputePipelineState(function: self.kernelFunction)
            self.needApply    = true
        } catch {
            print("Create compute pipeline failure.")
            return
        }
    }
    
    // MARK: 自定义参数处理
    func configArgumentTable(with encoder: MTLComputeCommandEncoder) {
        
    }
    
    
    // MARK: 开始滤镜处理
    private func applyFilter() {
        guard let inputTexture = self.provider?.texture else {  // 待处理输入纹理
            print("Did not provide texture.")
            return
        }
        if nil == self.outputTexture
            || self.outputTexture!.width != inputTexture.width
            || self.outputTexture!.height != inputTexture.height {    // 重新创建纹理
            let descriptor         = MTLTextureDescriptor()
            descriptor.pixelFormat = inputTexture.pixelFormat
            descriptor.width       = inputTexture.width
            descriptor.height      = inputTexture.height
            descriptor.usage       = MTLTextureUsage(rawValue: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue)  // 输出纹理需要「读写」权限
            self.outputTexture     = self.context.device.makeTexture(descriptor: descriptor)
        }
        let threadGroupSize  = MTLSize(width: 16, height: 16, depth: 1) // 每组线程数
        let threadGroupCount = MTLSize(width: (inputTexture.width  + threadGroupSize.width - 1) / threadGroupSize.width,
                                       height: (inputTexture.width  + threadGroupSize.width - 1) / threadGroupSize.width,
                                       depth: 1)    // 每个 grid 线程组数
        guard let commandBuffer = self.context.commandQueue.makeCommandBuffer() else {
            print("Crate command buffer failed.")
            return
        }
        commandBuffer.label = "SY-FilterCommand"
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Crate compute command encoder failed.")
            return
        }
        computeEncoder.label = "SY-ComputeEncoder"
        // 设置「计算」管线，以调用 shaders.metal 中的内核计算函数
        computeEncoder.setComputePipelineState(self.pipeline)
        // 设置「输入」纹理
        computeEncoder.setTexture(inputTexture, index: Int(SYTextureIndexInput.rawValue))
        // 设置「输出」纹理
        computeEncoder.setTexture(self.outputTexture, index: Int(SYTextureIndexOutput.rawValue))
        
        self.configArgumentTable(with: computeEncoder)
        
        // 设置计算区域
        computeEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
        // 调用 endEncoding 以释放编码器（这样下个 encoder 才可以创建）
        computeEncoder.endEncoding()
        
        commandBuffer.commit()  // 提交
        commandBuffer.waitUntilCompleted()  // 等待结果完成
    }
}
