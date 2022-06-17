//
//  SYShaders.metal
//  17_DiffuseReflection
//
//  Created by ShenYuanLuo on 2022/6/16.
//

#include <metal_stdlib>
#include "SYShaderTypes.h"

using namespace metal;


/// 顶点结构体（和 VertexDescriptor 中描述的一致）
typedef struct {
    /// 位置
    float3 position [[ attribute(0) ]];
    /// 纹理坐标
    float2 texCoord [[ attribute(1) ]];
    /// 法线
    half4 normal [[ attribute(2) ]];
}SYVertex;


/// 光栅化结果数据结构体
typedef struct {
    /// 裁剪空间位置
    float4 position [[ position ]];    // position 修饰表示这个是顶点
    /// 纹理-坐标（会做插值处理）
    float2 texCoord;
    /// 法线
    float4 normal;
}RasterizerData;


/// 顶点着色器
vertex RasterizerData
VertexShader(SYVertex input [[ stage_in ]],
             constant SYUniforms & uniforms [[ buffer(SYBufferIndexUniform) ]])
{
    RasterizerData out;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(input.position, 1.0);  // MVP 变换
    out.texCoord = input.texCoord;
    out.normal   = normalize(uniforms.modelMatrix * float4(float3(input.normal.xyz), 0));  // 将法线从模型空间转到世界空间
    return out;
}


/// 片段着色器
fragment half4
FragmentShader(RasterizerData input [[stage_in ]],
               constant SYUniforms & uniforms [[ buffer(SYBufferIndexUniform) ]],
               texture2d<half> baseColorMap [[ texture(SYTextureIndexColor) ]])
{
    // 纹理采样器
    constexpr sampler linearSampler(mip_filter::linear,
                                    mag_filter::linear,
                                    min_filter::linear,
                                    s_address::repeat,
                                    t_address::repeat);
    // 采样纹素颜色
    half4 colorSample = baseColorMap.sample(linearSampler, input.texCoord);
    
    float3 N = float3(input.normal.xyz);    // 法向量
    float3 L = normalize(-uniforms.directionalLightDirection);  // 入射光线取反
    
    // Lamber 漫反射
    float diffuse = uniforms.IL * uniforms.Kd * max(dot(N, L), 0.0);    // 计算漫反射光强
    float3 out    = float3(uniforms.directionalLightColor) * float3(colorSample.xyz) * diffuse; // 物体反射颜色 = 光照颜色 * 物体颜色 * 反射强度
    
    return half4(half3(out.xyz), 1.0);
}
