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
import PresentationExchange
import JOSESwift
import X509

// Enum defining the types of validated SIOP OpenID4VP requests
public enum ValidatedSiopOpenId4VPRequest {
  case idToken(request: IdTokenRequest)
  case vpToken(request: VpTokenRequest)
  case idAndVpToken(request: IdAndVpTokenRequest)
}

// Extension for ValidatedSiopOpenId4VPRequest
public extension ValidatedSiopOpenId4VPRequest {

  // Initialize with a request URI
  init(
    requestUri: JWTURI,
    clientId: String?,
    walletConfiguration: WalletOpenId4VPConfiguration? = nil
  ) async throws {
    // Convert request URI to URL
    guard let requestUrl = URL(string: requestUri) else {
      throw ValidatedAuthorizationError.invalidRequestUri(requestUri)
    }

    let jwt = try await ValidatedSiopOpenId4VPRequest.fetchJwtString(
      fetcher: Fetcher(session: walletConfiguration?.session ?? URLSession.shared),
      requestUrl: requestUrl
    )

    // Extract the payload from the JSON Web Token
    guard let payload = JSONWebToken(jsonWebToken: jwt)?.payload else {
      throw ValidatedAuthorizationError.invalidAuthorizationData
    }

    // Extract the client ID and nonce from the payload
    guard let payloadcClientId = payload[Constants.CLIENT_ID] as? String else {
      throw ValidatedAuthorizationError.missingRequiredField(".clientId")
    }

    guard let nonce = payload[Constants.NONCE] as? String else {
      throw ValidatedAuthorizationError.missingRequiredField(".nonce")
    }

    let clientIdScheme = payload[Constants.CLIENT_ID_SCHEME] as? String
      
    if let clientId = clientId {
      if payloadcClientId != clientId {
        throw ValidatedAuthorizationError.clientIdMismatch(clientId, payloadcClientId)
      }
    }

    // Determine the response type from the payload
    let responseType = try ResponseType(authorizationRequestObject: payload)

    try await ValidatedSiopOpenId4VPRequest.validateSignature(
      token: jwt,
      clientId: clientId,
      walletConfiguration: walletConfiguration
    )
    
    let client = try Self.getClient(
      clientId: payloadcClientId,
      jwt: jwt,
      config: walletConfiguration, 
      scheme: clientIdScheme
    )
    
    // Initialize the validated request based on the response type
    switch responseType {
    case .idToken:
      self = try ValidatedSiopOpenId4VPRequest.createIdToken(
        clientId: payloadcClientId,
        client: client,
        nonce: nonce,
        authorizationRequestObject: payload
      )
    case .vpToken:
      self = try ValidatedSiopOpenId4VPRequest.createVpToken(
        clientId: payloadcClientId,
        client: client,
        nonce: nonce,
        authorizationRequestObject: payload
      )
    case .vpAndIdToken:
      self = try ValidatedSiopOpenId4VPRequest.createIdVpToken(
        clientId: payloadcClientId,
        client: client,
        nonce: nonce,
        authorizationRequestObject: payload
      )
    case .code:
      throw ValidatedAuthorizationError.unsupportedResponseType(".code")
    }
  }

