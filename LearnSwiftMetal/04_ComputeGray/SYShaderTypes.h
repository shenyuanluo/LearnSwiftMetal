//
//  SYShaderTypes.h
//  04_ComputeGray
//
//  Created by ShenYuanLuo on 2022/5/12.
//

#ifndef SYShaderTypes_h
#define SYShaderTypes_h

#include <simd/simd.h>

/// 顶点结构
typedef struct {
    /// 位置
    vector_float4 position;
    /// 纹理坐标
    vector_float2 textureCoordinate;
}SYVertex;

/// 顶点-缓存输入下标
typedef enum {
    /// 顶点
    SYVertexInputIndexVertices  = 0,
}SYVertexInputIndex;

/// 片段-缓存输入下标
typedef enum {
    /// 原始-纹理
    SYFragmentInputIndexTextureSrc  = 0,
    /// 目的-纹理
    SYFragmentInputIndexTextureDest = 1,
}SYFragmentInputIndex;


#endif /* SYShaderTypes_h */
