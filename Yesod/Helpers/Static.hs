{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
---------------------------------------------------------
--
-- Module        : Yesod.Helpers.Static
-- Copyright     : Michael Snoyman
-- License       : BSD3
--
-- Maintainer    : Michael Snoyman <michael@snoyman.com>
-- Stability     : Unstable
-- Portability   : portable
--
-- Serve static files from a Yesod app.
--
-- This is most useful for standalone testing. When running on a production
-- server (like Apache), just let the server do the static serving.
--
---------------------------------------------------------
module Yesod.Helpers.Static
    ( serveStatic
    , FileLookup
    , fileLookupDir
    ) where

import System.Directory (doesFileExist)
import Control.Monad

import Yesod
import Data.List (intercalate)

type FileLookup = FilePath -> IO (Maybe (Either FilePath Content))

-- | A 'FileLookup' for files in a directory. Note that this function does not
-- check if the requested path does unsafe things, eg expose hidden files. You
-- should provide this checking elsewhere.
--
-- If you are just using this in combination with serveStatic, serveStatic
-- provides this checking.
fileLookupDir :: FilePath -> FileLookup
fileLookupDir dir fp = do
    let fp' = dir ++ '/' : fp
    exists <- doesFileExist fp'
    if exists
        then return $ Just $ Left fp'
        else return Nothing

serveStatic :: FileLookup -> Verb -> [String]
            -> Handler y [(ContentType, Content)]
serveStatic fl Get fp = getStatic fl fp
serveStatic _ _ _ = notFound

getStatic :: FileLookup -> [String] -> Handler y [(ContentType, Content)]
getStatic fl fp' = do
    when (any isUnsafe fp') notFound
    let fp = intercalate "/" fp'
    content <- liftIO $ fl fp
    case content of
        Nothing -> notFound
        Just (Left fp'') -> sendFile (typeByExt $ ext fp'') fp''
        Just (Right bs) -> return [(typeByExt $ ext fp, cs bs)]
      where
        isUnsafe [] = True
        isUnsafe ('.':_) = True
        isUnsafe _ = False