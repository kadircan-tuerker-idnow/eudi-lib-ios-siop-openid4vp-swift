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

public class JWSAlgorithm: JoseAlgorithm {
  
  fileprivate init(_ type: JWSAlgorithmType) {
    super.init(name: type.name, requirement: type.requirement)
  }
  
  public override init(name: String) {
    super.init(name: name)
  }
  
  public override init(name: String, requirement: JoseAlgorithm.Requirement) {
    super.init(name: name, requirement: requirement)
  }
}

public extension JWSAlgorithm {
  static func parse(_ s: String) -> JWSAlgorithm {
    if let type = JWSAlgorithmType(rawValue: s) {
      return .init(type)
    }
    return .init(name: s)
  }
}

fileprivate extension JWSAlgorithm {
  enum JWSAlgorithmType: String {
    case HS256
    case HS384
    case HS512
    case RS256
    case RS384
    case RS512
    case ES256
    case ES256K
    case ES384
    case ES512
    case PS256
    case PS384
    case PS512
    case EdDSA
    
    var name: String {
      return self.rawValue
    }
    
    var requirement: Requirement {
      switch self {
      case .HS256:
        return .REQUIRED
      case .HS384:
        return .OPTIONAL
      case .HS512:
        return .OPTIONAL
      case .RS256:
        return .RECOMMENDED
      case .RS384:
        return .OPTIONAL
      case .RS512:
        return .OPTIONAL
      case .ES256:
        return .RECOMMENDED
      case .ES256K:
        return .OPTIONAL
      case .ES384:
        return .OPTIONAL
      case .ES512:
        return .OPTIONAL
      case .PS256:
        return .OPTIONAL
      case .PS384:
        return .OPTIONAL
      case .PS512:
        return .OPTIONAL
      case .EdDSA:
        return .OPTIONAL
      }
    }
  }
}

public extension JWSAlgorithm {
  class Family: JoseAlgorithmFamily<JWSAlgorithm> {}
}

public extension JWSAlgorithm.Family {
  enum JWSAlgorithmFamilyType {
    case HMAC_SHA
    case RSA
    case EC
    case ED
    case SIGNATURE
  }
  static func parse(_ type: JWSAlgorithmFamilyType) -> JWSAlgorithm.Family {
    
    var RSA: [JWSAlgorithm] {
      return [
        .init(.RS256),
        .init(.RS384),
        .init(.RS512),
        .init(.PS256),
        .init(.PS384),
        .init(.PS512)
      ]
    }
    
    var EC: [JWSAlgorithm] {
      return [
        .init(.ES256),
        .init(.ES256K),
        .init(.ES384),
        .init(.ES512)
      ]
    }
    
    var ED: [JWSAlgorithm] {
      return [
        .init(.EdDSA)
      ]
    }
    
    var SIGNATURE: [JWSAlgorithm] {
      return RSA + EC + ED
    }
    
    switch type {
    case .HMAC_SHA:
      return .init(
        .init(.HS256),
        .init(.HS384),
        .init(.HS512)
      )
    case .RSA:
      return .init(RSA)
    case .EC:
      return .init(EC)
    case .ED:
      return .init(ED)
    case .SIGNATURE:
      return .init(SIGNATURE)
    }
  }
}
