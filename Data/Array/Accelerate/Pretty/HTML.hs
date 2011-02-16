{-# LANGUAGE GADTs, OverloadedStrings, ScopedTypeVariables, NoMonomorphismRestriction #-}
-- |Embedded array processing language: pretty printing to HTML
--
--  Copyright (c) 2009 Manuel M T Chakravarty, Gabriele Keller, Sean Lee, Sean Seefried
--
--  License: BSD3
--
--- Description ---------------------------------------------------------------
--

module Data.Array.Accelerate.Pretty.HTML  (
   dumpHtmlAST
) where

-- standard libraries
import Data.String
import Data.Monoid
import qualified Data.Text as T
import Text.Blaze.Renderer.Utf8
import Text.Blaze.Html4.Transitional ((!))
import qualified Text.Blaze.Html4.Transitional as H
import qualified Text.Blaze.Html4.Transitional.Attributes as A

import System.IO
import System.IO.Error hiding (catch)
import qualified Data.ByteString.Lazy as BS

-- friends
import Data.Array.Accelerate.AST
import Data.Array.Accelerate.Pretty.Traverse

combineHtml :: String -> String -> [H.Html] -> H.Html
combineHtml cssClass label nodes = do
   let inner = foldl (>>) (return ()) nodes
   H.div ! A.class_ ("node " `mappend` fromString cssClass `mappend` " expanded") $ do
     H.span ! A.class_ "selector" $ H.text (fromString label)
     inner
leafHtml :: String -> String -> H.Html
leafHtml cssClass label =
  H.div ! A.class_ ("node " `mappend` fromString cssClass `mappend` " leaf") $
    H.span $ H.text (fromString label)

htmlLabels :: Labels
htmlLabels = Labels { accFormat = "array-node"
                    , expFormat = "exp-node"
                    , funFormat = "fun-node"
                    , primFunFormat = "prim-fun-node"
                    , tupleFormat = "tuple-node"
                    , arrayFormat = "array-node"
                    , boundaryFormat = "boundary-node" }


-- combine :: Monad m => String -> String -> [m a] -> m a
-- combine = undefined
--
-- leafNode :: Monad m => String -> String -> m a
-- leafNode = undefined

htmlAST :: OpenAcc aenv a -> H.Html
htmlAST acc = H.docTypeHtml $
    H.head $ do
        H.meta ! A.httpEquiv "Content-Type" ! A.content "text/html; charset=UTF-8"
        H.script ! A.type_ "text/javascript" !
                   A.src "https://ajax.googleapis.com/ajax/libs/jquery/1.4.4/jquery.min.js" $ mempty
        H.link ! A.rel "stylesheet" ! A.href "accelerate.css" ! A.type_ "text/css"
        H.script ! A.type_ "text/javascript" $ H.text $
          T.unlines ["function collapse() {"
                    ,"  var parent=$(this).parent();"
                    ,"  var that = $(this);"
                    ,"  parent.addClass(\"collapsed\").removeClass(\"expanded\");"
                    ,"  parent.children().each(function (i) {"
                    ,"    if ($(this).get(0) != that.get(0)) {"
                    ,"      $(this).hide(100);"
                    ,"    }"
                    ,"  });"
                    ,"  $(this).unbind();"
                    ,"  $(this).click(expand);"
                    ,"}"
                    , ""
                    , "function expand() {"
                    , "var parent=$(this).parent();"
                    , "parent.removeClass(\"collapsed\").addClass(\"expanded\");"
                    , "parent.children().show(100);"
                    , "$(this).show();"
                    , "$(this).unbind();"
                    , "$(this).click(collapse);"
                    , "}"
                    , "$(document).ready(function () {"
                    , "  $('.expanded>.selector').click(collapse);"
                    , "  $('.collapsed>.selector').click(expand);"
                    , "});"]
        H.body $ do
          H.table ! A.border "0" $
            H.tr $ do
              H.td ! A.class_ "acc-node" $ H.span "OpenAcc"
              H.td ! A.class_ "fun-node" $ H.span "OpenFun"
              H.td ! A.class_ "exp-node" $ H.span "OpenExp"
              H.td ! A.class_ "prim-fun-node" $ H.span "PrimFun"
              H.td ! A.class_ "tuple-node" $ H.span "Tuple"
              H.td ! A.class_ "boundary-node" $ H.span "Boundary"
          H.hr
          travAcc htmlLabels combineHtml leafHtml acc

accelerateCSS :: String
accelerateCSS =
  unlines
  [ "body {"
  , "  font-family: Helvetica;"
  , "  font-size: 10pt;"
  , "}"
  , ".node {"
  , "  padding-left: 5px;"
  , ""
  , "}"
  , ""
  , ".expanded .node {"
  , "  padding-left: 12px;"
  , "}"
  , ""
  , ".expanded .node.leaf {"
  , " padding-left: 23px;"
  , "}"
  , ""
  , ".acc-node>span      { color: red; }"
  , ".exp-node>span      { color: blue;}"
  , ".array-node>span    { color: purple;}"
  , ".fun-node>span      { color: orange;}"
  , ".prim-fun-node>span { color: magenta;}"
  , ".tuple-node>span    { color: green;}"
  , ".boundary-node>span { color: darkcyan;}                                            "
  , ""
  , ".selector, .leaf>span {"
  , "  padding: 2px 7px 2px 5px; "
  , "}"
  , ""
  , ".selector:hover, .leaf>span:hover {"
  , "  background: #FC9;"
  , "  -webkit-border-radius: 10px;"
  , "  -moz-border-radius: 10px;"
  , "}"
  , ""
  , ".leaf>span:hover {"
  , "  cursor: default;"
  , "}"
  , ""
  , ".selector:hover {"
  , "  cursor: pointer;"
  , "}"
  , ""
  , ".expanded .selector::before {"
  , "  font-size: 8pt;"
  , "  color: #999;"
  , "  content: \"\\25bc\";"
  , "}"
  , ""
  , ".collapsed .selector::before {"
  , "  font-size: 8pt;"
  , "  color: #999;"
  , "  content: \"\\25ba\";"
  , "  position: relative;"
  , ""
  , "}"
  , ""
  , ".selector:hover::before {"
  , "  color: orange;"
  , "}" ]


dumpHtmlAST :: String -> OpenAcc aenv a -> IO ()
dumpHtmlAST basename acc =
  catch writeHtmlFile handler
  where
    writeHtmlFile = do
      let cssPath = "accelerate.css"
      h <- openFile cssPath WriteMode
      hPutStr h accelerateCSS
      hClose h
      let path = basename ++ ".html"
      h <- openFile path WriteMode
      BS.hPutStr h (renderHtml $ htmlAST acc)
      putStrLn ("HTML file successfully written to `" ++ path ++ "'\n" ++
                "CSS file written to `" ++ cssPath ++ "'")
      hClose h
    handler :: IOError -> IO ()
    handler e =
      case True of
        _ | isAlreadyInUseError e -> putStrLn "isAlreadyInUseError"
          | isDoesNotExistError e -> putStrLn "isDoesNotExistError"
          | isFullError e         -> putStrLn "isFullError"
          | isEOFError e          -> putStrLn "isEOFError"
          | isPermissionError   e -> putStrLn "isPermissionError"
          | isIllegalOperation e  -> putStrLn "isIllegalOperation"
          | isUserError e         -> putStrLn "isUserError"
          | otherwise             -> putStrLn "Unknown error"

