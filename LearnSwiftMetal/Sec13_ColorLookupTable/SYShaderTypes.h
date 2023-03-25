//
//  SYShaderTypes.h
//  Sec13_ColorLookupTable
//
//  Created by ShenYuanLuo on 2022/6/8.
//

#ifndef SYShaderTypes_h
#define SYShaderTypes_h

#include <simd/simd.h>

/// 顶点结构体
typedef struct {
    /// 顶点-位置
    vector_float4 position;
    /// 纹理-坐标
    vector_float2 textureCoordinate;
}SYVertex;


/// 转换矩阵结构体
typedef struct {
    /// 矩阵
    matrix_float3x3 matrix;
    /// 偏移
    vector_float3 offset;
}SYConvertMatrix;


/// 顶点着色器输入下标
typedef enum {
    /// 顶点
    SYVertexInputIndexVertices  = 0,
}SYVertexInputIndex;


/// 片段着色器缓存下标
typedef enum {
    /// 矩阵
    SYFragmentBufferIndexMatrix = 0,
}SYFragmentBufferIndex;


/// 片段着色器纹理下标
typedef enum {
    /// 普通-纹理
    SYFragmentTextureIndexNormal        = 0,
    /// 查表-纹理
    SYFragmentTextureIndexLookupTable   = 1,
}SYFragmentTextureIndex;

#endif /* SYShaderTypes_h */
