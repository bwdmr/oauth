import OAuthKit
import Vapor


public protocol AuthenticatableOAuthToken: OAuthToken, Authenticatable, AsyncBearerAuthenticator {
  func authenticate(token: Self, for request: Request) async throws
}

extension AuthenticatableOAuthToken {
  public func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
    try await self.authenticate(token: request.oauth.verify(bearer.token), for: request)
  }
}


