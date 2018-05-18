module Database.DAO.Migrator.MigratorDAO where

import Control.Lens ((^.))
import Data.Bson
import Data.Bson.Generic
import Database.MongoDB
       ((=:), delete, fetch, findOne, insert, merge, save, select)

import Common.Error
import Database.BSON.Migrator.MigratorState ()
import Database.DAO.Common
import Model.Context.AppContext
import Model.Migrator.MigratorState

msCollection = "migrations"

findMigratorStateByBranchUuid :: String -> AppContextM (Either AppError MigratorState)
findMigratorStateByBranchUuid branchUuid = do
  let action = findOne $ select ["branchUuid" =: branchUuid] msCollection
  maybeMigratorState <- runDB action
  return . deserializeMaybeEntity $ maybeMigratorState

insertMigratorState :: MigratorState -> AppContextM Value
insertMigratorState ms = do
  let action = insert msCollection (toBSON ms)
  runDB action

updateMigratorState :: MigratorState -> AppContextM ()
updateMigratorState ms = do
  let branchUuid = ms ^. msBranchUuid
  let action = fetch (select ["branchUuid" =: branchUuid] msCollection) >>= save msCollection . merge (toBSON ms)
  runDB action

deleteMigratorStates :: AppContextM ()
deleteMigratorStates = do
  let action = delete $ select [] msCollection
  runDB action

deleteMigratorStateByBranchUuid :: String -> AppContextM ()
deleteMigratorStateByBranchUuid branchUuid = do
  let action = delete $ select ["branchUuid" =: branchUuid] msCollection
  runDB action
