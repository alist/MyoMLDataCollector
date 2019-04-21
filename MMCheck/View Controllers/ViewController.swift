//
//  ViewController.swift
//  MMCheck
//
//  Created by Alexander H List on 4/8/19.
//  Copyright © 2019 Alexander H List. All rights reserved.
//

import UIKit
import AVFoundation

/**
 NOTES: J AND K models don't really work. I works pretty well when you have myo on correctly and you clentch-point!
 1. I think there's too much non-gesture data over gesture data-->
 2.     There's not enough gesture data in the port-down configuration
 3.     There's not a lot of data in different rotations around wrist
 4. The framed data should be uniformly scaled at this point because the differences are too subtle. Accel ±10 g and quat by Pi, EMG ±255
 5. We need to make sure we're using class_weights correctly
 6. The validation data is concerning because we should just sample from all the data sets for 50 % gesture and 50% non
 TLDR: MORE POINTING DATA! BETTER SCALING! MORE EVEN VALIDATION SET!
 
 Record some soft (less grippy) points.
 */

class ViewController: UIViewController {
  var myo: TLMMyo!
  let modeler = MyoModelRunner()
  let audioPlayer = try! AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "HTDripSound", withExtension: "wav")!)
  var startTime = Date()
  var isGesture: Bool = false
  
  var lastRecognition = Date()
  var recognitionDebounceInterval = 1.0
  var recognitionThreshold = 0.95
  var recognitionPredictionAverageCount = 5
  
  @IBOutlet weak var gestureProbabilityLabel: UILabel!
  @IBOutlet weak var idleProbabilityLabel: UILabel!
  
  /// Same datum is kept until 'ready' then it is printed and reset
  var datum = Datum()
  var printCSV: Bool = false
  var printClassification: Bool = false
  var classify = true
  
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
  }
  
  @objc func onAccelerometerData(notification: Notification!) {
    guard let accel = notification.userInfo?[kTLMKeyAccelerometerEvent] as? TLMAccelerometerEvent else { return }
    let data = accel.vector
    datum.date = accel.timestamp.timeIntervalSince(startTime)
    datum.acceleration = data
    processData()
  }
  
  @objc func onRotationData(notification: Notification!) {
    guard let rot = notification.userInfo?[kTLMKeyOrientationEvent] as? TLMOrientationEvent else { return }
    let data = rot.quaternion
    datum.date = rot.timestamp.timeIntervalSince(startTime)
    datum.quaternion = data
    processData()
  }
  
  func processData() {
    guard datum.ready else { return }
    datum.isGesture = isGesture
    if printCSV {
      print(datum)
    }
    modeler.addDataPoint(point: datum)
    if !modeler.isPredicting && classify {
      OperationQueue.main.addOperation { [weak self] in
        guard let this = self else { return }
        guard let prediction = this.modeler.makePrediction() else { return }
        if this.printClassification {
          print(prediction)
        }
        DispatchQueue.main.async {
          this.gestureProbabilityLabel.text = String(format: "%1.3f", arguments: [prediction.gesture])
          this.idleProbabilityLabel.text = String(format: "%1.3f", arguments: [prediction.idle])
          this.debounceRecognition()
        }
      }
    }
    datum = Datum()
  }
  
  /// Handles recognition and it's debouncing
  func debounceRecognition() {
    guard Date().timeIntervalSince(lastRecognition) > recognitionDebounceInterval else { return }
    guard modeler.averageOfLast(pointCount: recognitionPredictionAverageCount)?.gesture ?? 0 > recognitionThreshold else { return }
    print(modeler.averageOfLast(pointCount: recognitionPredictionAverageCount)!.gesture)
    audioPlayer.play()
    lastRecognition = Date()
  }
}
