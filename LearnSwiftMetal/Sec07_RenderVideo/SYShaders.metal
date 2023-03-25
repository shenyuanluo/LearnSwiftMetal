//
//  SYShaders.metal
//  Sec07_RenderVideo
//
//  Created by ShenYuanLuo on 2022/5/25.
//

#include <metal_stdlib>
#import "SYShaderTypes.h"

using namespace metal;

/// 光栅化数据结构
typedef struct {
    /// 裁剪空间位置（position 修饰表示这个是顶点）
    float4 clipSpacePosition [[ position ]];
    /// 纹理坐标
    float2 textureCoordinate;
}RasterizerData;


/// 顶点着色器函数
vertex RasterizerData
VertexShader(uint vertexID [[ vertex_id ]], // vertex_id 是顶点着色器每次处理的 index，用于定位当前的顶点
             constant SYVertex* vertexArray [[ buffer(SYVertexInputIndexVertices) ]])   // buffer 修饰表示是缓冲数据，0 是顶点缓冲索引
{
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}


/// 片段着色器函数
fragment float4
FragmentShader(RasterizerData input [[ stage_in ]], // stage_in 表示数据来自光栅化（光栅化是顶点着色器处理后的数据，业务层无法修改）
               texture2d<float> textureY [[ texture(SYFragmentTextureIndexY) ]],    // texture 修饰表示是纹理，0 是 Y 纹理索引
               texture2d<float> textureUV [[ texture(SYFragmentTextureIndexUV) ]],  // texture 修饰表示是纹理，1 是 UV 纹理索引
               constant SYConvertMatrix* convertMatrix [[ buffer(SYFragmentBufferIndexMatrix) ]])   // buffer 修饰表示是缓冲数据，0 是矩阵缓冲索引
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);   // sampler 是纹理采样器
    float3 yuv = float3(textureY.sample(textureSampler, input.textureCoordinate).r,     // 采集 Y 纹理纹素颜色
                        textureUV.sample(textureSampler, input.textureCoordinate).rg);  // 采样 UV 纹理纹素颜色
    float3 rgb = convertMatrix->matrix * (yuv + convertMatrix->offset); // YUV 转换为 RGB
    return float4(rgb, 1.0);
}

