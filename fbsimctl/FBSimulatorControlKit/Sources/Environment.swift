/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

import Foundation
import FBSimulatorControl

let EnvironmentPrefix = "FBSIMCTL_CHILD_"

public extension CLI {
  func appendEnvironment(_ environment: [String : String]) -> CLI {
    switch self {
    case .run(let command):
      return .run(command.appendEnvironment(environment))
    default:
      return self
    }
  }
}

public extension Command {
  func appendEnvironment(_ environment: [String : String]) -> Command {
    return Command(
      configuration: self.configuration,
      actions: self.actions.map { $0.appendEnvironment(environment) },
      query: self.query,
      format: self.format
    )
  }
}

public extension Action {
  func appendEnvironment(_ environment: [String : String]) -> Action {
    switch self {
    case .launchApp(let configuration):
      return .launchApp(
        configuration.withEnvironmentAdditions(
          Action.subprocessEnvironment(environment)
        )
      )
    case .launchAgent(let configuration):
      return .launchAgent(
        configuration.withEnvironmentAdditions(
          Action.subprocessEnvironment(environment)
        )
      )
    case .launchXCTest(let configuration):
      if let appLaunchConf = configuration.applicationLaunchConfiguration?.withEnvironmentAdditions(
        Action.subprocessEnvironment(environment)
      ) {
        return .launchXCTest(configuration.withApplicationLaunchConfiguration(appLaunchConf))
      }
      return .launchXCTest(configuration)
    default:
      return self
    }
  }

  fileprivate static func subprocessEnvironment(_ environment: [String : String]) -> [String : String] {
    var additions: [String : String] = [:]
    for (key, value) in environment {
      if !key.hasPrefix(EnvironmentPrefix) {
        continue
      }
      additions[key.replacingOccurrences(of: EnvironmentPrefix, with: "")] = value
    }
    return additions
  }
}
