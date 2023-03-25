//
//  SYSaturationFilter.swift
//  Sec06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/18.
//

import Foundation
import Metal


/// MARK: 饱和度滤镜处理器
class SYSaturationFilter: SYImageFilter {
    /// 饱和度比例因子
    var saturationFactor: Float = 1 {
        willSet {
            self.needApply = true
        }
    }
    
    init(saturation: Float, context: SYContext) {
        super.init(funtionName: "SaturationAdjust", context: context)
        self.saturationFactor = saturation
    }
    
    
    override func configArgumentTable(with encoder: MTLComputeCommandEncoder) {
        var unifor = AdjustSaturationUniforms(saturationFactor: self.saturationFactor)
        
        if nil == self.uniformBuffer {
            guard let buffer = self.context.device.makeBuffer(length: MemoryLayout<AdjustSaturationUniforms>.size,
                                                              options: .cpuCacheModeWriteCombined) else {
                print("Create saturation factor buffer failed.")
                return
            }
            self.uniformBuffer = buffer
        }
        memcpy(self.uniformBuffer!.contents(), &unifor, MemoryLayout<AdjustSaturationUniforms>.size)
        encoder.setBuffer(self.uniformBuffer, offset: 0, index: 0)
    }
}
