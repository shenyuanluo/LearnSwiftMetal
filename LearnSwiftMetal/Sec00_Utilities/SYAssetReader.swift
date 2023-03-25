//
//  SYAssetReader.swift
//  LearnSwiftMetal
//
//  Created by ShenYuanLuo on 2022/5/25.
//

import Foundation
import AVFoundation

class SYAssetReader {
    var reader: AVAssetReader!
    var trackOutput: AVAssetReaderTrackOutput!
    var videoUrl: URL
    var lock = NSLock()
    
    init(videoUrl: URL) {
        self.videoUrl = videoUrl
        self.customInit()
    }
    
    func readBuffer() -> CMSampleBuffer? {
        var buffer: CMSampleBuffer?
        
        self.lock.lock()
        if nil != self.trackOutput {
            buffer = self.trackOutput.copyNextSampleBuffer()
        }
        if nil != self.reader && .completed == self.reader.status {
            self.trackOutput = nil
            self.reader = nil
            self.customInit()
        }
        self.lock.unlock()
        
        return buffer
    }
    
    private func customInit() {
        let options = [AVURLAssetPreferPreciseDurationAndTimingKey : true]
        let asset = AVURLAsset(url: self.videoUrl, options: options)
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
            DispatchQueue.global().async {
                var error: NSError? = nil
                let status = asset.statusOfValue(forKey: "tracks", error: &error)
                if .loaded != status {
                    print("Load video asset error: \(String(describing: error?.localizedDescription))")
                    return
                }
                self?.processWith(asset: asset)
            }
        }
    }
    
    private func processWith(asset: AVAsset) {
        self.lock.lock()
        
        print("Prcess asset ...")
        do {
            self.reader = try AVAssetReader(asset: asset)
        } catch {
            print("Create asset reader failed.")
        }
        let settings = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        if let track = asset.tracks(withMediaType: .video).first {
            self.trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
            self.trackOutput.alwaysCopiesSampleData = false
            if self.reader.canAdd(self.trackOutput) {
                self.reader.add(self.trackOutput)
            }
        }
        if false == self.reader.startReading() {
            print("Error reading from file at URL: \(asset)")
        }
        
        self.lock.unlock()
    }
}
