//
//  MyoDatum.swift
//  MMCheck
//
//  Created by Alexander H List on 4/21/19.
//  Copyright © 2019 Alexander H List. All rights reserved.
//

import Foundation

fileprivate let aScale = (min: -3.364746, max: 5.992187)
fileprivate let qScale = (min: -2.579102, max: 5.206543)
fileprivate let eScale = (min: -128.0, max: 255.0)

struct Datum: CustomDebugStringConvertible {
  static let csvHeader = "time,gesture,ax,ay,az,qw,qx,qy,qz,e0,e1,e2,e3,e4,e5,e6,e7"
  /// Last data was set this time interval since run began
  var date: TimeInterval?
  /// Accelerations
  var acceleration: TLMVector3?
  /// EMG values
  var emg: [NSNumber]?
  /// Quat
  var quaternion: TLMQuaternion?
  /// whether it should be classified as part of a gesture or not
  var isGesture: Bool = false
  
  var ready: Bool {
    return date != nil && quaternion != nil && acceleration != nil && emg != nil
  }
  
  var verbose = false
  var debugDescription: String {
    guard ready else { return "not ready" }
    let emgString = emg!.map{ $0.stringValue }.joined(separator: ", ")
    var outString = "\(date!), \(isGesture), \(acceleration!.x), \(acceleration!.y), \(acceleration!.z), \(quaternion!.w), \(quaternion!.x), \(acceleration!.y), \(acceleration!.z), \(emgString)"
    if !verbose {
      outString = outString.split(separator: " ").joined() //deletes spaces after adding them lol
    }
    return outString
  }
}

extension Datum {
  var scaledPoint: Datum? {
    guard var accel = acceleration, var quat = quaternion, var emg = emg else { return nil }
    accel.x -= Float(aScale.min)
    accel.x /= Float(aScale.max)
    accel.y -= Float(aScale.min)
    accel.y /= Float(aScale.max)
    accel.z -= Float(aScale.min)
    accel.z /= Float(aScale.max)
    
    quat.w -= Float(qScale.min)
    quat.w /= Float(qScale.max)
    quat.x -= Float(qScale.min)
    quat.x /= Float(qScale.max)
    quat.y -= Float(qScale.min)
    quat.y /= Float(qScale.max)
    quat.z -= Float(qScale.min)
    quat.z /= Float(qScale.max)
    
    for i in 0 ... 7 {
      emg[i] = NSNumber(value: emg[i].doubleValue - eScale.min)
      emg[i] = NSNumber(value: emg[i].doubleValue / eScale.max)
    }
    var scaledPoint = Datum()
    scaledPoint.date = date
    scaledPoint.acceleration = accel
    scaledPoint.quaternion = quat
    scaledPoint.emg = emg
    return scaledPoint
  }
}
