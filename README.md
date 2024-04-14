<h2 align="center">OAuth</h2>



### About
A layer between [oauth-kit](https://github.com/bwdmr/oauth-kit) and [vapor](https://github.com/vapor/vapor).



### Usage
1. Define your custom fields, additionally to the access token ones: 
  - in this example it is: `email`, 
  - exemplatory scope is: `https://www.googleapis.com/auth/userinfo.email`,
  - and the dedicated endpoint would be: `https://www.googleapis.com/oauth2/v3/userinfo`


```swift
struct EmailAccessToken: OAuthGoogleToken {
  var endpoint: URL
  
  var accessToken: AccessTokenClaim?
  
  var email: EmailClaim?
  
  var expiresIn: ExpiresInClaim?
  
  var refreshToken: RefreshTokenClaim?
  
  var scope: ScopeClaim
  
  var tokenType: TokenTypeClaim?
}
```


2. Instantiate your service, passing your custom AccessToken along.
```swift
let emailendpointURL = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")

let authenticationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
let tokenEndpoint = "https://oauth2.googleapis.com/token"
let clientID = "CLIENT_ID"
let clientSecret = "CLIENT_SECRET"
let redirectURI = "REDIRECT_URI"
let scopeClaim = ScopeClaim(stringLiteral: "https://www.googleapis.com/auth/userinfo.email")
let scope = "https://www.googleapis.com/auth/userinfo.email"

let accessToken = EmailAccessToken(endpoint: emailendpointURL, scope: scopeClaim)

let oauthgoogle = GoogleService(
  authenticationEndpoint: authenticationEndpoint,
  tokenEndpoint: tokenEndpoint,
  clientID: clientID,
  clientSecret: clientSecret,
  redirectURI: redirectURI,
  scope: scope)

try await app.oauth.google.make(service: oauthgoogle, token: [accessToken], head: scope)
```


### See more:
- https://github.com/bwdmr/oauth-kit

