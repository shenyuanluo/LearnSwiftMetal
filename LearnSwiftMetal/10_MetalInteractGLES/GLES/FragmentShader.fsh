//
//  FragmentShader.fsh
//  10_MetalInteractGLES
//
//  Created by ShenYuanLuo on 2022/5/27.
//


/*
 片段着色器
 */

varying highp vec2 texCoordVarying; // 纹理坐标（「顶点」着色器传入）
uniform sampler2D inputTexture; // 纹理采样器（程序输入）
precision mediump float;    // 数据精度

void main()
{
    lowp vec3 rgb = texture2D(inputTexture, texCoordVarying).rgb;   // 采样纹理像素颜色
    gl_FragColor  = vec4(rgb, 1);   // 输出片段颜色值
}
