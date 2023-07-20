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

extension ValidatedSiopOpenId4VPRequest {
  public struct IdTokenRequest {
    let idTokenType: IdTokenType
    let clientMetaDataSource: ClientMetaDataSource?
    let clientIdScheme: ClientIdScheme?
    let clientId: String
    let nonce: String
    let scope: Scope?
    let responseMode: ResponseMode?
    let state: String?

    public init(
      idTokenType: IdTokenType,
      clientMetaDataSource: ClientMetaDataSource?,
      clientIdScheme: ClientIdScheme?,
      clientId: String,
      nonce: String,
      scope: Scope?,
      responseMode: ResponseMode?,
      state: String?
    ) {
      self.idTokenType = idTokenType
      self.clientMetaDataSource = clientMetaDataSource
      self.clientIdScheme = clientIdScheme
      self.clientId = clientId
      self.nonce = nonce
      self.scope = scope
      self.responseMode = responseMode
      self.state = state
    }
  }
}
