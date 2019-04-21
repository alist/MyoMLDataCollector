//
//  ViewController.swift
//  MMCheck
//
//  Created by Alexander H List on 4/8/19.
//  Copyright © 2019 Alexander H List. All rights reserved.
//

import UIKit

extension String {
  static let empty = ""
}

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
    let emgString = emg!.map{ $0.stringValue }.joined(separator: ", e ")
    var outString = "\(date!), \(isGesture), a \(acceleration!.x), a \(acceleration!.y), a \(acceleration!.z), q \(quaternion!.w), q \(quaternion!.x), q \(acceleration!.y), q \(acceleration!.z), e \(emgString)"
    if !verbose {
      outString = outString.replacingOccurrences(of: "a", with: String.empty)
      outString = outString.replacingOccurrences(of: "e", with: String.empty)
      outString = outString.replacingOccurrences(of: "q", with: String.empty)
      outString = outString.split(separator: " ").joined() //deletes spaces after adding them lol
    }
    return outString
  }
}

class ViewController: UIViewController {
  var myo: TLMMyo!
  var startTime = Date()
  var isGesture: Bool = false
  
  /// Same datum is kept until 'ready' then it is printed and reset
  var datum = Datum()
  
  @IBOutlet weak var statusLabel: UILabel!
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  @IBAction func downOnGestureButton(_ sender: Any) {
    isGesture = true
    updateUI()
  }
  
  @IBAction func gestureButtonUp(_ sender: Any) {
    isGesture = false
    updateUI()
  }
  
  func updateUI() {
    statusLabel.text = isGesture ? "Gesture" : "Not-Gesture"
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.default.addObserver(self, selector: #selector(self.onConnect(notification:)), name: NSNotification.Name.TLMHubDidConnectDevice, object: nil)

    NotificationCenter.default.addObserver(self, selector: #selector(self.onEMGData(notification:)), name: NSNotification.Name.TLMMyoDidReceiveEmgEvent, object: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(self.onAccelerometerData(notification:)), name: NSNotification.Name.TLMMyoDidReceiveAccelerometerEvent, object: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(self.onRotationData(notification:)), name: NSNotification.Name.TLMMyoDidReceiveOrientationEvent, object: nil)
    
    print(Datum.csvHeader)
    
    OperationQueue.main.addOperation { [weak self] in
      self?.openSettings()
    }
  }
  
  @IBAction func openSettings() {
    let settings = TLMSettingsViewController.settingsInNavigationController()!
    present(settings, animated: true, completion: nil)
  }
}


extension ViewController {
  @objc func onConnect(notification: Notification!) {
    guard let myo = TLMHub.shared()?.myoDevices()?.first as? TLMMyo else { return }
    self.myo = myo
    myo.setStreamEmg(.enabled)
  }
  
  @objc func onEMGData(notification: Notification!) {
    guard let emg = notification.userInfo?[kTLMKeyEMGEvent] as? TLMEmgEvent,
      let data = emg.rawData as? [NSNumber] else { return }
    datum.date = emg.timestamp.timeIntervalSince(startTime)
    datum.emg = data
    processData()
//    print("💪🏼 EMG: \(emg.timestamp.timeIntervalSince(startTime)) - \(data)" )
  }
  
  @objc func onAccelerometerData(notification: Notification!) {
    guard let accel = notification.userInfo?[kTLMKeyAccelerometerEvent] as? TLMAccelerometerEvent else { return }
    let data = accel.vector
    datum.date = accel.timestamp.timeIntervalSince(startTime)
    datum.acceleration = data
    processData()
//    print("🏎 ACC: \(accel.timestamp.timeIntervalSince(startTime)) - \(data.x), \(data.y), \(data.z)" )
  }
  
  @objc func onRotationData(notification: Notification!) {
    guard let rot = notification.userInfo?[kTLMKeyOrientationEvent] as? TLMOrientationEvent else { return }
    let data = rot.quaternion
    datum.date = rot.timestamp.timeIntervalSince(startTime)
    datum.quaternion = data
    processData()
//    print("➰ ROT: \(rot.timestamp.timeIntervalSince(startTime)) - \(data.x), \(data.y), \(data.z), w: \(data.w)")
  }
  
  func processData() {
    guard datum.ready else { return }
    datum.isGesture = isGesture
    print(datum)
    datum = Datum()
  }
}
