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

/// A protocol for an authorization service.
public protocol AuthorisationServiceType {
  /// Posts a response and returns a generic result.
  func formPost<T: Codable>(poster: Posting, response: AuthorizationResponse) async throws -> T
  /// Posts a response and returns a success boolean.
  func formCheck(poster: Posting, response: AuthorizationResponse) async throws -> DispatchOutcome
}

/// An implementation of the `AuthorisationServiceType` protocol.
public actor AuthorisationService: AuthorisationServiceType {

  var joseResponse: String?
  
  public init() { }

  /// Posts a response and returns a generic result.
  public func formPost<T: Codable>(
    poster: Posting = Poster(),
    response: AuthorizationResponse
  ) async throws -> T {
    switch response {
    case .directPost(let url, let data):
      let post = VerifierFormPost(
        additionalHeaders: ["Content-Type": ContentType.form.rawValue],
        url: url,
        formData: try data.toDictionary()
      )

      let result: Result<T, PostError> = await poster.post(
        request: post.urlRequest
      )
      return try result.get()
    default: throw AuthorizationError.invalidResponseMode
    }
  }

  /// Posts a response and returns a success boolean.
  public func formCheck(poster: Posting, response: AuthorizationResponse) async throws -> DispatchOutcome {
    switch response {
    case .directPost(let url, let data):
      
      let payload = setupDirectPostPayload(
        key: Constants.presentationSubmissionKey,
        dictionary: try? data.toDictionary()
      )
      
      let post = VerifierFormPost(
        additionalHeaders: ["Content-Type": ContentType.form.rawValue],
        url: url,
        formData: payload
      )

      let result: Result<(String, Bool), PostError> = await poster.check(key: "redirect_uri", request: post.urlRequest)
        let response = try result.get()
        return response.1 == true ? .accepted(redirectURI: URL(string: response.0)) : .rejected(reason: "")
    case .directPostJwt(let url, let data, let jarmSpec):
      let encryptor = ResponseSignerEncryptor()
      let joseResponse = try await encryptor.signEncryptResponse(spec: jarmSpec, data: data)
      
      let dictionary = try data.toDictionary()
      let payload = dictionary.merging([
        "state": dictionary["state"] ?? "",
        "response": joseResponse
      ], uniquingKeysWith: { _, new in
        new
      })
      
      let post = VerifierFormPost(
        additionalHeaders: ["Content-Type": ContentType.form.rawValue],
        url: url,
        formData: payload
      )
      
      self.joseResponse = joseResponse
      
      let result: Result<(String, Bool), PostError> = await poster.check(key: "redirect_uri", request: post.urlRequest)
        let response = try result.get()
        return response.1 == true ? .accepted(redirectURI: URL(string: response.0)) : .rejected(reason: "")
      
    case .query, .queryJwt, .fragmentJwt:
      throw AuthorizationError.invalidResponseMode
    case .fragment(let url, let data):
        switch data {
        case .openId4VPAuthorizationResponse(let vpToken, let verifiableCredential, let presentationSubmission, let state, let nonce):
            let urlString = url.absoluteString
            let serialised = try JSONEncoder().encode(presentationSubmission)
            guard let json = String(data: serialised, encoding: .utf8) else { throw AuthorizationError.invalidResponseMode}
            let redirectUri = "\(urlString)#vp_token=\(vpToken)&presentation_submission=\(json)"
            guard let redirectURL = URL(string: redirectUri) else {
                throw AuthorizationError.invalidResponseMode
            }
            return .redirectUri(redirectURI: redirectURL)

        default:
            throw AuthorizationError.invalidResponseMode
        }
    }
  }
}

private extension AuthorisationService {
  func setupDirectPostPayload(
    key: String,
    dictionary: [String: Any]?
  ) -> [String: Any] {
    
    guard let dictionary = dictionary else { return [:] }
    
    let value = dictionary[key] as? [String: Any]
    let presentationSubmission: String? = value?.toJSONString() ?? ""
    
    return dictionary
      .filter { $0.key != Constants.presentationSubmissionKey }
      .merging([Constants.presentationSubmissionKey: presentationSubmission as Any], uniquingKeysWith: { _, new in new })
      .compactMapValues { $0 }
      .filter { key, value in
        if let value = value as? String {
          return !value.isEmpty
        }
        return true
      }
  }
}
