//
//  SYShaders.metal
//  04_ComputeGray
//
//  Created by ShenYuanLuo on 2022/5/12.
//

#include <metal_stdlib>
#include "SYShaderTypes.h"

using namespace metal;

/// 光栅化数据结构
typedef struct {
    /// 裁剪空间位置
    float4 clipSpacePosition [[ position ]];    // position 修饰符表示这个是顶点
    /// 纹理坐标（会做插值处理）
    float2 textureCoordinate;
}ResterizerData;


/// 顶点着色器
vertex ResterizerData
VertexShader(uint vertexID [[ vertex_id ]], // vertex_id 是顶点着色器每次处理的 index，用于定位当前的顶点
             constant SYVertex *vertexArray [[ buffer(SYVertexInputIndexVertices) ]])   // buffer 表明是缓存数据，0 是索引
{
    ResterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}


/// 片段着色器
fragment float4
FragmentShader(ResterizerData  input        [[ stage_in ]], // stage_in 表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
               texture2d<half> textureColor [[ texture(0) ]])   // texture 表明是纹理数据，0 是索引
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);   // 纹理采样器
    
    half4 colorTex = textureColor.sample(textureSampler, input.textureCoordinate);  // 得到纹理对应位置的颜色
    
    return float4(colorTex);
}


constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722); // Rec.709标准：把rgba转成亮度值

kernel void // kernel 修饰的函数返回值必须是 void
ComputeGray(texture2d<half, access::read>  srcTexture  [[ texture(SYFragmentInputIndexTextureSrc) ]],
            texture2d<half, access::write> destTexture [[ texture(SYFragmentInputIndexTextureDest) ]],
            uint2                          grid        [[ thread_position_in_grid ]])
{
    // 注意边界保护
    if (grid.x <= destTexture.get_width() && grid.y <= destTexture.get_height()) {
        half4 originColor = srcTexture.read(grid);      // 读取输入纹理原始颜色值
        half gray = dot(originColor.rgb, kRec709Luma);  // 计算灰度值（亮度）
        destTexture.write(half4(gray, gray, gray, 1.0), grid);  // 写入输出纹理
    }
}
