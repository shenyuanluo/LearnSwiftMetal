//
//  SYShaderTypes.h
//  11_HistogramEqualization
//
//  Created by ShenYuanLuo on 2022/5/30.
//

#ifndef SYShaderTypes_h
#define SYShaderTypes_h

#include <simd/simd.h>

#define SY_CHANNEL_NUM  3       // 通道数量（RGB 三通道）
#define SY_CHANNEL_SIZE 256     // 通道大小（256 种颜色值）


/// 顶点结构体
typedef struct {
    /// 顶点-位置
    vector_float4 position;
    /// 纹理-坐标
    vector_float2 textureCoordinate;
}SYVertex;


/// 本地缓存
typedef struct {
    /// rgb 三个通道，每个通道 256 个颜色值
    int channel[SY_CHANNEL_NUM][SY_CHANNEL_SIZE];
}SYLocalBuffer;


/// 顶点着色器缓存下标枚举
typedef enum {
    /// 顶点数据
    SYVertexBufferIndexVertices     = 0,
}SYVertexBufferIndex;


/// 片段纹理下标枚举
typedef enum {
    /// 原始-纹理
    SYFragmentTextureIndexSource    = 0,
}SYFragmentTextureIndex;


/// 片段着色器缓存下标枚举
typedef enum {
    /// 转换计算缓存
    SYFragmentBufferIndexConvert    = 0,
}SYFragmentBufferIndex;


/// 内核计算函数缓存下标
typedef enum {
    /// 输出计算结果
    SYKernelBufferIndexOutput       = 0,
}SYKernelBufferIndex;


/// 内核计算函数纹理下标
typedef enum {
    /// 原始-纹理
    SYKernelTextureIndexSource      = 0,
}SYKernelTextureIndex;

#endif /* SYShaderTypes_h */