  // Initialize with a JWT string
  init(
    request: JWTString,
    walletConfiguration: WalletOpenId4VPConfiguration? = nil
  ) async throws {
    
    // Create a JSONWebToken from the JWT string
    let jsonWebToken = JSONWebToken(jsonWebToken: request)

    // Extract the payload from the JSON Web Token
    guard let payload = jsonWebToken?.payload else {
      throw ValidatedAuthorizationError.invalidAuthorizationData
    }

    // Extract the client ID and nonce from the payload
    guard let clientId = payload[Constants.CLIENT_ID] as? String else {
      throw ValidatedAuthorizationError.missingRequiredField(".clientId")
    }

    guard let nonce = payload[Constants.NONCE] as? String else {
      throw ValidatedAuthorizationError.missingRequiredField(".nonce")
    }

    let clientIdScheme = payload[Constants.CLIENT_ID_SCHEME] as? String

    // Determine the response type from the payload
    let responseType = try ResponseType(authorizationRequestObject: payload)

    try await ValidatedSiopOpenId4VPRequest.validateSignature(
      token: request,
      clientId: clientId,
      walletConfiguration: walletConfiguration
    )
    
    let client = try Self.getClient(
      clientId: clientId,
      jwt: request,
      config: walletConfiguration, 
      scheme: clientIdScheme
    )
    
    // Initialize the validated request based on the response type
    switch responseType {
    case .idToken:
      self = try ValidatedSiopOpenId4VPRequest.createIdToken(
        clientId: clientId,
        client: client,
        nonce: nonce,
        authorizationRequestObject: payload
      )
    case .vpToken:
      self = try ValidatedSiopOpenId4VPRequest.createVpToken(
        clientId: clientId,
        client: client,
        nonce: nonce,
        authorizationRequestObject: payload
      )
    case .vpAndIdToken:
      self = try ValidatedSiopOpenId4VPRequest.createIdVpToken(
        clientId: clientId,
        client: client,
        nonce: nonce,
        authorizationRequestObject: payload
      )
    case .code:
      throw ValidatedAuthorizationError.unsupportedResponseType(".code")
    }
  }

  // Initialize with an AuthorisationRequestObject object
  init(
    authorizationRequestData: AuthorisationRequestObject,
    walletConfiguration: WalletOpenId4VPConfiguration? = nil
  ) async throws {
    if let request = authorizationRequestData.request {
      try await self.init(request: request, walletConfiguration: walletConfiguration)
      
    } else if let requestUrl = authorizationRequestData.requestUri {
      try await self.init(requestUri: requestUrl, clientId: authorizationRequestData.clientId, walletConfiguration: walletConfiguration)
      
    } else {
      // Determine the response type from the authorization request data
      let responseType = try ResponseType(authorizationRequestData: authorizationRequestData)

      // Extract the nonce from the authorization request data
      guard let nonce = authorizationRequestData.nonce else {
        throw ValidatedAuthorizationError.missingRequiredField(".nonce")
      }

      // Extract the client ID from the authorization request data
      guard let clientId = authorizationRequestData.clientId else {
        throw ValidatedAuthorizationError.missingRequiredField(".clientId")
      }

      // Initialize the validated request based on the response type
      switch responseType {
      case .idToken:
        do {
          self = .idToken(request: .init(
            idTokenType: try .init(authorizationRequestData: authorizationRequestData),
            clientMetaDataSource: .init(authorizationRequestData: authorizationRequestData),
            clientIdScheme: try .init(authorizationRequestData: authorizationRequestData),
            clientId: clientId, 
            client: .preRegistered(clientId: clientId, legalName: clientId),
            nonce: nonce,
            scope: authorizationRequestData.scope,
            responseMode: try? .init(authorizationRequestData: authorizationRequestData),
            state: authorizationRequestData.state
          ))
        } catch { throw ValidatedAuthorizationError.conflictingData }
      case .vpToken:
        self = try ValidatedSiopOpenId4VPRequest.createVpToken(
          clientId: clientId,
          nonce: nonce,
          authorizationRequestData: authorizationRequestData
        )
      case .vpAndIdToken:
        self = .idAndVpToken(request: .init(
          idTokenType: try .init(authorizationRequestData: authorizationRequestData),
          presentationDefinitionSource: try .init(authorizationRequestData: authorizationRequestData),
          clientMetaDataSource: .init(authorizationRequestData: authorizationRequestData),
          clientIdScheme: try .init(authorizationRequestData: authorizationRequestData),
          clientId: clientId, 
          client: .preRegistered(clientId: clientId, legalName: clientId),
          nonce: nonce,
          scope: authorizationRequestData.scope,
          responseMode: try? .init(authorizationRequestData: authorizationRequestData),
          state: authorizationRequestData.state
        ))
      case .code: throw ValidatedAuthorizationError.unsupportedResponseType(".code")
      }
    }
  }

