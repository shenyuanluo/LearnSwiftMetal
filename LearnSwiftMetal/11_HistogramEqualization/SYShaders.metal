//
//  SYShaders.metal
//  11_HistogramEqualization
//
//  Created by ShenYuanLuo on 2022/5/30.
//

#include <metal_stdlib>
#import "SYShaderTypes.h"

using namespace metal;


/// 颜色缓存结构体
typedef struct {
    /// rgb 三个通道，每个通道 256 种颜色可能
    atomic_uint channel[SY_CHANNEL_NUM][SY_CHANNEL_SIZE];   // （atomic 原子操作）
}SYColorBuffer;

/// 光栅化结果数据结构体
typedef struct {
    /// 裁剪空间位置
    float4 clipSpacePosition [[ position ]];    // position 修饰表示这个是顶点
    /// 纹理-坐标（会做插值处理）
    float2 textureCoordinate;
}RasterizerData;


constant float SIZE = float(SY_CHANNEL_SIZE - 1);


/// 顶点着色器
vertex RasterizerData
VertexShader(uint vertexID[[ vertex_id ]],  // vertex_id 修饰表示这个是着色器每次处理的顶点下标（用于定位当前顶点）
             constant SYVertex* vertexArray [[ buffer(SYVertexBufferIndexVertices) ]])  // buffer 表面是缓冲数据（SYVertexBufferIndexVertices 是索引）
{
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;    // 纹理坐标（会进行插值处理）
    return out;
}


/// 片段着色器
fragment float4
FragmentShader(RasterizerData input [[ stage_in ]], // stage_in 表示这个数据来自光栅化（光栅化是顶点处理后的步骤，业务层无法修改）
               texture2d<float> colorTexture [[ texture(SYFragmentTextureIndexSource) ]],  // texture 表示是纹理数据（SYFragmentTextureIndexSource 是索引）
               device SYLocalBuffer &convertBuffer [[ buffer(SYFragmentBufferIndexConvert) ]])  // 转换的缓冲
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);   // 纹理采样器
    float4 colorSample = colorTexture.sample(textureSampler, input.textureCoordinate);  // 读取原始纹理颜色值
    int3 rgb           = int3(colorSample.rgb * SIZE);    // 先乘 SIZE （转成 0~255 之间的值）
    colorSample.rgb    = float3(convertBuffer.channel[0][rgb.r],
                                convertBuffer.channel[1][rgb.g],
                                convertBuffer.channel[2][rgb.b]) / SIZE;    // 再将 0~255 之间的值转成 0.0~1.0 之间的浮点数
    return colorSample;
}


/// 内核计算函数
kernel void
GrayCompute(texture2d<float, access::read> sourceTexture [[ texture(SYKernelTextureIndexSource) ]], // 输入-纹理
            device SYColorBuffer &out [[ buffer(SYKernelBufferIndexOutput)]],   // 输出-缓存
            uint2 grid [[ thread_position_in_grid ]])   // grid 索引
{
    // 边界保护
    if (grid.x >= sourceTexture.get_width() || grid.y >= sourceTexture.get_height()) {
        return;
    }
    float4 color = sourceTexture.read(grid);    // 读取原始颜色
    int3 rgb     = int3(color.rgb * SIZE);  // // 先乘 SIZE （转成 0~255 之间的值）
    // 颜色统计（每个像素点计一次）
    atomic_fetch_add_explicit(&out.channel[0][rgb.r], 1, memory_order_relaxed); // R
    atomic_fetch_add_explicit(&out.channel[1][rgb.g], 1, memory_order_relaxed); // G
    atomic_fetch_add_explicit(&out.channel[2][rgb.b], 1, memory_order_relaxed); // B
}
