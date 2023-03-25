//
//  SYShaders.metal
//  Sec06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/18.
//

#include <metal_stdlib>
#include "SYShaderTypes.h"

using namespace metal;


// 饱和度处理
kernel void
SaturationAdjust(texture2d<float, access::read> inTexture [[ texture(SYTextureIndexInput) ]],     // 输入纹理
                 texture2d<float, access::write> outTexture [[ texture(SYTextureIndexOutput) ]],   // 输出纹理
                 constant AdjustSaturationUniforms &uniforms [[ buffer(0) ]],   // 模糊因子
                 uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = inTexture.read(gid);   // 读取原始颜色
    float value    = dot(inColor.rgb, float3(0.299, 0.587, 0.114)); // 计算饱和度
    
    float4 grayColor(value, value, value, 1.0);
    float4 outColor = mix(grayColor, inColor, uniforms.saturationFactor);   // 混合颜色
    
    outTexture.write(outColor, gid);
}


// 高斯模糊处理
kernel void
GaussianBlur2D(texture2d<float, access::read> inTexture [[ texture(SYTextureIndexInput) ]],   // 输入纹理
               texture2d<float, access::write> outTexture [[ texture(SYTextureIndexOutput) ]], // 输出纹理
               texture2d<float, access::read> weights [[ texture(2) ]],     // 权重纹理
               uint2 gid [[ thread_position_in_grid ]]) // 线程位置
{
    int size   = weights.get_width();
    int radius = size / 2;
    
    float4 accumColor(0, 0, 0, 0);
    for (int j = 0; j < size; ++j)
    {
        for (int i = 0; i < size; ++i)
        {
            uint2 kernelIndex(i, j);
            uint2 textureIndex(gid.x + (i - radius), gid.y + (j - radius));
            
            float4 color  = inTexture.read(textureIndex).rgba;
            float4 weight = weights.read(kernelIndex).rrrr;
            accumColor   += weight * color;
        }
    }
    
    outTexture.write(float4(accumColor.rgb, 1), gid);
}

