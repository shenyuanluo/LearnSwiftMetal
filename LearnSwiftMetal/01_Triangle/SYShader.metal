//
//  Shader.metal
//  LearnSwiftMetal
//
//  Created by ShenYuanLuo on 2022/5/5.
//

#include <metal_stdlib>
#include "SYShaderType.h"
using namespace metal;


typedef struct
{
    float4 clipSpacePosition [[position]]; // position的修饰符表示这个是顶点
    
    float2 textureCoordinate; // 纹理坐标，会做插值处理
    
} RasterizerData;


// vertex 修饰，表示该函数是一个「顶点着色器」
vertex RasterizerData // 返回给片元着色器的结构体
VertexShader(uint vertexID [[ vertex_id ]], // vertex_id 是顶点 shader 每次处理的 index，用于定位当前的顶点
             constant SYVertex *vertexArray [[ buffer(0) ]]) { // buffer 表明是缓存数据，0 是索引
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}

// fragment 修饰，表示该函数是一个「片段着色器」
fragment float4
FragmentShader(RasterizerData input [[stage_in]], // stage_in 表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
               texture2d<half> colorTexture [[ texture(0) ]]) // texture 表明是纹理数据，0 是索引
{
    // Metal 程序中初始化的采样器必须使用 constexpr 修饰符声明
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear); // sampler是采样器
    
    half4 colorSample = colorTexture.sample(textureSampler, input.textureCoordinate); // 得到纹理对应位置的颜色
    
    return float4(colorSample);
}
