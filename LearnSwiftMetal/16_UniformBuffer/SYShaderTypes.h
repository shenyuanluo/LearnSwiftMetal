//
//  SYShaderTypes.h
//  16_UniformBuffer
//
//  Created by ShenYuanLuo on 2022/6/15.
//

#ifndef SYShaderTypes_h
#define SYShaderTypes_h

#include <simd/simd.h>


/// 顶点属性枚举
typedef enum {
    /// 位置
    SYVertexAttributePosition   = 0,
    /// 纹理坐标
    SYVertexAttributeTexCoord   = 1,
}SYVertexAttribute;


/// 缓存下标
typedef enum {
    SYBufferIndexMeshPosition   = 0,
    SYBufferIndexUniform        = 1,
}SYBufferIndex;


/// 纹理下标
typedef enum {
    /// 颜色
    SYTextureIndexColor         = 0,
    /// 法线
    SYTextureIndexNormal        = 1,
    /// 镜面反射
    SYTextureIndexSpecular      = 2,
}SYTextureIndex;


/// Uniform 结构体
typedef struct {
    /// 模型-视图矩阵
    matrix_float4x4 modelViewMatrix;
    /// 投影矩阵
    matrix_float4x4 projectionMatrix;
}SYUniforms;

#endif /* SYShaderTypes_h */
