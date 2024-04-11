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
let accessToken = EmailAccessToken(emailendpointURL)

let authenticationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
let tokenEndpoint = "https://oauth2.googleapis.com/token"
let clientID = "CLIENT_ID"
let clientSecret = "CLIENT_SECRET"
let redirectURI = "REDIRECT_URI"
let state = "STATE"
let oauthgoogle = GoogleService(
  authenticationEndpoint: authenticationEndpoint,
  tokenEndpoint: tokenEndpoint,
  clientID: clientID,
  clientSecret: clientSecret,
  redirectURI: redirectURI,
  state: state)

try await app.oauth.google.use(service, accessToken, head: "https://www.googleapis.com/auth/userinfo.email")
```


### See more:
- https://github.com/bwdmr/oauth-kit

