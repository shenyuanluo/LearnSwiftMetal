//
//  SYShaders.metal
//  Sec10_MetalInteractGLES
//
//  Created by ShenYuanLuo on 2022/5/27.
//

#include <metal_stdlib>
#import "SYShaderTypes.h"

using namespace metal;

/// 光栅化数据结构体
typedef struct {
    /// 裁剪空间位置
    float4 clipSpacePosition [[ position ]];    // position 修饰表示这是个顶点
    /// 纹理坐标（会做插值处理）
    float2 textureCoordinate;
}RasterizerData;


/// 顶点着色器
vertex RasterizerData
VertexShader(uint vertexID [[ vertex_id ]], // vertex_id 修饰表示着色器每次处理的 index （用于定位当前的顶点）
             constant SYVertex* vertexArray [[ buffer(SYVertexInputIndexVertices) ]])   // buffer 修饰表示是数据缓存（SYVertexInputIndexVertices 是索引）
{
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    
    return out;
}


/// 片段着色器
fragment float4
FragmentShader(RasterizerData input [[ stage_in ]],             // stage_in 修饰表示这个数据来自光栅化（光栅化是顶点处理之后的步骤，业务层无法修改）
               texture2d<half> colorTexure [[ texture(0) ]])    // texture 修饰表示是纹理数据（0 是索引）
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);   // 纹理采样器
    
    half4 colorSample = colorTexure.sample(textureSampler, input.textureCoordinate);  // 采样纹素颜色
    return float4(colorSample);
}


/// 内核计算处理
kernel void
SobelCompute(texture2d<half, access::read>  srcTexture  [[ texture(SYComputeTextureIndexSrc) ]],    // 输入-纹理
             texture2d<half, access::write> destTexture [[ texture(SYComputeTextureIndexDest) ]],   // 输出-纹理
             uint2                          grid        [[ thread_position_in_grid ]],              // 当前处理线程在 grid 的位置
             device SYTransParam*           param       [[ buffer(0) ]])                            // param.kRec709Luma = half3(0.2126, 0.7152, 0.0722); 
{
    // 边界保护
    if (grid.x >= destTexture.get_width() || grid.y >= destTexture.get_height()) {
        return;
    }
    thread half4 color = srcTexture.read(grid); // 读取原始颜色
    thread half gray   = dot(color.rgb, half3(param->kRec709Luma)); // 转换成亮度
//    destTexture.write(half4(gray, gray, gray, 1.0), grid);  // 写到输出纹理中
    destTexture.write(color, grid);
}
