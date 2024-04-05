import OAuthKit
import Vapor
import NIOConcurrencyHelpers




public struct GoogleAccessToken: OAuthToken, Authenticatable {
  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case expiresIn = "expires_in"
    case refreshToken = "refresh_token"
    case scope = "scope"
    case tokenType = "token_type"
  }
  
  public let accessToken: AccessTokenClaim
  
  public let expiresIn: ExpiresInClaim
  
  public let refreshToken: RefreshTokenClaim?
  
  public let scope: ScopeClaim
  
  public let tokenType: TokenTypeClaim
  
  public init(
    accessToken: AccessTokenClaim,
    expiresIn: ExpiresInClaim,
    refreshToken: RefreshTokenClaim? = nil,
    scope: ScopeClaim,
    tokenType: TokenTypeClaim = "Bearer"
  ) {
    self.accessToken = accessToken
    self.expiresIn = expiresIn
    self.refreshToken = refreshToken
    self.scope = scope
    self.tokenType = tokenType
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.accessToken = try container.decode(AccessTokenClaim.self, forKey: .accessToken)
    self.expiresIn = try container.decode(ExpiresInClaim.self, forKey: .expiresIn)
    self.refreshToken = try container.decodeIfPresent(RefreshTokenClaim.self, forKey: .refreshToken)
    self.scope = try container.decode(ScopeClaim.self, forKey: .scope)
    self.tokenType = try container.decode(TokenTypeClaim.self, forKey: .tokenType)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(accessToken, forKey: .accessToken)
    try container.encode(expiresIn, forKey: .expiresIn)
    try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
    try container.encode(scope, forKey: .scope)
    try container.encode(tokenType, forKey: .tokenType)
  }
  
  public func verify() async throws {
    try self.expiresIn.verifyNotExpired()
  }
}




struct OAuthRouteCollection: RouteCollection {
  let service: GoogleService
  let redirectURI: RedirectURIClaim
  
  init(_ service: GoogleService) {
    self.service = service
    self.redirectURI = service.redirectURI
  }
  
  func boot(routes: Vapor.RoutesBuilder) throws {
    
    routes.get(redirectURI.value.pathComponents) { req -> Response in
      let code = try req.query.decode(CodeClaim.self)
      let accessURL = try service.accessURL(code: code.value)
      let accessURI = URI(string: accessURL.absoluteString)
      let response = try await req.application.client.post(accessURI)
      let token = try response.content.decode(GoogleAccessToken.self)
      req.auth.login(token)
      return Response(status: .ok)
    }
  }
}



public extension Request.OAuth {
  var google: Google {
    .init(_oauth: self)
  }
  
  
  struct Google: Sendable {
    public let _oauth: Request.OAuth
    
    public func verify() async throws -> GoogleAccessToken {
      guard let token = self._oauth._request.headers.bearerAuthorization?.token else {
        self._oauth._request.logger.error("Request is missing OAuth bearer token.")
        throw Abort(.unauthorized)
      }
      return try await self._oauth.verify(token)
    }
    
    public func redirect() async throws -> Response {
      guard let service = self._oauth._request.application.oauth.google.service else { throw Abort(.internalServerError) }
      return try await self._oauth.redirect(service)
    }
  }
}




public extension Application.OAuth {
  var google: Google {
    .init(_oauth: self)
  }
  
  struct Google: Sendable {
    public let id: OAuthIdentifier = OAuthIdentifier("google")
    
    public let _oauth: Application.OAuth
    
    private struct Key: StorageKey, LockKey {
      typealias Value = Storage
    }
    
    public final class Storage: Sendable {
      private struct SendableBox: Sendable {
        var service: GoogleService?
      }
      
      private let sendableBox: NIOLockedValueBox<SendableBox>
      
      var service: GoogleService? {
        get {
          self.sendableBox.withLockedValue { box in
            box.service
          }
        }
        set {
          self.sendableBox.withLockedValue { box in
            box.service = newValue
          }
        }
      }
      
      init() {
        let box = SendableBox()
        self.sendableBox = .init(box)
      }
    }
    
    init(_oauth: Application.OAuth) {
      self._oauth = _oauth
    }
    
    
    ///
    private (set) var service: GoogleService? {
      get {
        self.storage.service
      }
      nonmutating set {
        self.storage.service = newValue
      }
    }
    
    ///
    private var storage: Storage {
      if let existing = self._oauth._application.storage[Key.self] {
        return existing }
      
      else {
        let lock = self._oauth._application.locks.lock(for: Key.self)
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = self._oauth._application.storage[Key.self] {
          return existing }
        
        let new = Storage()
        self._oauth._application.storage[Key.self] = new
        return new
      }
    }
    
    public func make(service: GoogleService) async throws {
      guard let id = service.oauthIdentifier else { throw Abort(.internalServerError) }
      self.service = service
      try await self._oauth._application.oauth.services.add(service, for: id)
      try self._oauth._application.register(collection: OAuthRouteCollection(service))
    }
  }
}
