{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

-- | This module provides functions that interfaces with the Yodlee Aggregation
-- REST API. This is a thin wrapper around the API.
module Yodlee.Aggregation
       (
         -- * The 'Default' class
         Default(..)
         -- * Data types
       , Yodlee
       , runYodlee
         -- ** API Input types
         -- $apiin
       , CobrandCredential
       , cobrandUsername
       , cobrandPassword
       , UserCredential
       , userUsername
       , userPassword
       , UserRegistrationData
       , userCredential
       , userEmail
       , userFirstName
       , userLastName
       , userMiddleInitial
       , userAddress1
       , userAddress2
       , userCity
       , userCountry
       , SiteCredentialComponent
       , siteCredItemFormat
       , siteCredItemValue
         -- ** JSON 'Value's from the API
         -- $value
       , CobrandSession
       , _CobrandSession
       , UserSession
       , _UserSession
       , Site
       , _Site
       , siteLoginForm
       , SiteId
       , siteId
       , SiteAccount
       , _SiteAccount
         -- * Endpoints
         -- $endpoints
       , coblogin
       , register3
       , login
       , searchSite
       , getSiteLoginForm
       , addSiteAccount1
  ) where

import           Control.Error
import           Control.Lens.Combinators
import           Control.Monad
import           Control.Monad.IO.Class
import           Control.Monad.Reader
import           Data.Aeson
import           Data.Aeson.Lens
import qualified Data.ByteString.Char8    as C
import           Data.Default
import           Data.Maybe
import           Data.Monoid
import qualified Data.Text                as T
import qualified Data.Vector              as V
import           Network.Wreq             as HTTP
import           Network.Wreq.Session     as HTTPSess
import           Network.Wreq.Types

-- $apiin
-- The API input data types store inputs to the APIs. This includes, for
-- example, the 'CobrandCredential' and 'UserCredential' types, which are data
-- structures that store the relevant credentials (username and password). The
-- data constructors for all those types are purposefully not exported. You are
-- expected to construct those objects by using 'def'. You can then set the
-- fields using the provided lenses, like this:
--
-- @
-- 'set' 'cobrandUsername' "username" . 'set' 'cobrandPassword' "password" $ 'def'
-- @
--

-- | 'CobrandCredential' is a data structure that stores the credentials for a
-- Yodlee cobrand login.
--
-- According to Yodlee, the cobrand login is a process by which a developer
-- authenticates their application with the Yodlee API before registering its
-- user and performing other actions like adding accounts, getting transactions,
-- etc., on behalf of its user.
$(declareLenses [d|
  data CobrandCredential = CobrandCredential
    { cobrandUsername :: T.Text
    , cobrandPassword :: T.Text
    } deriving (Show)
  |])

-- | The default value for 'CobrandCredential' is such that both the username
-- and password are 'T.empty'.
instance Default CobrandCredential where
  def = CobrandCredential T.empty T.empty

-- | 'UserCredential' is a data structure that stores user credentials.
$(declareLenses [d|
  data UserCredential = UserCredential
    { userUsername :: T.Text
    , userPassword :: T.Text
    } deriving (Show)
  |])

-- | The default value for 'UserCredential' is such that both the username and
-- password are 'T.empty'.
instance Default UserCredential where
  def = UserCredential T.empty T.empty

-- | 'UserRegistrationData' is a data structure that contains credentials and
-- the user profile, such as email, name, address, city, etc. Currently, not all
-- are supported.
$(declareLenses [d|
  data UserRegistrationData = UserRegistrationData
    { userCredential    :: UserCredential
    , userEmail         :: T.Text
    , userFirstName     :: Maybe T.Text
    , userLastName      :: Maybe T.Text
    , userMiddleInitial :: Maybe T.Text
    , userAddress1      :: Maybe T.Text
    , userAddress2      :: Maybe T.Text
    , userCity          :: Maybe T.Text
    , userCountry       :: Maybe T.Text
    } deriving (Show)
  |])

instance Default UserRegistrationData where
  def = UserRegistrationData def T.empty Nothing Nothing Nothing Nothing Nothing Nothing Nothing

-- | 'SiteCredentialComponent' is a data structure that contains the expected
-- format as well as the provided value of a piece of site credential. In Yodlee
-- terms, site account is the association of a consumer with accounts available
-- in the site, and therefore a site login uses credential types that are unique
-- to each site. For this reason, a 'Getter' called 'siteCredItemFormat' is
-- provided to get the expected format of this piece of credential. The
-- credential may then be added by using the 'Lens'' called 'siteCredItemValue'.
$(declareLenses [d|
  data SiteCredentialComponent = SiteCredentialComponent
    { siteCredItemValue :: T.Text
    , siteCredItemIndex :: Int -- not exported
    , siteCredItemFormatInternal :: Value
    } deriving (Show)
  |])

-- | This is the 'Getter' that allows you to extract the JSON 'Value' inside
-- 'SiteCredentialComponent'. This is slightly unusual because it's a 'Getter',
-- not a 'Lens'' to prevent modifications.
siteCredItemFormat :: Getter SiteCredentialComponent Value
siteCredItemFormat = siteCredItemFormatInternal

-- $value
-- This section contains data structures such as 'CobrandSession',
-- 'UserSession', and 'Site', which are returned by the Yodlee API. They are
-- implemented by wrapping a newtype around the raw @Value@. The reason is
-- because Yodlee does not seem to document very well exactly which fields are
-- present. To avoid the risk of the Haskell version getting out-of-date with
-- the upstream structure, we will trade some type safety here.
--
-- You can access the underlying 'Value' using the corresponding 'Getter'. You
-- can extract the 'Value', but you normally cannot modify those data structures
-- without extracting the 'Value' or construct them (unless you use
-- @unsafeCoerce@ in which case you should know what you are doing).

-- | 'CobrandSession' is the JSON data structure returned by the Yodlee API
-- after a successful cobrand login.
newtype CobrandSession = CobrandSession Value deriving (Show)

-- | This is the 'Getter' that allows you to extract the JSON 'Value' inside
-- a 'CobrandSession'.
_CobrandSession :: Getter CobrandSession Value
_CobrandSession = to (\(CobrandSession a) -> a)

-- | 'UserSession' is the JSON data structure returned by the Yodlee API after a
-- successful user login.
newtype UserSession = UserSession Value deriving (Show)

-- | This is the 'Getter' that allows you to extract the JSON 'Value' inside
-- a 'UserSession'.
_UserSession :: Getter UserSession Value
_UserSession = to (\(UserSession a) -> a)

-- | 'UserSession' is the JSON data structure returned by the Yodlee API after a
-- successful site search.
newtype Site = Site Value deriving (Show)

-- | This is the 'Getter' that allows you to extract the JSON 'Value' inside
-- 'Site'.
_Site :: Getter Site Value
_Site = to (\(Site a) -> a)

-- | 'SiteId' is a newtype wrapper for the site ID. You can get a 'SiteId' by
-- using the 'siteId' 'Getter'.
newtype SiteId = SiteId Integer deriving (Show)

-- | This is the 'Getter' that allows you to get a 'SiteId' from a 'Site'.
siteId :: Getter Site SiteId
siteId = to (fromJust <$> preview (_Site . key "siteId" . _Integer . to SiteId))

-- | 'SiteAccount' is the JSON data structure returned by the Yodlee API after
-- associating a customer with a site.
newtype SiteAccount = SiteAccount Value deriving (Show)

-- | This is the 'Getter' that allows you to extract the JSON 'Value' inside
-- a 'SiteAccount'.
_SiteAccount :: Getter SiteAccount Value
_SiteAccount = to (\(SiteAccount a) -> a)

urlBase :: String
urlBase = "https://rest.developer.yodlee.com/services/srest/restserver/v1.0"

cobrandSessionToken :: Traversal' Value T.Text
cobrandSessionToken = key "cobrandConversationCredentials" . key "sessionToken" . _String

userSessionToken :: Traversal' Value T.Text
userSessionToken = key "userContext" . key "conversationCredentials" . key "sessionToken" . _String

-- | The 'Yodlee' monad is a type returned by all endpoint functions. This /may/
-- become a @newtype@ in the future. The error type may also be more
-- descriptive, i.e. not just a 'Nothing' in case of error.
type Yodlee a = MaybeT (ReaderT HTTPSess.Session IO) a

-- | The 'runYodlee' function takes an action described by the 'Yodlee'
-- monad and executes it.
runYodlee :: Yodlee a -> IO (Maybe a)
runYodlee = HTTPSess.withSession . runReaderT . runMaybeT

-- $endpoint
-- Those functions correspond to the identically named Yodlee Aggregation REST
-- APIs. Some functions have a number following them. I don't know why.

performAPIRequest :: (Postable a) => String -> a -> Yodlee (Response Value)
performAPIRequest urlPart postable = do
  session <- lift ask
  let url = urlBase <> urlPart
  bs <- liftIO $ HTTPSess.post session url postable
  hoistMaybe $ asValue bs

-- | This authenticates the cobrand. Once the cobrand is authenticated a
-- 'CobrandSession' is created and the token within the 'CobrandSession' expires
-- every 100 minutes. Exceptions will be thrown on network errors, but 'Nothing'
-- will be returned if the server did not send a valid JSON response, or the
-- JSON response does not contain the expected fields.
coblogin :: CobrandCredential -> Yodlee CobrandSession
coblogin credential = do
  r <- performAPIRequest "/authenticate/coblogin"
    [ "cobrandLogin" := view cobrandUsername credential
    , "cobrandPassword" := view cobrandPassword credential
    ]
  guard $ has (responseBody . cobrandSessionToken) r
  hoistMaybe $ preview (responseBody . _Value . to CobrandSession) r

-- | This accepts a consumer's details to register the consumer in the Yodlee
-- system. After registration, the user is automatically logged in.
register3 :: CobrandSession -> UserRegistrationData -> Yodlee UserSession
register3 cbSess userReg = do
  let regParamsReq =
        [ "cobSessionToken" := view (_CobrandSession . cobrandSessionToken) cbSess
        , "userCredentials.loginName" := view (userCredential . userUsername) userReg
        , "userCredentials.password" := view (userCredential . userPassword) userReg
        , "userCredentials.objectInstanceType" := ("com.yodlee.ext.login.PasswordCredentials" :: T.Text)
        , "userProfile.emailAddress" := view userEmail userReg
        ]
  let optParamMap = [ ("userProfile.firstName", userFirstName)
                          , ("userProfile.lastName", userLastName)
                          , ("userProfile.middleInitial", userMiddleInitial)
                          , ("userProfile.address1", userAddress1)
                          , ("userProfile.address2", userAddress2)
                          , ("userProfile.city", userCity)
                          , ("userProfile.country", userCountry)
                          ]
  let regParamsOpt = catMaybes ((\(fieldName, fieldLens) -> (fieldName :=) <$> preview fieldLens userReg) <$> optParamMap)
  r <- performAPIRequest "/jsonsdk/UserRegistration/register3" (regParamsOpt <> regParamsReq)
  checkUserSession r

-- | This enables the consumer to log in to the application. Once the consumer
-- logs in, a 'UserSession' is created. It contains a token that will be used in
-- subsequently API calls. The token expires every 30 minutes.
login :: CobrandSession -> UserCredential -> Yodlee UserSession
login cbSess userCred = do
  r <- performAPIRequest "/authenticate/login"
    [ "cobSessionToken" := view (_CobrandSession . cobrandSessionToken) cbSess
    , "login" := view userUsername userCred
    , "password" := view userPassword userCred
    ]
  checkUserSession r

checkUserSession :: Response Value -> Yodlee UserSession
checkUserSession r = do
  guard $ has (responseBody . userSessionToken) r
  hoistMaybe $ preview (responseBody . _Value . to UserSession) r

-- | This searches for sites. If the search string is found in the display name
-- parameter or aka parameter or keywords parameter of any 'Site' object, that
-- site will be included in this list of matching sites.
searchSite :: CobrandSession -> UserSession -> T.Text -> Yodlee [Site]
searchSite cbSess user site = do
  r <- performAPIRequest "/jsonsdk/SiteTraversal/searchSite"
    [ "cobSessionToken" := view (_CobrandSession . cobrandSessionToken) cbSess
    , "userSessionToken" := view (_UserSession . userSessionToken) user
    , "siteSearchString" := site
    ]
  -- This guard checks it contains a siteId. Do not remove it! The correctness of @siteId@ depends on it.
  guard $ allOf (responseBody . _Array . traverse) (has (key "siteId" . _Integer)) r
  return $ toListOf (responseBody . _Array . traverse . to Site) r

-- | This is a 'Fold' that allows you to directly obtain a list of
-- 'SiteCredentialComponent' using 'toListOf'. Alternatively, you can also use
-- 'getSiteLoginForm' to achieve the same thing with an HTTP call in 'IO'. (But
-- why?)
siteLoginForm :: Fold Site SiteCredentialComponent
siteLoginForm = _Site . key "loginForms" . _Array . to V.indexed . traverse . to (uncurry (SiteCredentialComponent T.empty))

-- | This provides the login form associated with the requested site, given a
-- 'SiteId'. It is unknown why this needs to exist because 'searchSite' already
-- returns this information, but it's included as per recommendation from
-- Yodlee. The login form comprises of the credential fields that are required
-- for adding a member to that site. This call lets the consumers enter their
-- credentials into the login form for the site they are trying to add.
getSiteLoginForm :: CobrandSession -> SiteId -> Yodlee [SiteCredentialComponent]
getSiteLoginForm cbSess (SiteId i) = do
  r <- performAPIRequest "/jsonsdk/SiteAccountManagement/getSiteLoginForm"
    [ "cobSessionToken" := view (_CobrandSession . cobrandSessionToken) cbSess
    , "siteId" := show i
    ]
  -- Check that the conjunctionOp is 1, which is AND, i.e. the form fields form a product type. We don't want to deal with sum types.
  -- By the way, the second key "conjuctionOp" is misspelled.
  guard . (== Just 1) $ preview (responseBody . _Value . key "conjunctionOp" . key "conjuctionOp" . _Integer) r
  guard $ allOf (responseBody . key "componentList" . _Array . traverse) (\obj -> allOf (traverse . traverse) (`has'` obj) siteCredentialExpectedFields) r
  return $ toListOf (responseBody . key "componentList" . _Array . to V.indexed . traverse . to (uncurry (SiteCredentialComponent T.empty))) r
  where has' l = isJust . preview l

siteCredentialExpectedFields :: [(C.ByteString, Getting (First T.Text) Value T.Text)]
siteCredentialExpectedFields =
  [ ("displayName", key "displayName" . _String)
  , ("fieldType.typeName", key "fieldType" . key "typeName" . _String)
  , ("name", key "name" . _String)
  , ("size", key "size" . _Integer . to show . to T.pack)
  , ("valueIdentifier", key "valueIdentifier" . _String)
  , ("valueMask", key "valueMask" . _String)
  , ("isEditable", key "isEditable" . _Bool . to show . to T.pack . to T.toLower)
  ]

siteCredentialRequiredFields :: [(C.ByteString, Getting (First T.Text) SiteCredentialComponent T.Text)]
siteCredentialRequiredFields = [("value", siteCredItemValue)] <> over (traverse . traverse) (siteCredItemFormat .) siteCredentialExpectedFields

-- | This adds a member site account associated with a particular site.
-- refresh is initiated for the item. This API is expected to be called after
-- getting a login form for a particular site using 'getSiteLoginForm' or
-- @getSiteInfo@ or 'searchSite'.
addSiteAccount1 :: CobrandSession -> UserSession -> SiteId -> [SiteCredentialComponent] -> Yodlee SiteAccount
addSiteAccount1 cbSess user (SiteId i) siteCreds = do
  let transformCredPiece cred name traversal = (("credentialFields[" <> view (siteCredItemIndex . to show . to C.pack) cred <> "]." <> name) :=) <$> preview traversal cred
  let transformCred cred = uncurry (transformCredPiece cred) <$> siteCredentialRequiredFields
  let transformed = concatMap transformCred siteCreds
  credRequestParams <- hoistMaybe . sequence $ transformed
  let requestParams = [ "cobSessionToken" := view (_CobrandSession . cobrandSessionToken) cbSess
                      , "userSessionToken" := view (_UserSession . userSessionToken) user
                      , "siteId" := show i
                      , "credentialFields.enclosedType" := ("com.yodlee.common.FieldInfoSingle" :: T.Text) -- XXX
                      ] <> credRequestParams
  r <- performAPIRequest "/jsonsdk/SiteAccountManagement/addSiteAccount1" requestParams
  hoistMaybe $ preview (responseBody . _Value . to SiteAccount) r
