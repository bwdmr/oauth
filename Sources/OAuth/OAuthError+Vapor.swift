import OAuthKit
import Vapor

extension OAuthError: AbortError {
  public var status: HTTPResponseStatus {
    .unauthorized
  }
}
