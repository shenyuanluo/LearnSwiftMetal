//
//  SYShaderTypes.h
//  Sec10_MetalInteractGLES
//
//  Created by ShenYuanLuo on 2022/5/27.
//

#ifndef SYShaderTypes_h
#define SYShaderTypes_h

#include <simd/simd.h>

/// 顶点结构体
typedef struct {
    /// 位置
    vector_float4 position;
    /// 纹理坐标
    vector_float2 textureCoordinate;
}SYVertex;


/// 顶点着色器输入下标枚举
typedef enum {
    /// 顶点数据
    SYVertexInputIndexVertices  = 0,
}SYVertexInputIndex;


/// 内核计算纹理输入下标
typedef enum {
    /// 源始-纹理
    SYComputeTextureIndexSrc    = 0,
    /// 目的-纹理
    SYComputeTextureIndexDest   = 1,
}SYComputeTextureIndex;


/// 转换参数结构体
typedef struct {
    /// 转亮度值（BT.709 标准）
    vector_float3 kRec709Luma;
}SYTransParam;

#endif /* SYShaderTypes_h */
