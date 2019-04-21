//
//  MyoModelRunner.swift
//  MMCheck
//
//  Created by Alexander H List on 4/21/19.
//  Copyright © 2019 Alexander H List. All rights reserved.
//

import Foundation
import CoreML

fileprivate let frameSize = 60
fileprivate typealias Idx = ChannelIdx

fileprivate enum ChannelIdx: NSNumber {
  case ax = 0
  case ay
  case az
  case qw
  case qx
  case qy
  case qz
  case e0
  case e1
  case e2
  case e3
  case e4
  case e5
  case e6
  case e7
}

fileprivate let aChannelIdx = (x: 0, y: 1, z: 2)

class MyoModelRunner {
  private var dataPoints = [Datum]()
  private var model = IMyoPointingModel()
  private var currentlyPredicting = false
  var isPredicting: Bool { return currentlyPredicting }
  
  func addDataPoint(point: Datum) {
    guard let pointCopy = point.scaledPoint else { return }
    dataPoints.append(pointCopy)
    if dataPoints.count > frameSize {
      dataPoints = Array(dataPoints[dataPoints.endIndex.advanced(by: -frameSize)...])
    }
  }
  
  func makePrediction() -> (idle: Double, gesture: Double)? {
    currentlyPredicting = true
    defer {
      currentlyPredicting = false
    }
    guard let dataArray = getDataArray() else { return nil }
    guard let result = try? model.prediction(input1: dataArray) else{
      return nil
    }
    let output = result.output1
    guard !output[0].doubleValue.isNaN && !output[1].doubleValue.isNaN else {return nil}
    return (output[0].doubleValue, output[1].doubleValue)
  }
}

extension MyoModelRunner {
  fileprivate func getDataArray() -> MLMultiArray? {
    guard dataPoints.count == frameSize else { return nil }
    let array = try! MLMultiArray(shape: [1, 60, 15], dataType: .double)
    
    for (i, point) in dataPoints.enumerated() {
      guard let accel = point.acceleration, let quat = point.quaternion, let emg = point.emg else { return nil }
      array[[0, i, Idx.ax.rawValue] as! [NSNumber]] = NSNumber(value: accel.x)
      array[[0, i, Idx.ay.rawValue] as! [NSNumber]] = NSNumber(value: accel.y)
      array[[0, i, Idx.az.rawValue] as! [NSNumber]] = NSNumber(value: accel.z)
      
      array[[0, i, Idx.qw.rawValue] as! [NSNumber]] = NSNumber(value: quat.w)
      array[[0, i, Idx.qx.rawValue] as! [NSNumber]] = NSNumber(value: quat.x)
      array[[0, i, Idx.qy.rawValue] as! [NSNumber]] = NSNumber(value: quat.y)
      array[[0, i, Idx.qz.rawValue] as! [NSNumber]] = NSNumber(value: quat.z)
      
      for ei in 0...Idx.e7.rawValue.intValue - Idx.e0.rawValue.intValue {
        let dataI = Idx.e0.rawValue.intValue + ei
        array[[0, i, dataI] as [NSNumber]] = emg[ei]
      }
    }
    return array
  }
}
