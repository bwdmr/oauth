import OAuthKit
import Vapor
import NIOConcurrencyHelpers



extension OAuthService {
  
  @discardableResult
  func register<Token>(
    app: Application,
    _ service: any OAuthServiceable,
    router: any OAuthRouteCollection,
    token: Token
  ) async throws -> Self where Token: AuthenticatableOAuthToken {
    try await self.register(service)
    try await app.register(collection: router, service: service, token: token)
    
    return self
  }
}
