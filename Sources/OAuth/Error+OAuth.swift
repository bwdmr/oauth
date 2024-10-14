import OAuthKit
import Vapor



extension OAuthError: @retroactive AbortError {
  public var status: HTTPResponseStatus {
    .unauthorized
  }
}