  fileprivate struct ResultType: Codable {}
  fileprivate static func fetchJwtString(
    fetcher: Fetcher<ResultType> = Fetcher(),
    requestUrl: URL
  ) async throws -> String {
    let jwtResult = try await fetcher.fetchString(url: requestUrl)
    switch jwtResult {
    case .success(let string):
      return try ValidatedSiopOpenId4VPRequest.extractJWT(string)
    case .failure: throw ValidatedAuthorizationError.invalidJwtPayload
    }
  }
}

public extension ValidatedSiopOpenId4VPRequest {
  static func getClient(
    clientId: String,
    jwt: JWTString,
    config: WalletOpenId4VPConfiguration?,
    scheme: String?
  ) throws -> Client {
    guard
        let scheme: SupportedClientIdScheme = config?.supportedClientIdSchemes.first(where: { $0.scheme.rawValue == scheme }) ?? config?.supportedClientIdSchemes.first
    else {
      throw ValidatedAuthorizationError.validationError("No supported client Id scheme")
    }
    
    switch scheme {
    case .preregistered(let clients):
      guard let client = clients[clientId] else {
        throw ValidatedAuthorizationError.validationError("preregistered client nort found")
      }
      return .preRegistered(
        clientId: clientId,
        legalName: client.legalName
      )
        
    case .redirectUri(let clientId):
        guard let clientIdURL = URL(string: clientId) else {
            throw ValidatedAuthorizationError.validationError("redirectUri client not found")
        }
        return .redirectUri(clientId: clientIdURL)

    case .x509SanUri,
         .x509SanDns:
      guard let jws = try? JWS(compactSerialization: jwt) else {
        throw ValidatedAuthorizationError.validationError("Unable to process JWT")
      }

      guard let chain: [String] = jws.header.x5c else {
        throw ValidatedAuthorizationError.validationError("No certificate in header")
      }

      let certificates: [Certificate] = parseCertificates(from: chain)
      guard let certificate = certificates.first else {
        throw ValidatedAuthorizationError.validationError("No certificate in chain")
      }

      return .x509SanUri(
        clientId: clientId,
        certificate: certificate
      )
        
    case .did(let keyLookup):
      return try Self.didPublicKeyLookup(
        jws: try JWS(compactSerialization: jwt),
        clientId: clientId,
        keyLookup: keyLookup
      )

    case .verifierAttestation: //(let trust, let clockSkew):
        throw ValidatedAuthorizationError.validationError("Verifier Attestation not supported")
    }
  }
}

// Private extension for ValidatedSiopOpenId4VPRequest
private extension ValidatedSiopOpenId4VPRequest {
  
  private static func verifierAttestation() {

  }

  private static func didPublicKeyLookup(
    jws: JWS,
    clientId: String,
    keyLookup: DIDPublicKeyLookupAgent
  ) throws -> Client {

    guard let kid = jws.header.kid else {
      throw ValidatedAuthorizationError.validationError("kid not found in JWT header")
    }

    guard
      let keyUrl = AbsoluteDIDUrl.parse(kid),
      keyUrl.string.hasPrefix(clientId)
    else {
      throw ValidatedAuthorizationError.validationError("kid not found in JWT header")
    }

    guard let clientIdAsDID = DID.parse(clientId) else {
      throw ValidatedAuthorizationError.validationError("Invalid DID")
    }

    guard let publicKey = keyLookup(clientIdAsDID) else {
      throw ValidatedAuthorizationError.validationError("Unable to extract public key from DID")
    }

    try JarJwtSignatureValidator.verifyJWS(
      jws: jws,
      publicKey: publicKey
    )

    return .didClient(
      did: clientIdAsDID
    )
  }

  static func validateSignature(
    token: JWTString,
    clientId: String?,
    walletConfiguration: WalletOpenId4VPConfiguration? = nil
  ) async throws {
    
    let validator = JarJwtSignatureValidator(walletOpenId4VPConfig: walletConfiguration)
    try? await validator.validate(clientId: clientId, jwt: token)
  }
  
