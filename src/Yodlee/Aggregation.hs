-- | This module provides functions that interfaces with the Yodlee Aggregation
-- REST API. This is a thin wrapper around the API.
module Yodlee.Aggregation
       (
         -- * The 'Default' class
         Default(..)
         -- * Data types
       , Yodlee
       , runYodlee
       , Error(..)
       , ErrorAt(..)
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
       , siteCredItemDisplayName
       , siteCredItemTypeName
       , siteCredItemName
       , siteCredItemSize
       , siteCredItemIsOptional
         -- ** JSON 'Value's from the API
         -- $value
       , CobrandSession
       , _CobrandSession
       , UserSession
       , _UserSession
       , Site
       , _Site
       , siteLoginForm
       , SiteAccount
       , _SiteAccount
       , MFARefresh
       , _MFARefresh
         -- * Endpoints
         -- $endpoints
       , coblogin
       , register3
       , login
       , searchSite
       , getSiteLoginForm
       , addSiteAccount1
       , getMFAResponseForSite
         -- * Helper functions
       , fillInSiteCredentialComponents
  ) where

import           Data.Default
import           Yodlee.Endpoints
import           Yodlee.Types
