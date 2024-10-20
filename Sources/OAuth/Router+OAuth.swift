import OAuthKit
import Vapor
import NIOConcurrencyHelpers

import Logging



struct OAuthRouter<Service>: OAuthRouteCollection
where Service: OAuthServiceable {
  typealias Service = Service
  
  var service: Service

  init(_ service: Service) {
    self.service = service }
}


public protocol OAuthRouteCollection<Service>: Sendable, RouteCollection
where Service: OAuthServiceable {
  associatedtype Service
  
  init(_ service: Service)
  
  var service: Service { get set }
  
  func boot<Token>(
    routes: RoutesBuilder,
    redirectURI: RedirectURIClaim,
    token: Token)
  
  async throws where Token: AuthenticatableOAuthToken
}


extension RoutesBuilder {
  public func register<Token>(
    collection: any OAuthRouteCollection,
    service: OAuthServiceable,
    token: Token
  ) async throws where Token: AuthenticatableOAuthToken {
    let redirectURI = await service.redirectURI
    
    try await collection.boot(
      routes: self,
      redirectURI: redirectURI,
      token: token)
  }
}



extension OAuthRouteCollection {
  
  func boot(routes: Vapor.RoutesBuilder) throws {
    throw OAuthError.invalidData("router")
  }
  
  public func boot<Token>(
    routes: RoutesBuilder,
    redirectURI: RedirectURIClaim,
    token: Token
  ) async throws where Token: AuthenticatableOAuthToken {
    let path = URI(string: redirectURI.value).path
    let pathComponents = path.pathComponents
    
    
    routes.get(pathComponents) { request async throws in
      
      let code = try request.query.get(String.self, at: "code")
      let tokenURL = try await service.tokenURL(code: code)
      let _tokenURL = tokenURL.0
      let _tokenData = tokenURL.1
      
      let tokenURI = URI(string: _tokenURL.absoluteString)
      
      let tokenResponse = try await request.application.client
        .post(tokenURI, beforeSend: { request in
          
          request.headers.add(
            name: "Content-Type",
            value: "application/x-www-form-urlencoded")
          
          let byteBuffer = ByteBuffer(bytes: _tokenData)
          request.body = byteBuffer
        })
      
      let accessToken = try tokenResponse.content.decode(Token.self)
      try await token.authenticate(
          token: accessToken,
          for: request)
      return Response(status: .ok)
    }
  }
}
