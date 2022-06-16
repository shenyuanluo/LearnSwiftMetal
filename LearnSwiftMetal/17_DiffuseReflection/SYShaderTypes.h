//
//  SYShaderTypes.h
//  17_DiffuseReflection
//
//  Created by ShenYuanLuo on 2022/6/16.
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
    /// 法线
    SYVertexAttributeNormal     = 2,
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
    /// 模型矩阵
    matrix_float4x4 modelMatrix;
    /// 观察矩阵
    matrix_float4x4 viewMatrix;
    /// 模型-观察矩阵
    matrix_float4x4 modelViewMatrix;
    /// 投影矩阵
    matrix_float4x4 projectionMatrix;
    
    /// 光源强度
    float IL;
    /// 漫反射系数
    float Kd;
    
    /// 定向光-方向
    vector_float3 directionalLightDirection;
    /// 定向光-颜色
    vector_float3 directionalLightColor;
}SYUniforms;

#endif /* SYShaderTypes_h */
