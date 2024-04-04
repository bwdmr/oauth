import OAuthKit
import Vapor


public extension OAuthToken where Self: Authenticatable {
  static func authenticator() -> AsyncAuthenticator {
    OAuthTokenAuthenticator<Self>()
  }
}


private struct OAuthTokenAuthenticator<Token>: OAuthAuthenticator
where Token: OAuthToken & Authenticatable {
  
  func authenticate(token: Token, for request: Request) async throws {
    request.auth.login(token)
  }
}


public protocol OAuthAuthenticator: AsyncBearerAuthenticator {
  associatedtype Token: OAuthToken
  func authenticate(token: Token, for request: Request) async throws
}


public extension OAuthAuthenticator {
  func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
    try await self.authenticate(token: request.oauth.verify(bearer.token), for: request)
  }
}
