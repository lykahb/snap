{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
module Main where

import Data.Lens.Template
import qualified Data.Text as T
import Snap.Core
import Snap.Http.Server.Config
import Snap.Util.FileServe

import Snap.Snaplet
import Snap.Snaplet.Heist
import Snap.Snaplet.Session
import Snap.Snaplet.Session.Backends.CookieSession
import Text.Templating.Heist

data App = App
    { _heist :: Snaplet (Heist App)
    , _session :: Snaplet SessionManager
    }

type AppHandler = Handler App App

makeLens ''App

instance HasHeist App where
    heistLens = subSnaplet heist

helloHandler :: AppHandler ()
helloHandler = writeText "Hello world"

sessionTest :: AppHandler ()
sessionTest = withSession session $ do
  with session $ do
    curVal <- getFromSession "foo"
    case curVal of
      Nothing -> do
        setInSession "foo" "bar"
      Just _ -> return ()
  list <- with session $ (T.pack . show) `fmap` sessionToList
  csrf <- with session $ (T.pack . show) `fmap` csrfToken
  renderWithSplices "session"
    [ ("session", liftHeist $ textSplice list)
    , ("csrf", liftHeist $ textSplice csrf) ]

------------------------------------------------------------------------------
-- |
app :: SnapletInit App App
app = makeSnaplet "app" "An snaplet example application." Nothing $ do
    h <- nestSnaplet "heist" heist $ heistInit "resources/templates"
    with heist $ addSplices
        [("mysplice", liftHeist $ textSplice "YAY, it worked")]
    s <- nestSnaplet "session" session $
      initCookieSessionManager "config/site_key.txt" "_session" Nothing
    addRoutes [ ("/hello", helloHandler)
              , ("/aoeu", with heist $ heistServeSingle "foo")
              , ("/sessionTest", sessionTest)
              , ("", with heist heistServe)
              , ("", with heist $ serveDirectory "resources/doc")
              ]
    return $ App h s

main :: IO ()
main = serveSnaplet defaultConfig app

