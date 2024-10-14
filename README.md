<h2 align="center">OAuth</h2>



### About
Register the oauth service of choice. 
OAuthToken has to conforms to Authenticatable. 

Register the RouteCollection to serve the route at the redirectURI as configured in the service.
As soon as the redirection completes and the bearer token is returned and verified, the extended 
Access-Token will be stored within the cache. 

Retrieve the Access-Token from cache at any time for custom operations. 


example Token:
  - only endpoint and scope have to be ddefined
  - in this example it is: `email`
  - exemplatory scope is: `https://www.googleapis.com/auth/userinfo.email`,
  - and the dedicated endpoint would be: `https://www.googleapis.com/oauth2/v3/userinfo`

```swift
struct EmailAccessToken: GoogleToken {
  var endpoint: URL
  
  var accessToken: AccessTokenClaim?
  
  var email: String?
  
  var expiresIn: ExpiresInClaim?
  
  var refreshToken: RefreshTokenClaim?
  
  var scope: ScopeClaim
}

let accessToken = EmailAccessToken(endpoint: emailendpointURL, scope: scopeClaim)
```


example Service:
```swift
let authenticationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
let tokenEndpoint = "https://oauth2.googleapis.com/token"
let clientID = "CLIENT_ID"
let clientSecret = "CLIENT_SECRET"
let redirectURI = "REDIRECT_URI"
let scope = ScopeClaim(stringLiteral: "https://www.googleapis.com/auth/userinfo.email") 

let oauthgoogle = GoogleService(
  authenticationEndpoint: authenticationEndpoint,
  tokenEndpoint: tokenEndpoint,
  clientID: clientID,
  clientSecret: clientSecret,
  redirectURI: redirectURI,
  scope: scope)
```


example Route:
```swift
try await app.oauth.google.make<EmailAccessToken>(service: oauthgoogle)
```


### See more:
- https://github.com/bwdmr/oauth-kit

