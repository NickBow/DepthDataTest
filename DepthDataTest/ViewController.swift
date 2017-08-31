//
//  ViewController.swift
//  DepthDataTest
//
//  Created by Nicholas Bowlin on 8/21/17.
//  Copyright © 2017 Small Planet Digital. All rights reserved.
//

import UIKit
import AVFoundation
import Metal

class ViewController: UIViewController, AVCaptureDepthDataOutputDelegate {
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private var setupResult: SessionSetupResult = .success
    
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem)
    private let dataOutputQueue = DispatchQueue(label: "data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private var videoDeviceInput: AVCaptureDeviceInput!
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private var depthVisualizationEnabled = true
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check depth authorization status
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant video access
             We suspend the session queue to delay session setup until the access request has completed
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted { self.setupResult = .notAuthorized }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access
            setupResult = .notAuthorized
        }
        
        /*
         Setup the capture session.
         In general it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Why not do all of this on the main queue?
         Because AVCaptureSession.startRunning() is a blocking call which can
         take a long time. We dispatch session setup to the sessionQueue so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async { self.configureSession() }
    }
    
    // Call this on the session queue
    private func configureSession() {
        if setupResult != .success { return }
        
        let defaultVideoDevice: AVCaptureDevice? = videoDeviceDiscoverySession.devices.first
        
        guard let videoDevice = defaultVideoDevice else {
            print("Could not find any video device")
            setupResult = .configurationFailed
            return
        }
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }
        
        session.beginConfiguration()
        
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        // Add a video input
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)
        
        // Add a depth data output
        if session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)
            depthDataOutput.setDelegate(self, callbackQueue: dataOutputQueue)
            depthDataOutput.isFilteringEnabled = true
            if let connection = depthDataOutput.connection(with: .depthData) {
                connection.isEnabled = depthVisualizationEnabled
            } else {
                print("No AVCaptureConnection")
            }
        } else {
            print("Could not add depth data output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
        session.startRunning()
    }
    
    // MARK: - Depth Data Output Delegate
    
    func depthDataOutput(_ depthDataOutput: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        print("Depth output!")
        
         var bytesPerRow = CVPixelBufferGetBytesPerRow(depthData.depthDataMap)
         var width = CVPixelBufferGetWidth(depthData.depthDataMap)
         var height = CVPixelBufferGetHeight(depthData.depthDataMap)
        
         print("bytes: \(bytesPerRow) | \(width)/\(height)")
         var depth = depthData
         depth = depth.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
         
         var type = depth.depthDataType
         var pixelBuffer = depth.depthDataMap
        
         switch type {
         case kCVPixelFormatType_DisparityFloat16: print("Disparity 16")
         case kCVPixelFormatType_DisparityFloat32: print("Disparity 32")
         case kCVPixelFormatType_DepthFloat16: print("Depth 16")
         case kCVPixelFormatType_DepthFloat32: print("Depth 32")
         default: print("Other type")
         }
         
         CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
         
         let pixelBufferPointer = unsafeBitCast(CVPixelBufferGetBaseAddress(pixelBuffer), to: UnsafeMutablePointer<Float32>.self)
         let pixel = pixelBufferPointer[0]
        
        print("Distance: \(pixel)")
         
         CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

