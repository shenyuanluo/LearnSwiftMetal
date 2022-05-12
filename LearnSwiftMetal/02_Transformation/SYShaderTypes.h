//
//  SYShaderTypes.h
//  02_Transformation
//
//  Created by ShenYuanLuo on 2022/5/10.
//

#ifndef SYShaderTypes_h
#define SYShaderTypes_h

#include <simd/simd.h>

/// 顶点结构
typedef struct {
    /// 坐标
    vector_float4 position;
    /// 颜色
    vector_float3 color;
    /// 纹理坐标
    vector_float2 textureCoordinate;
}SYVertex;

/// 矩阵结构
typedef struct {
    /// 投影矩阵
    matrix_float4x4 projectionMatrix;
    /// 模型视图矩阵
    matrix_float4x4 modelViewMatrix;
}SYMatrix;

/// 顶点-缓存输入下标
typedef enum {
    /// 顶点
    SYVertexInputIndexVertices  = 0,
    /// 矩阵
    SYVertexInputIndexMatrix    = 1,
}SYVertexInputIndex;

/// 片段-缓存输入下标
typedef enum {
    /// 纹理
    SYFragmentInputIndexTexture = 0,
}SYFragmentInputIndex;


#endif /* SYShaderTypes_h */
