//
//  CornerView.swift
//  MMCheck
//
//  Created by Alexander H List on 4/8/19.
//  Copyright © 2019 Alexander H List. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable class CornerButton: UIButton {
  @IBInspectable var cornerRadius: CGFloat {
    get { return layer.cornerRadius }
    set(new) { layer.cornerRadius = new }
  }
}

@IBDesignable class CornerView: UIView {
  @IBInspectable var cornerRadius: CGFloat {
    get { return layer.cornerRadius }
    set(new) { layer.cornerRadius = new }
  }
}
