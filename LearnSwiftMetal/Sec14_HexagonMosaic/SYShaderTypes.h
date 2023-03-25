//
//  SYShaderTypes.h
//  Sec14_HexagonMosaic
//
//  Created by ShenYuanLuo on 2022/6/9.
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


/// 顶点着色器输入下标
typedef enum {
    /// 顶点
    SYVertexInputIndexVertices  = 0,
}SYVertexInputIndex;


/// 片段着色器输入下标
typedef enum {
    /// 纹理
    SYFragmentInputIndexTexture = 0,
}SYFragmentInputIndex;

#endif /* SYShaderTypes_h */
