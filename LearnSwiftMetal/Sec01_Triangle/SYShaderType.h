//
//  SYShaderType.h
//  LearnSwiftMetal
//
//  Created by ShenYuanLuo on 2022/5/5.
//

#ifndef SYShaderType_h
#define SYShaderType_h

#include <simd/simd.h>  // 头文件包含了 Metal shaders 与 C/OBJC 源之间共享的类型和枚举常数

/// 顶点结构体
typedef struct {
    /// 顶点坐标
    vector_float4 position;
    /// 纹理坐标
    vector_float2 textureCoordinate;
}SYVertex;

#endif /* SYShaderType_h */
