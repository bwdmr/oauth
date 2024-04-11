import OAuthKit
import Vapor



public extension OAuthHeadToken where Self: Authenticatable {
  static func authenticator() -> AsyncAuthenticator {
    OAuthAccessAuthenticator<Self>()
  }
}


private struct OAuthAccessAuthenticator<Token>: OAuthAuthenticator
where Token: OAuthHeadToken & Authenticatable {
  func authenticate(token: Token, for request: Request) async throws {
    request.auth.login(token)
  }
}


public protocol OAuthAuthenticator: AsyncBearerAuthenticator {
  associatedtype Token: OAuthHeadToken
  func authenticate(token: Token, for request: Request) async throws
}


public extension OAuthAuthenticator {
  func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
    try await self.authenticate(token: request.oauth.verify(bearer.token), for: request)
  }
}
