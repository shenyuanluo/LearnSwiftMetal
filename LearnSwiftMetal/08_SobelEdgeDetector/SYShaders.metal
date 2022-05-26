//
//  SYShaders.metal
//  08_SobelEdgeDetector
//
//  Created by ShenYuanLuo on 2022/5/25.
//

#include <metal_stdlib>
#import "SYShaderTypes.h"

using namespace metal;

/// 光栅化数据结构
typedef struct {
    /// 裁剪空间位置（position 修饰表示这个是顶点）
    float4 clipSpacePosition [[ position ]];
    /// 纹理坐标
    float2 textureCoordinate;
}RasterizerData;


/// 顶点着色器函数
vertex RasterizerData
VertexShader(uint vertexID [[ vertex_id ]], // vertex_id 是顶点着色器每次处理的 index，用于定位当前的顶点
             constant SYVertex* vertexArray [[ buffer(SYVertexInputIndexVertices) ]])   // buffer 修饰表示是缓冲数据，0 是顶点缓冲索引
{
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}


/// 片段着色器
fragment float4
FragmentShader(RasterizerData input [[ stage_in ]], // stage_in 表示数据来自光栅化（光栅化是顶点着色器处理后的数据，业务层无法修改）
               texture2d<half> colorTexture [[ texture(0) ]])   // texture 修饰表示是纹理，0 是纹理索引
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);   // sampler 是纹理采样器
    half4 colorSample = colorTexture.sample(textureSampler, input.textureCoordinate);   // 采集纹理纹素颜色
    return float4(colorSample);
}


constant half kSobelStep = 1.0;  //
constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722); // BT.709 标准：RGB 转成亮度值


/// 内核计算函数（Sobel 边缘检测：https://homepages.inf.ed.ac.uk/rbf/HIPR2/sobel.htm）
kernel void
SobelCompute(texture2d<half, access::read>  textureSrc  [[ texture(SYFragmentTextureIndexSrc) ]],
             texture2d<half, access::write> textureDest [[ texture(SYFragmentTextureIndexDest) ]],
             uint2                          grid        [[ thread_position_in_grid ]])
{
    /*
     行数     9个像素          位置
     上     | * * * |      | 左 中 右 |
     中     | * * * |      | 左 中 右 |
     下     | * * * |      | 左 中 右 |
     */
    half4 topLeft      = textureSrc.read(uint2(grid.x - kSobelStep, grid.y - kSobelStep));  // 左上
    half4 top          = textureSrc.read(uint2(grid.x,              grid.y - kSobelStep));  // 上
    half4 topRight     = textureSrc.read(uint2(grid.x + kSobelStep, grid.y - kSobelStep));  // 右上
    half4 left         = textureSrc.read(uint2(grid.x - kSobelStep, grid.y             ));  // 左
    half4 center       = textureSrc.read(uint2(grid.x,              grid.y             ));  // 中
    half4 right        = textureSrc.read(uint2(grid.x + kSobelStep, grid.y             ));  // 右
    half4 bottomLeft   = textureSrc.read(uint2(grid.x + kSobelStep, grid.y + kSobelStep));  // 下左
    half4 bottom       = textureSrc.read(uint2(grid.x,              grid.y + kSobelStep));  // 下
    half4 bottomRight  = textureSrc.read(uint2(grid.x + kSobelStep, grid.y + kSobelStep));  // 下右

    // 计算出周围各个点的灰度值
    half3x3 A;
    A[0][0] = dot(topLeft.rgb,     kRec709Luma);
    A[0][1] = dot(top.rgb,         kRec709Luma);
    A[0][2] = dot(topRight.rgb,    kRec709Luma);
    A[1][0] = dot(left.rgb,        kRec709Luma);
    A[1][1] = dot(center.rgb,      kRec709Luma);
    A[1][2] = dot(right.rgb,       kRec709Luma);
    A[2][0] = dot(bottomLeft.rgb,  kRec709Luma);
    A[2][1] = dot(bottom.rgb,      kRec709Luma);
    A[2][2] = dot(bottomRight.rgb, kRec709Luma);
    
    /*
     Soobel 卷积因子
          Gx                  Gy
     | -1, 0, 1 |       | -1, -2, -1 |
     | -2, 0, 2 |       |  0,  0,  0 |
     | -1, 0, 1 |       |  1,  2,  1 |
     */
    
    // 构建 Gx 卷积因子矩阵
    half3x3 Gx;
    /* 不可以直接静态初始化，暂原因未知
    = {
        -1, 0, 1,
        -2, 0, 2,
        -1, 0, 1
    }*/
    Gx[0][0] = -1;
    Gx[0][1] =  0;
    Gx[0][2] =  1;
    Gx[1][0] = -2;
    Gx[1][1] =  0;
    Gx[1][2] =  2;
    Gx[2][0] = -1;
    Gx[2][1] =  0;
    Gx[2][2] =  1;

    // 构建 Gy 卷积因子矩阵
    half3x3 Gy;
    /* 不可以直接静态初始化，暂原因未知
    = {
        -1, -2, -1 ,
         0,  0,  0,
         1,  2,  1
    }*/
    Gy[0][0] = -1;
    Gy[0][1] = -2;
    Gy[0][2] = -1;
    Gy[1][0] =  0;
    Gy[1][1] =  0;
    Gy[1][2] =  0;
    Gy[2][0] =  1;
    Gy[2][1] =  2;
    Gy[2][2] =  1;

    
    half gx = Gx[0][0] * A[0][0]  +  Gx[0][1] * A[0][1]  +  Gx[0][2] * A[0][2] +
              Gx[1][0] * A[1][0]  +  Gx[1][1] * A[1][1]  +  Gx[1][2] * A[1][2] +
              Gx[2][0] * A[2][0]  +  Gx[2][1] * A[2][1]  +  Gx[2][2] * A[2][2];
    half gy = Gy[0][0] * A[0][0]  +  Gy[0][1] * A[0][1]  +  Gy[0][2] * A[0][2] +
              Gy[1][0] * A[1][0]  +  Gy[1][1] * A[1][1]  +  Gy[1][2] * A[1][2] +
              Gy[2][0] * A[2][0]  +  Gy[2][1] * A[2][1]  +  Gy[2][2] * A[2][2];
    
    // sqrt(hori^2 + vert^2)，相当于求点到(hori, vert)的距离，所以可以用length
    half color = length(half2(gx, gy));
    textureDest.write(half4(color, color, color, 1.0), grid); // 写回对应纹理
}
