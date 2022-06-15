//
//  SYShaders.metal
//  15_LoadingObjModel
//
//  Created by ShenYuanLuo on 2022/6/13.
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
VertexShader(SYVertex in [[ stage_in ]])
{
    RasterizerData out;
    out.position = vector_float4(in.position / 500.0f + float3(0, -0.3, 0), 1.0);
    out.texCoord = in.texCoord;
    return out;
}


/// 片段着色器
fragment half4
FragmentShader(RasterizerData in [[ stage_in ]],
               texture2d<half> baseColorMap [[ texture(SYTextureIndexColor) ]])
{
    constexpr sampler linearSampler(mip_filter::linear,
                                    mag_filter::linear,
                                    min_filter::linear,
                                    s_address::repeat,
                                    t_address::repeat);
    half4 colorSample = baseColorMap.sample(linearSampler, in.texCoord);
    return colorSample;
}
