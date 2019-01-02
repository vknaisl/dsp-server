module Api.Handler.IO.IOHandler where

import Data.Aeson (encode)
import qualified Data.List as L
import Data.Text.Lazy
import Network.Wai.Parse
import Web.Scotty.Trans (addHeader, files, json, param, raw)

import Api.Handler.Common
import Service.IO.IOService
import Service.Package.PackageService

exportA :: Endpoint
exportA = do
  pkgId <- param "pkgId"
  eitherDto <- runInUnauthService $ getPackageWithEventsById pkgId
  case eitherDto of
    Right dto -> do
      let cdHeader = "attachment;filename=" ++ pkgId ++ ".kmp"
      addHeader "Content-Disposition" (pack cdHeader)
      addHeader "Content-Type" (pack "application/octet-stream")
      raw $ encode dto
    Left error -> sendError error

importA :: Endpoint
importA =
  getAuthServiceExecutor $ \runInAuthService -> do
    fs <- files
    case L.find (\(fieldName, file) -> fieldName == "file") fs of
      Just (fieldName, file) -> do
        let fName = fileName file
        let fContent = fileContent file
        eitherDto <- runInAuthService $ importPackageInFile fContent
        case eitherDto of
          Right dto -> json dto
          Left error -> sendError error
      Nothing -> notFoundA
