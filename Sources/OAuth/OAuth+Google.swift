import OAuthKit
import Vapor
import NIOConcurrencyHelpers


extension GoogleService.AccessToken: Authenticatable { }

struct OAuthRouteCollection: RouteCollection {
  let service: GoogleService
  let redirectURI: RedirectURIClaim
  
  init(_ service: GoogleService) {
    self.service = service
    self.redirectURI = service.redirectURI
  }
  
  func boot(routes: Vapor.RoutesBuilder) throws {
    let redirectURIString = redirectURI.value
    let redirecturiURL = URI(string: redirectURIString)
    let path = redirecturiURL.path
    
    routes.get(path.pathComponents) { req -> Response in
      let code: String = try req.query.get(at: CodeClaim.key.stringValue)
      let tokenURL = try service.tokenURL(code: code)
      let tokenURI = URI(string: tokenURL.absoluteString)
      let response = try await req.application.client.post(tokenURI)
      
      let token = try response.content.decode(GoogleService.AccessToken.self)
      req.auth.login(token)
      return Response(status: .ok)
    }
  }
}



public extension Request.OAuth {
  var google: Google { .init(_oauth: self) }
 
  
  struct Google: Sendable {
    public let _oauth: Request.OAuth
    
    public func verify() async throws -> GoogleService.AccessToken {
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
