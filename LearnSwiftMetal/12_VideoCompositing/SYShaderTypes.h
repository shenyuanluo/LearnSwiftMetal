//
//  SYShaderTypes.h
//  12_VideoCompositing
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
    SYFragmentBufferIndexMatrix     = 0,
}SYFragmentBufferIndex;


/// 片段着色器纹理下标
typedef enum {
    /// 绿幕 Y-纹理
    SYFragmentTextureIndexGreenTextureY     = 0,
    /// 绿幕 UV-纹理
    SYFragmentTextureIndexGreenTextureUV    = 1,
    /// 正常 Y-纹理
    SYFragmentTextureIndexNormalTextureY    = 2,
    /// 正常 UV-纹理
    SYFragmentTextureIndexNormalTextureUV   = 3,
}SYFragmentTextureIndex;

#endif /* SYShaderTypes_h */
