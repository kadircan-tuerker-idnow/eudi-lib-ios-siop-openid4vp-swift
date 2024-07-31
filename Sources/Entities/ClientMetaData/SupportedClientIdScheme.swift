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
import JOSESwift

public enum SupportedClientIdScheme {
  public var scheme: ClientIdScheme {
    switch self {
      
    /**
      * The Client Identifier is known to the Wallet in advance of the Authorization Request.
      */
    case .preregistered:
      return .preRegistered
    case .x509SanUri:
      return .x509SanUri
    case .x509SanDns:
      return .x509SanDns
    case .did:
      return .did
    case .verifierAttestation:
      return .verifierAttestation
    case .redirectUri:
        return .redirectUri
    }
  }

  case redirectUri(clientId: String)
  case preregistered(clients: [String: PreregisteredClient])
  case x509SanUri(trust: CertificateTrust)
  case x509SanDns(trust: CertificateTrust)
  case did(lookup: DIDPublicKeyLookupAgent)
  case verifierAttestation(
    trust: Verifier,
    clockSkew: TimeInterval = 15.0
  )
}
