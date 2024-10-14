import OAuthKit
import Vapor



extension OAuthToken where Self: Authenticatable {
  public static func authenticator() -> AsyncAuthenticator {
    OAuthTokenAuthenticator<Self>()
  }
}


struct OAuthTokenAuthenticator<Token>: OAuthAuthenticator
where Token: OAuthToken & Authenticatable {
  
  func authenticate(token: Token, for request: Request) async throws {
    request.auth.login(token)
  }
}


public protocol OAuthAuthenticator: AsyncBearerAuthenticator {
  associatedtype Token: OAuthToken
  func authenticate(token: Token, for request: Request) async throws
}


extension OAuthAuthenticator {
  public func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
    try await self.authenticate(token: request.oauth.verify(bearer.token), for: request)
  }
}
