module Api.Handler.Common where

import Control.Lens ((^.))
import Control.Monad.Logger
import Control.Monad.Trans.Class (lift)
import Data.Aeson ((.=), eitherDecode, encode, object)
import Data.Maybe
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import Network.HTTP.Types (hContentType, notFound404)
import Network.HTTP.Types.Method (methodOptions)
import Network.HTTP.Types.Status
       (badRequest400, forbidden403, internalServerError500, ok200,
        unauthorized401)
import Network.Wai
import Web.Scotty.Trans
       (ActionT, body, header, json, params, request, status)

import Api.Resource.Error.ErrorDTO ()
import Common.Error
import LensesConfig
import Model.Context.AppContext
import Service.Token.TokenService
import Service.User.UserService

type Endpoint = ActionT LT.Text AppContextM ()

getReqDto callback = do
  reqBody <- body
  let eitherReqDto = eitherDecode reqBody
  case eitherReqDto of
    Right reqDto -> callback reqDto
    Left error -> sendError $ createErrorWithErrorMessage error

getCurrentUserUuid callback = do
  tokenHeader <- header "Authorization"
  let userUuidMaybe = getUserUuidFromToken (tokenHeader >>= \token -> Just . LT.toStrict $ token) :: Maybe T.Text
  case userUuidMaybe of
    Just userUuid -> callback (T.unpack userUuid)
    Nothing -> unauthorizedA

getCurrentUser callback =
  getCurrentUserUuid $ \userUuid -> do
    eitherUser <- lift $ getUserById userUuid
    case eitherUser of
      Right user -> callback user
      Left error -> sendError error

getQueryParam paramName = do
  reqParams <- params
  let mValue = lookup paramName reqParams
  case mValue of
    Just value -> return . Just . LT.toStrict $ value
    Nothing -> return Nothing

getListOfQueryParamsIfPresent :: [LT.Text] -> ActionT LT.Text AppContextM [(T.Text, T.Text)]
getListOfQueryParamsIfPresent = Prelude.foldr go (return [])
  where
    go name monadAcc = do
      value <- extractQueryParam name
      acc <- monadAcc
      return $ maybeToList value ++ acc
    extractQueryParam name = do
      mValue <- getQueryParam name
      case mValue of
        Just value -> return $ Just (LT.toStrict name, value)
        Nothing -> return Nothing

checkPermission perm callback = do
  tokenHeader <- header "Authorization"
  let mUserPerms = getPermissionsFromToken (tokenHeader >>= \token -> Just . LT.toStrict $ token)
  case mUserPerms of
    Just userPerms ->
      if perm `Prelude.elem` userPerms
        then callback
        else forbidden
    Nothing -> forbidden

isLogged callback = do
  tokenHeader <- header "Authorization"
  callback . isJust $ tokenHeader

isAdmin callback =
  isLogged $ \userIsLogged ->
    if userIsLogged
      then getCurrentUser $ \user -> callback $ user ^. role == "ADMIN"
      else callback False

sendError :: AppError -> Endpoint
sendError (ValidationError errorMessage formErrors fieldErrors) = do
  status badRequest400
  json $ ValidationError errorMessage formErrors fieldErrors
sendError (NotExistsError errorMessage) = do
  status notFound404
  json $ NotExistsError errorMessage
sendError (DatabaseError errorMessage) = do
  status internalServerError500
  json $ DatabaseError errorMessage
sendError (MigratorError errorMessage) = do
  status badRequest400
  json $ MigratorError errorMessage

unauthorizedA :: Endpoint
unauthorizedA = do
  status unauthorized401
  json $ object ["status" .= 401, "error" .= "Unauthorized"]

unauthorizedL :: Response
unauthorizedL =
  responseLBS unauthorized401 [(hContentType, "application/json; charset=utf-8")] $
  encode (object ["status" .= 401, "error" .= "Unauthorized"])

forbidden :: Endpoint
forbidden = do
  status forbidden403
  json $ object ["status" .= 403, "error" .= "Forbidden"]

notFoundA :: Endpoint
notFoundA = do
  request <- request
  if requestMethod request == methodOptions
    then status ok200
    else do
      lift $ $(logInfo) "Request does not match any route"
      status notFound404
      json $ object ["status" .= 404, "error" .= "Not Found"]
