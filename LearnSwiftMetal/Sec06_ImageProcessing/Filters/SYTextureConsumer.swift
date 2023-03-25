//
//  SYTextureConsumer.swift
//  Sec06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/17.
//

import Foundation

/// 纹理使用协议
protocol SYTextureConsumerProtocol {
    /// 纹理提供者
    var provider: SYTextureProviderProtocol? { get }
}
