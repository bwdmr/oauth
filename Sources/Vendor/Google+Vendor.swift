import OAuthKit
import Vapor
import NIOConcurrencyHelpers



extension Request.OAuth {
  public var google: Google { .init(_oauth: self) }
  
  public struct Google: Sendable {
    public let _oauth: Request.OAuth
    
    public func redirect() async throws -> Response {
      guard let service = self._oauth._request.application.oauth.google.service else {
        throw Abort(.internalServerError) }
      
      return try await self._oauth.redirect(service)
    }
  }
}


extension Application.OAuth {
  public var google: Google {
    .init(_oauth: self)
  }
  
  public struct Google: Sendable {
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
    private(set) var service: GoogleService? {
      get { self.storage.service }
      nonmutating set { self.storage.service = newValue }
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
    public func make<Token>(service: GoogleService) where Token: GoogleToken & Authenticatable {
      let router = OAuthRouter<GoogleService, Token>(service)
      
      try await self._oauth._application.oauth
        .services.register(app: self._oauth._application, service, router: router)
    }
  }
}
