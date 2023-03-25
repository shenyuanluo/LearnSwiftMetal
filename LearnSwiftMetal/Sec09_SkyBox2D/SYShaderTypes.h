//
//  SYShaderTypes.h
//  Sec09_SkyBox2D
//
//  Created by ShenYuanLuo on 2022/5/26.
//

#ifndef SYShaderTypes_h
#define SYShaderTypes_h

#include <simd/simd.h>

/// 顶点结构体
typedef struct {
    /// 位置
    vector_float4 position;
    /// 颜色
    vector_float3 color;
    /// 纹理坐标
    vector_float2 textureCoordinate;
}SYVertex;


/// 矩阵结构体
typedef struct {
    /// 投影矩阵
    matrix_float4x4 projection;
    /// 模型观察矩阵
    matrix_float4x4 modelView;
}SYMatrix;


/// 顶点着色器缓存下标枚举
typedef enum {
    /// 顶点
    SYVertexInputIndexVertices  = 0,
    /// 矩阵
    SYVertexInputIndexMatrix    = 1,
}SYVertexInputIndex;


/// 片段着色器下标枚举
typedef enum {
    /// 纹理
    SYFragmentInputIndexTexture     = 0,
}SYFragmentInputIndex;


#endif /* SYShaderTypes_h */
