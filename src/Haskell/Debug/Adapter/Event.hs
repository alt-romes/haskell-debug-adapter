module Haskell.Debug.Adapter.Event where

import Control.Monad.IO.Class
import Control.Concurrent.Async
import Control.Concurrent
import qualified System.Log.Logger as L
import Control.Monad.State.Lazy
import Control.Lens

import Haskell.Debug.Adapter.Type
import Haskell.Debug.Adapter.Utility
import Haskell.Debug.Adapter.Constant


-- |
--
addEvent :: AppStores -> Event -> IO ()
addEvent dat evt = do
  let mvar = dat^.evtStoreAppStores
  evts <- takeMVar mvar
  putMVar mvar (evts++[evt])


-- |
--
run :: AppStores -> IO ()
run appData = runApp appData app >>= \case
    Left err -> do
      L.errorM _LOG_NAME err
      return ()
    Right (res, _) -> do
      L.infoM _LOG_NAME $ show res
      return ()


-- |
--
app :: AppContext ()
app = do
  go
  return ()
  where
    go = do
      takeEvent >>= \case
        Nothing -> return ()
        Just ev -> runEvent ev

      liftIO $ threadDelay _10_MILLI_SEC
      go


-- |
--
takeEvent :: AppContext (Maybe Event)
takeEvent = do
  appDat <- get
  let mvar = appDat^.evtStoreAppStores
  liftIO $ goIO mvar


  where
    goIO mvar = isExists mvar >>= \case
      False -> return Nothing
      True  -> take1 mvar

    isExists mvar = readMVar mvar >>= \case
      [] -> return False
      _  -> return True

    take1 mvar = takeMVar mvar >>= \case
      [] -> do
        putMVar mvar []
        return Nothing
      (x:xs) -> do
        putMVar mvar xs
        return $ Just x


-- |
--
runEvent :: Event -> AppContext ()
runEvent StopEvent = do
  as <- view actsAsyncsAppStores <$> get
  liftIO $ mapM_ cancel as

