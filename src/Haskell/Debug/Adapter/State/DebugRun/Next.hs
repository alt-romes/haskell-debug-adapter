{-# LANGUAGE MultiParamTypeClasses #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Haskell.Debug.Adapter.State.DebugRun.Next where

import Control.Monad.IO.Class
import qualified System.Log.Logger as L
import qualified Text.Read as R
import qualified Data.List as L
import Control.Monad.Except

import qualified GHCi.DAP as DAP
import Haskell.Debug.Adapter.Type
import Haskell.Debug.Adapter.Constant
import qualified Haskell.Debug.Adapter.Utility as U
import qualified Haskell.Debug.Adapter.GHCi as P

-- |
--
instance StateRequestIF DebugRunState DAP.NextRequest where
  action (DebugRun_Next req) = do
    liftIO $ L.debugM _LOG_APP $ "DebugRunState NextRequest called. " ++ show req
    app req

-- |
--
app :: DAP.NextRequest -> AppContext (Maybe StateTransit)
app req = flip catchError errHdl $ do
  
  let args = DAP.argumentsNextRequest req
      cmd = ":dap-next " ++ U.showDAP args

  P.cmdAndOut cmd
  P.expectH $ P.funcCallBk lineCallBk

  resSeq <- U.getIncreasedResponseSequence
  let res = DAP.defaultNextResponse {
            DAP.seqNextResponse = resSeq
          , DAP.request_seqNextResponse = DAP.seqNextRequest req
          , DAP.successNextResponse = True
          }

  U.addResponse $ NextResponse res

  return Nothing
  
  where
    lineCallBk :: Bool -> String -> AppContext ()
    lineCallBk True  s = U.sendStdoutEvent s
    lineCallBk False s
      | L.isPrefixOf _DAP_HEADER s = dapHdl $ drop (length _DAP_HEADER) s
      | otherwise = U.sendStdoutEventLF s

    -- |
    --
    dapHdl :: String -> AppContext ()
    dapHdl str = case R.readEither str of
      Left err -> throwError $ err ++ " : " ++ str
      Right (Left err) -> throwError $ err ++ " : " ++ str
      Right (Right body) -> U.handleStoppedEventBody body
        

    -- |
    --
    errHdl :: String -> AppContext (Maybe StateTransit)
    errHdl msg = do
      liftIO $ L.errorM _LOG_APP msg
      resSeq <- U.getIncreasedResponseSequence
      let res = DAP.defaultNextResponse {
                DAP.seqNextResponse = resSeq
              , DAP.request_seqNextResponse = DAP.seqNextRequest req
              , DAP.successNextResponse = False
              , DAP.messageNextResponse = msg
              }

      U.addResponse $ NextResponse res
      return Nothing

