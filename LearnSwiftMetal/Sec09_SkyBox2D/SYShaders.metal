//
//  SYShaders.metal
//  Sec09_SkyBox2D
//
//  Created by ShenYuanLuo on 2022/5/26.
//

#include <metal_stdlib>
#import "SYShaderTypes.h"

using namespace metal;

/// 光栅化结果数据
typedef struct {
    /// 顶点位置
    float4 clipSpacePosition [[ position ]];
    /// 像素颜色
    float3 pixelColor;
    /// 纹理坐标
    float2 textureCoordinate;
}RasterizerData;


/// 顶点着色器
vertex RasterizerData
VertexShader(uint vertexID [[ vertex_id ]], // 顶点索引
             constant SYVertex* vertexArray [[ buffer(SYVertexInputIndexVertices) ]],   // 顶点数据
             constant SYMatrix* matrix [[ buffer(SYVertexInputIndexMatrix) ]])  // 变化矩阵
{
    RasterizerData out;
    out.clipSpacePosition = matrix->projection * matrix->modelView * vertexArray[vertexID].position;    // 变换处理
    out.pixelColor        = vertexArray[vertexID].color;    // 顶点颜色（方便调试）
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;    // 纹理坐标
    return out;
}


/// 片段着色器
fragment float4
FragmentShader(RasterizerData input [[ stage_in ]],
               texture2d<half> textureColor [[ texture(SYFragmentInputIndexTexture) ]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);   // 纹理采样器
    
    half4 colorTex = textureColor.sample(textureSampler, input.textureCoordinate);   // 采样纹理颜色
//    half4 colorTex = half4(input.pixelColor.r, input.pixelColor.g, input.pixelColor.b, 1);    // 顶点颜色（用于调试）
    
    return float4(colorTex);
}
