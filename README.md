<h2 align="center">OAuth</h2>



### About
Register the oauth service of choice. 
OAuthToken has to conforms to `AuthenticatableOAuthToken`,
including a `authenticate` function.

Register the RouteCollection to serve the route at 
the redirectURI as configured in the service.
As soon as the redirection completes and the bearer token 
is returned and verified, the extended 
Access-Token will be stored within the cache. 
Retrieve the Access-Token from cache at any time for custom operations. 


example Implementation:
```swift
struct EmailAccessToken: GoogleToken, AuthenticatableOAuthToken {
  var endpoint: URL
  
  var accessToken: AccessTokenClaim?
  var email: String?
  var expiresIn: ExpiresInClaim?
  var refreshToken: RefreshTokenClaim?
  var scope: ScopeClaim
  
  func authenticate(token: EmailAccessToken, for request: Vapor.Request) async throws {
    request.auth.login(token) }
}

let tokenEndpoint = "https://oauth2.googleapis.com/token"
let authenticationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
let infoEndpoint = "https://www.googleapis.com/oauth2/v3/userinfo"
guard let infoendpointURL = URL(string: infoEndpoint) 
else { throw Abort(.notFound) }

let clientID = "CLIENT_ID"
let clientSecret = "CLIENT_SECRET"
let redirectURI = "REDIRECT_URI"
let scope = ScopeClaim(stringLiteral: "https://www.googleapis.com/auth/userinfo.email") 
let emailToken = EmailAccessToken(
  endpoint: infoendpointURL, 
  scope: scopeClaim)

let oauthgoogle = GoogleService(
  authenticationEndpoint: authenticationEndpoint,
  tokenEndpoint: tokenEndpoint,
  clientID: clientID,
  clientSecret: clientSecret,
  redirectURI: redirectURI,
  scope: scope)
  
try await app.oauth.google.make(service: oauthGoogle, token: emailToken)
```

### See more:
- https://github.com/bwdmr/oauth-kit

