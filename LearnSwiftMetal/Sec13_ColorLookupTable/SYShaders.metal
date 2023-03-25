//
//  SYShaders.metal
//  Sec13_ColorLookupTable
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

constant float SquareSize = 63.0 / 512.0;   // 一个正方形小个子在整个图片的纹理宽度


/// 顶点着色器
vertex RasterizerData
VertexShader(uint vertexID [[ vertex_id ]], // vertex_id 修饰表示这个是着色器每次处理的顶点下标（用于定位当前顶点）
             constant SYVertex* vertexArray [[ buffer(SYVertexInputIndexVertices) ]])   // buffer 表明是缓冲数据（SYVertexBufferIndexVertices 是索引）
{
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;    // 纹理坐标（会进行插值处理）
    return out;
}


/// 片段着色器
fragment float4
FragmentShader(RasterizerData input [[ stage_in ]], // stage_in 表示这个数据来自光栅化（光栅化是顶点处理后的步骤，业务层无法修改）
               texture2d<float> normalTexture [[ texture(SYFragmentTextureIndexNormal) ]],  // texture 表示是纹理数据（SYFragmentTextureIndexNormal 是索引）
               texture2d<float> lookupTableTexture [[ texture(SYFragmentTextureIndexLookupTable) ]])    // texture 表示是纹理数据（SYFragmentTextureIndexLookupTable 是索引）
{
    // 纹理采样器
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    // 读取原始纹理颜色
    float4 textureColor = normalTexture.sample(textureSampler, input.textureCoordinate);
    
    // 蓝色部分 [0, 63] 共 64 种
    float blueColor = textureColor.b * 63.0;
    
    // 为了有更好的过渡效果，每次计算的时候用相邻的结果进行线性结合
    // 第 1 个正方形位置（例如：blueColor = 22.5，则 y = 22/8 = 2, x = 22 - 2*2 = 6；即第 2 行，第 6 个正方形；y 是纵坐标）
    float2 quad1;
    quad1.y = floor(floor(blueColor) * 0.125);      // 1/8（每行 8 个小正方形）
    quad1.x = floor(blueColor) - (quad1.y * 8.0);   // 每行 8 个小正方形
    
    // 第 2 个正方形位置（同上）
    float2 quad2;
    quad2.y = floor(ceil(blueColor) * 0.125);       // 1/8（每行 8 个小正方形）
    quad2.x = ceil(blueColor) - (quad2.y * 8.0);   // （每行 8 个小正方形）
    
    /*
     quad1 是正方形的坐标，每个正方形占纹理大小的 1/8，即是 0.125，所以 quad1.x * 0.125 是算出正方形的左下角x坐标
     SquareSize 是 63/512，一个正方形小格子在整个图片的纹理宽度
     */
    // 计算颜色(r, g, b)在第 1 个正方形中的位置
    float2 texPos1;
    texPos1.x = (quad1.x * 0.125) + (SquareSize * textureColor.r);
    texPos1.y = (quad1.y * 0.125) + (SquareSize * textureColor.g);
    
    // 计算颜色(r, g, b)在第 2 个正方形中的位置
    float2 texPos2;
    texPos2.x = (quad2.x * 0.125) + (SquareSize * textureColor.r);
    texPos2.y = (quad2.y * 0.125) + (SquareSize * textureColor.g);
    
    float4 newColor1 = lookupTableTexture.sample(textureSampler, texPos1);  // 正方形 1 的颜色值
    float4 newColor2 = lookupTableTexture.sample(textureSampler, texPos2);  // 正方形 2 的颜色值
    float4 newColor  = mix(newColor1, newColor2, fract(blueColor));         // 根据小数点的部分进行 mix
    
    return float4(newColor.rgb, textureColor.w);    // 不修改 Alpha 值
}
