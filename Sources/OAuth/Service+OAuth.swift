import OAuthKit
import Vapor
import NIOConcurrencyHelpers



extension OAuthService {
  
  @discardableResult
  func register(
    app: Application,
    _ service: any OAuthServiceable,
    router: any OAuthRouteCollection
  ) async throws -> Self {
    try await self.register(service)
    try await app.register(collection: router, service: service)
    
    return self
  }
}
