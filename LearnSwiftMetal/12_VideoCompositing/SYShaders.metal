//
//  SYShaders.metal
//  12_VideoCompositing
//
//  Created by ShenYuanLuo on 2022/6/8.
//

#include <metal_stdlib>
#import "SYShaderTypes.h"

using namespace metal;


/// 光栅化结果数据结构体
typedef struct {
    /// 裁剪空间位置
    float4 clipSpacePosition [[ position ]];    // position 修饰表示这个是顶点
    /// 纹理-坐标（会做插值处理）
    float2 textureCoordinate;
}RasterizerData;

constant float3 greenMaskColor = float3(0.0, 1.0, 0.0); // 过滤掉绿色


/// 片段着色器
vertex RasterizerData
VertexShader(uint vertexID [[ vertex_id ]], // vertex_id 修饰表示这个是着色器每次处理的顶点下标（用于定位当前顶点）
             constant SYVertex *vertexArray [[ buffer(SYVertexInputIndexVertices) ]])   // buffer 表明是缓冲数据（SYVertexBufferIndexVertices 是索引）
{
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;    // 纹理坐标（会进行插值处理）
    return out;
}


/// 片段着色器
fragment float4
FragmentShader(RasterizerData input [[ stage_in ]], // stage_in 表示这个数据来自光栅化（光栅化是顶点处理后的步骤，业务层无法修改）
               texture2d<float> greenTextureY [[ texture(SYFragmentTextureIndexGreenTextureY) ]],   // texture 表示是纹理数据（SYFragmentTextureIndexGreenTextureY 是索引）
               texture2d<float> greenTextureUV [[ texture(SYFragmentTextureIndexGreenTextureUV) ]], // texture 表示是纹理数据（SYFragmentTextureIndexGreenTextureUV 是索引）
               texture2d<float> normalTextureY [[ texture(SYFragmentTextureIndexNormalTextureY) ]], // texture 表示是纹理数据（SYFragmentTextureIndexNormalTextureY 是索引）
               texture2d<float> normalTextureUV [[ texture(SYFragmentTextureIndexNormalTextureUV) ]], // texture 表示是纹理数据（SYFragmentTextureIndexNormalTextureUV 是索引）
               constant SYConvertMatrix *convertMatrix [[ buffer(SYFragmentBufferIndexMatrix) ]])   // buffer表明是缓存数据（SYFragmentBufferIndexMatrix 是索引）
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear); // 纹理采样器
    
    /*
     RGB ——> YUV BT.601
     
     | Y |      | 0.299     0.587     0.114   |   | R |
     | U |  =   |-0.14713  -0.28886   0.436   | x | G |
     | V |      | 0.615    -0.51499  -0.10001 |   | B |
     
     
     RGB ——> YUV BT.601（FullRange）
     
     | Y |      | 0.257   0.504   0.098 |   | R |
     | U |  =   |-0.148  -0.291   0.439 | x | G |
     | V |      | 0.439  -0.368  -0.071 |   | B |
     */
    float maskY    =  0.257 * greenMaskColor.r + 0.504 * greenMaskColor.g + 0.098 * greenMaskColor.b;
    float maskU    = -0.148 * greenMaskColor.r - 0.291 * greenMaskColor.g + 0.439 * greenMaskColor.b;
    float maskV    =  0.439 * greenMaskColor.r - 0.368 * greenMaskColor.g - 0.071 * greenMaskColor.b;
    float3 maskYUV = float3(maskY, maskU, maskV) + float3(16.0 / 255.0, 0.5, 0.5);
    
    // 绿幕视频读取出来的图像（YUV-颜色空间）
    float3 greenVideoYUV = float3(greenTextureY.sample(textureSampler, input.textureCoordinate).r,
                                  greenTextureUV.sample(textureSampler, input.textureCoordinate).rg);
    // YUV 转成 RGB
    float3 greenVideoRGB = convertMatrix->matrix * (greenVideoYUV + convertMatrix->offset);
    
    // 正常视频读取出来的图像（YUV-颜色空间）
    float3 normalVideoYUV = float3(normalTextureY.sample(textureSampler, input.textureCoordinate).r,
                                   normalTextureUV.sample(textureSampler, input.textureCoordinate).rg);
    // YUV 转成 RGB
    float3 normalVideoRGB = convertMatrix->matrix * (normalVideoYUV + convertMatrix->offset);
    
    // 计算需要替换的值
    float blendValue = smoothstep(0.1, 0.3, distance(maskYUV.yz, greenVideoYUV.yz));
    
    // 混合两个图像
    return float4(mix(normalVideoRGB, greenVideoRGB, blendValue), 1.0); // blendValue = 0，表示接近绿色，取 normalColor；
}


