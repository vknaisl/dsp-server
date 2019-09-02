module Service.KnowledgeModel.Compilator.EventApplicator.Question where

import Control.Lens
import qualified Data.Map as M
import Prelude hiding (lookup)

import LensesConfig
import Model.Event.EventAccessors
import Model.Event.Question.QuestionEvent
import Model.KnowledgeModel.KnowledgeModel
import Model.KnowledgeModel.KnowledgeModelLenses
import Service.KnowledgeModel.Compilator.EventApplicator.EventApplicator
import Service.KnowledgeModel.Compilator.Modifier.Answer ()
import Service.KnowledgeModel.Compilator.Modifier.Chapter ()
import Service.KnowledgeModel.Compilator.Modifier.Delete
import Service.KnowledgeModel.Compilator.Modifier.Expert ()
import Service.KnowledgeModel.Compilator.Modifier.Integration ()
import Service.KnowledgeModel.Compilator.Modifier.KnowledgeModel ()
import Service.KnowledgeModel.Compilator.Modifier.Modifier
import Service.KnowledgeModel.Compilator.Modifier.Reference ()
import Service.KnowledgeModel.Compilator.Modifier.Tag ()
import Util.Lens

instance ApplyEvent AddQuestionEvent where
  apply event km = Right . addEntity . addEntityReference $ km
    where
      addEntityReference :: KnowledgeModel -> KnowledgeModel
      addEntityReference km =
        case M.lookup (getEventParentUuid event) (km ^. chaptersM) of
          Just parent ->
            km & (chaptersM . at (getEventParentUuid event)) ?~ (parent & ap questionUuids .~ (getEventNodeUuid event))
          Nothing ->
            case M.lookup (getEventParentUuid event) (km ^. questionsM) of
              Just parent ->
                km & (questionsM . at (getEventParentUuid event)) ?~
                (parent & ap itemTemplateQuestionUuids' .~ (getEventNodeUuid event))
              Nothing ->
                case M.lookup (getEventParentUuid event) (km ^. answersM) of
                  Just parent ->
                    km & (answersM . at (getEventParentUuid event)) ?~
                    (parent & ap followUpUuids .~ (getEventNodeUuid event))
                  Nothing -> km
      addEntity :: KnowledgeModel -> KnowledgeModel
      addEntity km = km & (questionsM . at (getEventNodeUuid event)) ?~ (createEntity event)

instance ApplyEvent EditQuestionEvent where
  apply = applyEditEvent (entities . questions) "Question"

instance ApplyEvent DeleteQuestionEvent where
  apply event km = Right . deleteEntity . deleteEntityReference $ km
    where
      deleteEntityReference :: KnowledgeModel -> KnowledgeModel
      deleteEntityReference km =
        case M.lookup (getEventParentUuid event) (km ^. chaptersM) of
          Just parent ->
            km & (chaptersM . at (getEventParentUuid event)) ?~ (parent & del questionUuids .~ (getEventNodeUuid event))
          Nothing ->
            case M.lookup (getEventParentUuid event) (km ^. questionsM) of
              Just parent ->
                km & (questionsM . at (getEventParentUuid event)) ?~
                (parent & del itemTemplateQuestionUuids' .~ (getEventNodeUuid event))
              Nothing ->
                case M.lookup (getEventParentUuid event) (km ^. answersM) of
                  Just parent ->
                    km & (answersM . at (getEventParentUuid event)) ?~
                    (parent & del followUpUuids .~ (getEventNodeUuid event))
                  Nothing -> km
      deleteEntity :: KnowledgeModel -> KnowledgeModel
      deleteEntity km = deleteQuestion km (getEventNodeUuid event)
