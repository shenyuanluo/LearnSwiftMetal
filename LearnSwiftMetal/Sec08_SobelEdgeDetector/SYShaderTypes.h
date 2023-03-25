//
//  SYShaderTypes.h
//  Sec08_SobelEdgeDetector
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


/// 顶点输入下标枚举
typedef enum {
    /// 顶点
    SYVertexInputIndexVertices = 0
}SYVertexInputIndex;


/// 片段纹理下标枚举
typedef enum {
    /// 原始-纹理
    SYFragmentTextureIndexSrc   = 0,
    /// 结果-纹理
    SYFragmentTextureIndexDest  = 1,
}SYFragmentTextureIndex;


#endif /* SYShaderTypes_h */
