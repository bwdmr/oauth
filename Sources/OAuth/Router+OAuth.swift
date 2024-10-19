import OAuthKit
import Vapor
import NIOConcurrencyHelpers

import Logging



struct OAuthRouter<Service, Token>: OAuthRouteCollection
where Service: OAuthServiceable, Token: OAuthToken & Authenticatable {
  typealias Service = Service
  typealias Token = Token
  
  var service: Service
  
  init(_ service: Service) {
    self.service = service }
}


public protocol OAuthRouteCollection<Service, Token>: Sendable, RouteCollection
where Service: OAuthServiceable, Token: OAuthToken & Authenticatable {
  associatedtype Service
  associatedtype Token
  
  init(_ service: Service)
  
  var service: Service { get set }
  
  func boot(routes: RoutesBuilder, redirectURI: RedirectURIClaim) async throws
}


extension RoutesBuilder {
  public func register(
    collection: any OAuthRouteCollection,
    service: OAuthServiceable
  ) async throws {
    let redirectURI = await service.redirectURI
    try await collection.boot(routes: self, redirectURI: redirectURI)
  }
}


extension OAuthRouteCollection {
  
  func boot(routes: Vapor.RoutesBuilder) throws {
    throw OAuthError.invalidData("router")
  }
  
  public func boot(
    routes: RoutesBuilder,
    redirectURI: RedirectURIClaim
  ) async throws {
    let logger = Logger(label: "beet")
    
    let path = URI(string: redirectURI.value).path
    let pathComponents = path.pathComponents
    
    routes.get(pathComponents) { request async throws -> Response in
      let code = try request.query.get(String.self, at: "code")
      
      let tokenURL = try await service.tokenURL(code: code)
      let _tokenURL = tokenURL.0
      let _tokenData = tokenURL.1
      
      let tokenURI = URI(string: _tokenURL.absoluteString)
      
      let tokenResponse = try await request.application.client.post(tokenURI, beforeSend: {
        request in
        
          request.headers.add(
            name: "Content-Type", value: "application/x-www-form-urlencoded")
          let byteBuffer = ByteBuffer(bytes: _tokenData)
          request.body = byteBuffer })
     
      logger.log(level: .info, "response")
      let accessToken = try tokenResponse.content.decode(Token.self)
      logger.log(level: .info, "\(accessToken)")
      let authenticator = Token.authenticator() as! OAuthTokenAuthenticator<Token>
      try await authenticator.authenticate(token: accessToken, for: request)
      return Response.init(status: .ok)
    }
  }
}
