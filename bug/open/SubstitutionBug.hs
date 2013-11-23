{-# LANGUAGE ExistentialQuantification , RankNTypes #-}
-- The 'unsafeUnbind' usage is ... wait for it ... unsafe :P
--
-- Run with 'runhaskell SubstitutionBug.hs'.

import PatternUnify.Tm
import PatternUnify.Context
import Common.PrettyPrint
import Common.Names
import Common.BwdFwd
import Control.Monad

-- Heterogeneous list elements supporting 'Pretty' and 'Show'.
data H = forall a. (Pretty a , Show a) => H a

egs :: [(String , [H])]
egs = runFreshM $ do
  x0 <- fresh . s2n $ "x"
  x1 <- fresh . s2n $ "x"
  x2 <- fresh . s2n $ "x"
  y  <- fresh . s2n $ "y"
  z  <- fresh . s2n $ "z"
  let x = x0
  let v0 = V x0 Only
      v1 = V x1 Only
      v2 = V x2 Only
      n0 = N v0 B0
      n1 = N v1 B0
      n2 = N v2 B0
      eg1 = L (bind x0 (L (bind x1 (C (Pair n0 n1)))))
      eg2 = n1
      eg3 = L (bind x0 (L (bind x1 (N v0 (B0 :< A n1 :< A n0)))))
      eg4 = n2

      -- This is supposed to be equivalent to the failing 'Problem'
      -- substitution example ... but it works !!! ???
      eg5Body = appM z (B0 :< A (var x) :< A (var y) :< A (var y))
      eg5 = lams [ z , x , y ] eg5Body
      eg6Body = appV x (B0 :< If (bindK (C Bool)) (var x) (C False'))
      eg6 = lam x . lamK . lamK $ eg6Body
      eg7 = lams [ x , y ] eg5Body

      -- The 'Problem' version: fails as in 'PatternUnify.Tests.tests !! 14'!
      eg8 = allProb x (C Bool) . allProb y (C Bool) $ eqnProb (C Bool) eg5Body (C Bool) eg6Body

  eg1eg2 <- eg1 $$ eg2
  eg3eg2 <- eg3 $$ eg2
  eg1eg2eg4 <- eg1eg2 $$ eg4
  eg3eg2eg4 <- eg3eg2 $$ eg4
  eg5eg6 <- eg5 $$ eg6
  eg6IntoEg7 <- substM z eg6 eg7
  eg6IntoEg8 <- substM z eg6 eg8

  return $ [ ("app" , [ H eg1 , H eg2 , H eg1eg2 ])
           , ("app" , [ H eg3 , H eg2 , H eg3eg2 ])
           , ("app" , [ H eg1eg2 , H eg4 , H eg1eg2eg4 ])
           , ("app" , [ H eg3eg2 , H eg4 , H eg3eg2eg4 ])
           , ("app" , [ H eg5 , H eg6 , H eg5eg6 ])
           , ("sub" , [ H z , H eg6 , H eg7 , H eg6IntoEg7 ])
           , ("sub" , [ H z , H eg6 , H eg8 , H eg6IntoEg8 ])
           -- , eg1 $$ eg2 -- Should be \ x2 . Pair x1 x2 for *fresh* x
           --              -- but it's  \ x1 . Pair x1 x1 instead :P
           ]

main = do
  forM_ egs $ \ x -> do
    print show x
    putStrLn ""
    print ppp x
    putStrLn ""
    putStrLn ""
 where
  print :: (forall a. (Pretty a , Show a) => a -> String) -> (String , [H]) -> IO ()
  print p (s , hs) = do
    putStrLn $ s
    forM_ (init hs) $ \ (H h) -> do
      putStrLn $ p h
    -- If we instead use 'let H h = last hs' then GHC says:
    --
    --   My brain just exploded
    --   I can't handle pattern bindings for existential or GADT data constructors.
    --   Instead, use a case-expression, or do-notation, to unpack the constructor.
    --
    -- :D
    case last hs of
      H h -> putStrLn $ "=\n" ++ p h
