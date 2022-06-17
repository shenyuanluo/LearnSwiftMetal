//
//  SYShaders.metal
//  21_CookTorrance
//
//  Created by ShenYuanLuo on 2022/6/17.
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
    /// 世界空间位置（用于计算镜面反射光照）
    float4 worldPos;
}RasterizerData;


/// 顶点着色器
vertex RasterizerData
VertexShader(SYVertex input [[ stage_in ]],
             constant SYUniforms & uniforms [[ buffer(SYBufferIndexUniform) ]])
{
    RasterizerData out;
    float4 position = float4(input.position, 1.0);
    out.position    = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;  // MVP 变换
    out.texCoord    = input.texCoord;
    out.normal      = normalize(uniforms.modelMatrix * float4(float3(input.normal.xyz), 0));  // 将法线从模型空间转到世界空间
    out.worldPos    = uniforms.modelMatrix * position;
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
//    half4 colorSample = half4(0,0.7,0.2,1.0);
    
    float3 N = float3(input.normal.xyz);                            // 法线向量
    float3 L = normalize(-uniforms.directionalLightDirection);      // 入射光向量
    float3 V = normalize(uniforms.cameraPos - input.worldPos.xyz);  // 观察向量
    float3 H = normalize(L + V);    // 半角向量
//    float3 R = normalize(2 * fmax(dot(N, L), 0) * N - L);           // 反射光向量
    
    float Rs = 0;
    float nv = dot(N, V);
    float nl = dot(N, L);
    
    bool front = (nv > 0) && (nl > 0);  // 正面
    
    if (front)
    {
        float nh = dot(N, H);
        float vh = dot(V, H);
        
        // F: 菲涅耳反射系数
        float F = uniforms.f + (1 - uniforms.f) * pow(1 - vh, 5.0);
        
        // D: 微表面分布函数
        float temp = (nh * nh - 1) / (uniforms.m * uniforms.m * nh * nh);
        float D    = exp(temp) / (uniforms.m * uniforms.m) * pow(nh, 4.0);
        
        // G: 几何衰减系数
        float G1 = (2 * nh * nv) / vh;
        float G2 = (2 * nh * nl) / vh;
        float G  = fmin3(1.0, G1, G2);
        
        // Rs
        Rs = (F * D * G) / (nv * nl);
    }
    
    // Lamber 漫反射
    float diffuse = uniforms.IL * uniforms.Kd * max(dot(N, L), 0.0);    // 计算漫反射光强
    // 镜面反射（Cook-torrance）
    float specular = uniforms.IL * uniforms.Ks * Rs;    // 计算镜面反射
    // 环境光
    float amblient = uniforms.Ia * uniforms.Ka;
    
    // 冯氏光照模型: 环境光照 + 漫反射光照 + 镜面反射光照
    float3 out = float3(uniforms.directionalLightColor) * float3(colorSample.xyz) * (diffuse + specular + amblient);
    
    return half4(half3(out.xyz), 1.0);
}


