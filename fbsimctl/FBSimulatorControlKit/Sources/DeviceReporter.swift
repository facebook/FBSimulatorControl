/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

import FBDeviceControl
import Foundation

open class DeviceReporter: iOSReporter {
  public unowned let device: FBDevice
  public let reporter: EventReporter
  public let format: FBiOSTargetFormat

  init(device: FBDevice, format: FBiOSTargetFormat, reporter: EventReporter) {
    self.device = device
    self.format = format
    self.reporter = reporter
  }

  open var target: FBiOSTarget {
    return device
  }
}
