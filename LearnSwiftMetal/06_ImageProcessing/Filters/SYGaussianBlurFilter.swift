//
//  SYGaussianBlur2DFilter.swift
//  06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/18.
//

import Foundation
import Metal


/// 高斯模糊滤镜处理器
class SYGaussianBlurFilter: SYImageFilter {
    /// 模糊半径
    var radius: Float = 1 {
        willSet {
            self.sigma             = newValue / 2
            self.needApply         = true
            self.blurWeightTexture = nil
        }
    }
    /// 模糊参数
    var sigma: Float = 0 {
        willSet {
            self.needApply         = true
            self.blurWeightTexture = nil
        }
    }
    
    private var blurWeightTexture: MTLTexture?  /// 模糊权重纹理
    
    init(radius: Float, context: SYContext) {
        
        super.init(funtionName: "GaussianBlur2D", context: context)
        self.radius = radius
    }
    
    // 创建模糊权重纹理
    private func generateBlurWeightTexture() {
        assert(self.radius >= 0, "Blur radius must be non-negative")
        
        let radius: Float   = self.radius   // 模糊半径（如：0~7）
        let sigma: Float    = self.sigma
        let size:Int        = Int((round(radius) * 2) + 1)
        var delta: Float    = 0
        var expScale: Float = 0
        
        if (0.0 < radius)
        {
            if 1 == size {
                delta = MAXFLOAT * 0.5
            } else {
                delta = Float((Int(radius) * 2) / (size - 1))
            }
            expScale = Float(Int(-1 / (2 * sigma * sigma)))
        }
        var weights: [Float] = [Float](repeating: 0, count: size * size)
        
        var weightSum: Float = 0
        var y = -radius
        for j in 0..<size {
            var x = -radius
            for i in 0..<size {
                let weight            = expf((x * x + y * y) * expScale)    // 求取 e 的 x 次幂
                weights[j * size + i] = weight
                weightSum            += weight
                x                    += delta
            }
            y += delta
        }

        let weightScale: Float = 1 / weightSum
        for j in 0..<size {
            for i in 0..<size {
                let weight            = weights[j * size + i]
                weights[j * size + i] = weight * weightScale
            }
        }
        // 纹理描述符
        let descriptor         = MTLTextureDescriptor()
        descriptor.pixelFormat = .r32Float      // 纹理-像素格式
        descriptor.width       = size           // 纹理-宽度
        descriptor.height      = size           // 纹理-高度
        descriptor.usage       = .shaderRead    // 纹理-「读」权限

        // 创建纹理
        guard let texture = self.context.device.makeTexture(descriptor: descriptor) else {
            print("Create blur weight texture failed.")
            return 
        }
        self.blurWeightTexture = texture
        // 纹理上传范围
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: size, height: size, depth: 1))
        // 拷贝图像数据到纹理
        self.blurWeightTexture?.replace(region: region,
                                        mipmapLevel: 0,
                                        withBytes: weights,
                                        bytesPerRow: MemoryLayout<Float>.size * size)
    }
    
    // 自定义参数处理
    override func configArgumentTable(with encoder: MTLComputeCommandEncoder) {
        if nil == self.blurWeightTexture {
            self.generateBlurWeightTexture()
        }
        encoder.setTexture(self.blurWeightTexture, index: 2)
    }
}
