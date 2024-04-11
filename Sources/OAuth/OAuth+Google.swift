import OAuthKit
import Vapor
import NIOConcurrencyHelpers



public protocol OAuthHeadToken: GoogleToken, Content, Authenticatable {}


struct OAuthRouteCollection: RouteCollection {
  let token: any OAuthHeadToken
  let service: GoogleService
  let redirectURI: RedirectURIClaim
  
  init(_ service: GoogleService, token: any OAuthHeadToken) async {
    self.service = service
    self.redirectURI = await service.redirectURI
    self.token = token
  }
  
  public func decodeFromResponse<Token>(_ content: ContentContainer, _ as: Token)
  throws -> Token where Token: Content {
    return try content.decode(Token.self)
  }

  func boot(routes: Vapor.RoutesBuilder) throws {
    let redirectURIString = redirectURI.value
    let redirecturiURL = URI(string: redirectURIString)
    let path = redirecturiURL.path
    
    routes.get(path.pathComponents) { req -> Response in
      let code: String = try req.query.get(at: CodeClaim.key.stringValue)
      
      let tokenURL = try await service.tokenURL(code: code)
      let tokenURI = URI(string: tokenURL.absoluteString)
      let tokenResponse = try await req.application.client.post(tokenURI)
      let accessToken = try self.decodeFromResponse(tokenResponse.content, token)
      
      let infoURL = token.endpoint
      let infoURI = URI(string: infoURL.absoluteString)
      let infoResponse = try await req.application.client.post(infoURI, beforeSend: { req in
        try req.content.encode(accessToken) })
      var infoToken = try self.decodeFromResponse(infoResponse.content, token)
      try await accessToken.mergeable(&infoToken)
      req.auth.login(infoToken)
      
      return Response(status: .ok)
    }
  }
}



public extension Request.OAuth {
  var google: Google { .init(_oauth: self) }
  
  struct Google: Sendable {
    public let _oauth: Request.OAuth
    
    public func redirect() async throws -> Response {
      guard let service = self._oauth._request.application.oauth.google.service else {
        throw Abort(.internalServerError) }
      
      return try await self._oauth.redirect(service)
    }
  }
}



public extension Application.OAuth {
  var google: Google {
    .init(_oauth: self)
  }
  
  struct Google: Sendable {
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
    
    ///
    public func make(service: GoogleService, token: [OAuthToken], head: String) async throws {
      guard let headToken = token.first(where: {
        $0.scope.value.contains(head) && ($0.self as Any) is Authenticatable.Type
      }) else { throw Abort(.internalServerError) }
      
      self.service = service
      try await self._oauth._application.oauth
        .services.register(service, token, head: head)
      
      try await self._oauth._application.register(
        collection: OAuthRouteCollection(service, token: headToken as! (any OAuthHeadToken)))
    }
  }
}
