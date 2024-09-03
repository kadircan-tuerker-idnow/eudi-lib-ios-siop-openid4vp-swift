/*
 * Copyright (c) 2023 European Commission
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import Foundation

public enum DispatchOutcome: Codable, Equatable {
  case accepted(redirectURI: URL?)
  case rejected(reason: String)
  case redirectUri(redirectURI: URL?)

  enum CodingKeys: String, CodingKey {
    case accepted
    case rejected
      case redirectUri
  }
}

public extension DispatchOutcome {

  internal init() {
    self = .accepted(redirectURI: nil)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if container.contains(.accepted) {
      let redirectURI = try container.decode(URL?.self, forKey: .accepted)
      self = .accepted(redirectURI: redirectURI)
    } else if container.contains(.rejected) {
      let reason = try container.decode(String.self, forKey: .rejected)
      self = .rejected(reason: reason)
    } else {
      throw DecodingError.dataCorruptedError(
          forKey: CodingKeys.accepted,
          in: container,
          debugDescription: "Invalid DispatchOutcome"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .accepted(let redirectURI):
      try container.encode(redirectURI, forKey: .accepted)
    case .rejected(let reason):
      try container.encode(reason, forKey: .rejected)
    case .redirectUri(let redirectURI):
        try container.encode(redirectURI, forKey: .accepted)
    }
  }
}