  // Create a VP token request
  static func createVpToken(
    clientId: String,
    nonce: String,
    authorizationRequestData: AuthorisationRequestObject
  ) throws -> ValidatedSiopOpenId4VPRequest {
    .vpToken(request: .init(
      presentationDefinitionSource: try .init(authorizationRequestData: authorizationRequestData),
      clientMetaDataSource: .init(authorizationRequestData: authorizationRequestData),
      clientIdScheme: try .init(authorizationRequestData: authorizationRequestData),
      clientId: clientId, 
      client: .redirectUri(clientId: URL(string: clientId)!),
      nonce: nonce,
      responseMode: try? .init(authorizationRequestData: authorizationRequestData),
      state: authorizationRequestData.state
    ))
  }

  // Create an ID token request
  static func createIdToken(
    clientId: String,
    client: Client,
    nonce: String,
    authorizationRequestObject: JSONObject
  ) throws -> ValidatedSiopOpenId4VPRequest {
    .idToken(request: .init(
      idTokenType: try .init(authorizationRequestObject: authorizationRequestObject),
      clientMetaDataSource: .init(authorizationRequestObject: authorizationRequestObject),
      clientIdScheme: try .init(authorizationRequestObject: authorizationRequestObject),
      clientId: clientId, 
      client: client,
      nonce: nonce,
      scope: authorizationRequestObject[Constants.SCOPE] as? String ?? "",
      responseMode: try? .init(authorizationRequestObject: authorizationRequestObject),
      state: authorizationRequestObject[Constants.STATE] as? String
    ))
  }

  // Create a VP token request
  static func createVpToken(
    clientId: String,
    client: Client,
    nonce: String,
    authorizationRequestObject: JSONObject
  ) throws -> ValidatedSiopOpenId4VPRequest {
    .vpToken(request: .init(
      presentationDefinitionSource: try .init(authorizationRequestObject: authorizationRequestObject),
      clientMetaDataSource: .init(authorizationRequestObject: authorizationRequestObject),
      clientIdScheme: try .init(authorizationRequestObject: authorizationRequestObject),
      clientId: clientId, 
      client: client,
      nonce: nonce,
      responseMode: try? .init(authorizationRequestObject: authorizationRequestObject),
      state: authorizationRequestObject[Constants.STATE] as? String
    ))
  }

  // Create an ID and VP token request
  static func createIdVpToken(
    clientId: String,
    client: Client,
    nonce: String,
    authorizationRequestObject: JSONObject
  ) throws -> ValidatedSiopOpenId4VPRequest {
    .idAndVpToken(request: .init(
      idTokenType: try .init(authorizationRequestObject: authorizationRequestObject),
      presentationDefinitionSource: try .init(authorizationRequestObject: authorizationRequestObject),
      clientMetaDataSource: .init(authorizationRequestObject: authorizationRequestObject),
      clientIdScheme: try .init(authorizationRequestObject: authorizationRequestObject),
      clientId: clientId, 
      client: client,
      nonce: nonce,
      scope: authorizationRequestObject[Constants.SCOPE] as? String ?? "",
      responseMode: try? .init(authorizationRequestObject: authorizationRequestObject),
      state: authorizationRequestObject[Constants.STATE] as? String
    ))
  }

  /// Extracts the JWT token from a given JSON string or JWT string.
  /// - Parameter string: The input string containing either a JSON object with a JWT field or a JWT string.
  /// - Returns: The extracted JWT token.
  /// - Throws: An error of type `ValidatedAuthorizationError` if the input string is not a valid JSON or JWT, or if there's a decoding error.
  private static func extractJWT(_ string: String) throws -> String {
    if string.isValidJSONString {
      if let jsonData = string.data(using: .utf8) {
        do {
          let decodedObject = try JSONDecoder().decode(RemoteJWT.self, from: jsonData)
          return decodedObject.jwt
        } catch {
          throw error
        }
      } else {
        throw ValidatedAuthorizationError.invalidJwtPayload
      }
    } else {
      if string.isValidJWT() {
        return string
      } else {
        throw ValidatedAuthorizationError.invalidJwtPayload
      }
    }
  }
}
