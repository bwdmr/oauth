import OAuthKit
import Vapor
import NIOConcurrencyHelpers



public protocol OAuthHeadToken: OAuthToken, Content, Authenticatable {}


public protocol OAuthRouteCollection<T, U>: RouteCollection where T: OAuthHeadToken, U: OAuthServiceable {
  associatedtype T
  associatedtype U
  
  var service: U { get set }
  
  init(_ service: U)
  
  func boot(routes: RoutesBuilder) async throws
}


extension OAuthRouteCollection {
  
  public func boot(routes: RoutesBuilder) async throws {
    let pathString = await self.service.redirectURI.value
    
    routes.get(pathString.pathComponents) { req -> Response in
      let code: String = try req.query.get(at: CodeClaim.key.stringValue)
      
      let tokenURL = try await service.tokenURL(code: code)
      let _tokenURL = tokenURL.0
      let _tokenData = tokenURL.1
      let tokenURI = URI(string: _tokenURL.absoluteString)
      let tokenResponse = try await req.application.client.post(tokenURI, beforeSend: { req in

        req.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        let byteBuffer = ByteBuffer(bytes: _tokenData)
        req.body = byteBuffer
      })
      
      let accessToken = try tokenResponse.content.decode(T.self)
      
      guard let head = await service.head else { throw Abort(.notFound) }
      let infoURL = head.endpoint
      let infoURI = URI(string: infoURL.absoluteString)
      let infoResponse = try await req.application.client.post(infoURI, beforeSend: { req in
        try req.content.encode(accessToken) })
      var infoToken = try infoResponse.content.decode(T.self)
      try await accessToken.mergeable(&infoToken)
      
      req.auth.login(infoToken)
      
      return Response(status: .ok)
    }
  }
}



extension OAuthService {
  
  @discardableResult
  func register(
    app: Application, 
    _ service: OAuthServiceable,
    _ use: [OAuthToken],
    head: String,
    router: any OAuthRouteCollection
  ) async throws -> Self {
    try await self.register(service, use, head: head)
    try app.register(collection: router)
    
    return self
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
    public func make(service: GoogleService, token: [OAuthToken], head: String, router: any OAuthRouteCollection) async throws {
      try await self._oauth._application.oauth
        .services.register(app: self._oauth._application, service, token, head: head, router: router)
    }
  }
}
