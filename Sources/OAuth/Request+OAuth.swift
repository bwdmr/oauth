import OAuthKit
import Vapor
import NIOConcurrencyHelpers



public extension Request {
  var oauth: OAuth {
    .init(_request: self)
  }
  
  struct OAuth: Sendable {
    public let _request: Request
    
    @discardableResult
    public func redirect<Service>(_ service: Service)
    async throws -> Response where Service: OAuthServiceable
    { 
      let url = try service.authenticationURL()
      return self._request.redirect(to: url.absoluteString)
    }
    
    
    ///
    @discardableResult
    public func verify<Token>(_ token: Token, as _: Token.Type = Token.self)
    async throws -> Token where Token: OAuthToken
    {
      guard let token = self._request.headers.bearerAuthorization?.token else {
        self._request.logger.error("Request is missing OAuth bearer header")
        throw Abort(.unauthorized)
      }
      return try await self.verify(token, as: Token.self)
    }
    
    
    ///
    @discardableResult
    public func verify<Token>(_ message: String, as _: Token.Type = Token.self)
    async throws -> Token where Token: OAuthToken
    {
      try await self.verify([UInt8](message.utf8), as: Token.self)
    }
    
    
    ///
    @discardableResult
    public func verify<Token>(_ message: some DataProtocol & Sendable, as _: Token.Type = Token.self)
    async throws -> Token where Token: OAuthToken {
      try await self._request.application.oauth.services.verify(message, as: Token.self)
    }
  }
}
