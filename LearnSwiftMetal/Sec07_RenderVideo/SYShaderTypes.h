//
//  SYShaderTypes.h
//  Sec07_RenderVideo
//
//  Created by ShenYuanLuo on 2022/5/25.
//

#ifndef SYShaderTypes_h
#define SYShaderTypes_h

#include <simd/simd.h>

/// 顶点结构体
typedef struct {
    /// 位置-坐标
    vector_float4 position;
    /// 纹理-坐标
    vector_float2 textureCoordinate;
}SYVertex;


/// 转换矩阵结构体
typedef struct {
    /// 矩阵
    matrix_float3x3 matrix;
    /// 偏移量
    vector_float3 offset;
}SYConvertMatrix;


/// 顶点输入下标枚举
typedef enum {
    /// 顶点
    SYVertexInputIndexVertices = 0
}SYVertexInputIndex;


/// 片段缓存下标枚举
typedef enum {
    /// 矩阵
    SYFragmentBufferIndexMatrix = 0
}SYFragmentBufferIndex;


/// 片段纹理下标枚举
typedef enum {
    /// Y-纹理
    SYFragmentTextureIndexY     = 0,
    /// UV-纹理
    SYFragmentTextureIndexUV    = 1,
} SYFragmentTextureIndex;


#endif /* SYShaderTypes_h */
