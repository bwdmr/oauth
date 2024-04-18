import OAuthKit
import Vapor
import NIOConcurrencyHelpers



public protocol OAuthHeadToken: OAuthToken, Content, Authenticatable {}


struct OAuthRouter<HeadToken, Service>: OAuthRouteCollection 
where HeadToken: OAuthHeadToken, Service: OAuthServiceable {
  var service: Service
  var head: HeadToken
  
  init(_ service: Service, head: HeadToken) {
    self.service = service
    self.head = head
  }
}


public protocol OAuthRouteCollection<HeadToken, Service>: RouteCollection 
where HeadToken: OAuthHeadToken, Service: OAuthServiceable {
  associatedtype HeadToken
  associatedtype Service
  
  init(_ service: Service, head: HeadToken)
  
  var service: Service { get set }
  var head: HeadToken { get set }
  
  func boot(routes: RoutesBuilder, redirectURI: RedirectURIClaim) async throws
}


extension RoutesBuilder {
  public func register(collection: any OAuthRouteCollection, service: OAuthServiceable) 
  async throws {
    let redirectURI = await service.redirectURI
    try await collection.boot(routes: self, redirectURI: redirectURI)
  }
}


extension OAuthRouteCollection {
  
  func boot(routes: Vapor.RoutesBuilder) throws {
    throw OAuthError.invalidData("router")
  }
  
  public func boot(routes: RoutesBuilder, redirectURI: RedirectURIClaim) 
  async throws {
    let path = URI(string: redirectURI.value).path
    
    routes.get(path.pathComponents) { req -> Response in
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
      
      let token = try tokenResponse.content.decode(HeadToken.self)
      guard let accessToken = token.accessToken,
        let head = await service.head,
        var infoURL = head.endpoint
      else { throw Abort(.internalServerError) }
      
      let accesstokenItem = URLQueryItem(name: AccessTokenClaim.key.stringValue, value: accessToken.value)
      infoURL.append(queryItems: [accesstokenItem])
      
      let infoURI = URI(string: infoURL.absoluteString)
      let infoResponse = try await req.application.client.get(infoURI)
      var info = try infoResponse.content.decode(HeadToken.self)
      try await token.mergeable(&info)
      
      
      req.auth.login(info)
      return Response(status: .ok)
    }
  }
}



extension OAuthService {
  
  @discardableResult
  func register<HeadToken>(app: Application, _ service: any OAuthServiceable, _ use: [OAuthToken], head: HeadToken, router: any OAuthRouteCollection)
  async throws -> Self where HeadToken: OAuthToken {
    try await self.register(service, use, head: head)
    try await app.register(collection: router, service: service)
    
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
    public func make<HeadToken>(service: GoogleService, token: [OAuthToken], head: HeadToken) 
    async throws where HeadToken: OAuthHeadToken  {
      
      let router = OAuthRouter(service, head: head)
      
      try await self._oauth._application.oauth
        .services.register(app: self._oauth._application, service, token, head: head, router: router)
    }
  }
}
