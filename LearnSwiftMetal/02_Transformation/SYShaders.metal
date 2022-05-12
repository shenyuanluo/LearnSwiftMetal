//
//  SYShaders.metal
//  02_Transformation
//
//  Created by ShenYuanLuo on 2022/5/10.
//

#include <metal_stdlib>
#import "SYShaderTypes.h"

using namespace metal;

/// 光栅化数据结构
typedef struct {
    /// 裁剪空间位置
    float4 clipSpacePosition [[ position ]];
    /// 像素颜色
    float3 pixelColor;
    /// 纹理坐标
    float2 textureCoordinate;
}ResterizerData;


/// 顶点着色器
vertex ResterizerData
VertexShader(uint vertexID [[ vertex_id ]],
             constant SYVertex *vertexArray [[ buffer(SYVertexInputIndexVertices) ]],
             constant SYMatrix *matrix [[ buffer(SYVertexInputIndexMatrix) ]])
{
    ResterizerData out;
    out.clipSpacePosition = matrix->projectionMatrix * matrix->modelViewMatrix * vertexArray[vertexID].position;
    out.pixelColor        = vertexArray[vertexID].color;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}


/// 片段着色器
fragment float4
FragmentShader(ResterizerData input [[ stage_in ]],
               texture2d<half> textureColor [[ texture(SYFragmentInputIndexTexture) ]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    half4 colorTex = textureColor.sample(textureSampler, input.textureCoordinate);
//    half4 colorTex = half4(input.pixelColor.x, input.pixelColor.y, input.pixelColor.z, 1);
    
    return float4(colorTex);
}
