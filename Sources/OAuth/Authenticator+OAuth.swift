import OAuthKit
import Vapor
import Logging



public protocol OAuthAuthenticator: Sendable, AsyncBearerAuthenticator {
  associatedtype Token: Authenticatable & OAuthToken
  func authenticate(token: Token, for request: Request) async throws
}


extension OAuthAuthenticator {
  public func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
    try await self.authenticate(token: request.oauth.verify(bearer.token), for: request)
  }
}
