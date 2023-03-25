//
//  SYShaders.metal
//  Sec16_UniformBuffer
//
//  Created by ShenYuanLuo on 2022/6/15.
//

#include <metal_stdlib>
#include "SYShaderTypes.h"

using namespace metal;


/// 顶点结构体（和 VertexDescriptor 中描述的一致）
typedef struct {
    /// 位置
    float3 position [[ attribute(0) ]];
    /// 纹理坐标
    float2 texCoord [[ attribute(1) ]];
}SYVertex;


/// 光栅化结果数据结构体
typedef struct {
    /// 裁剪空间位置
    float4 position [[ position ]];    // position 修饰表示这个是顶点
    /// 纹理-坐标（会做插值处理）
    float2 texCoord;
}RasterizerData;


/// 顶点着色器
vertex RasterizerData
VertexShader(SYVertex input [[ stage_in ]],
             constant SYUniforms & uniforms [[ buffer(SYBufferIndexUniform) ]])
{
    RasterizerData out;
    float4 position = float4(input.position, 1.0);
    out.position    = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord    = input.texCoord;
    return out;
}


/// 片段着色器
fragment half4
FragmentShader(RasterizerData input [[ stage_in ]],
               texture2d<half> baseColorMap [[ texture(SYTextureIndexColor) ]])
{
    // 纹理采样器
    constexpr sampler linearSampler(mip_filter::linear,
                                    mag_filter::linear,
                                    min_filter::linear,
                                    s_address::repeat,
                                    t_address::repeat);
    half4 colorSample = baseColorMap.sample(linearSampler, input.texCoord);
    return colorSample;
}
