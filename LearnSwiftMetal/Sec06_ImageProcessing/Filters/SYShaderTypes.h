//
//  SYShaderTypes.h
//  Sec06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/18.
//

#ifndef SYShaderTypes_h
#define SYShaderTypes_h

typedef struct {
    float saturationFactor;
}AdjustSaturationUniforms;

/// 纹理下标
typedef enum {
    /// 输入纹理
    SYTextureIndexInput = 0,
    /// 输出纹理
    SYTextureIndexOutput = 1,
}SYTextureIndex;


#endif /* SYShaderTypes_h */
