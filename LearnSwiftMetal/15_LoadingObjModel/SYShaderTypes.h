//
//  SYShaderTypes.h
//  15_LoadingObjModel
//
//  Created by ShenYuanLuo on 2022/6/13.
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


/// 纹理下标
typedef enum {
    /// 颜色
    SYTextureIndexColor         = 0,
    /// 法线
    SYTextureIndexNormal        = 1,
    /// 镜面反射
    SYTextureIndexSpecular      = 2,
}SYTextureIndex;


#endif /* SYShaderTypes_h */
