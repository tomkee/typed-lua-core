module Typechecker.Subtype where

import Data.Maybe (isNothing, fromJust)

import Types             (F(..), L(..), B(..), P(..), S(..), T(..), E(..), V(..), TType(..))
import AST               (Expr(..), Stm(..), Block(..), LHVal(..), ExprList(..))
import Typechecker.Utils (allT, anyT)
import Text.Show.Pretty  (ppShow    )

class Subtype a where 
  (<?) :: a -> a -> Bool


instance Subtype F where
    (FL LFalse       )    <? (FB BBoolean   )    = True
    (FL LTrue        )    <? (FB BBoolean   )    = True
    (FL (LString _  ))    <? (FB BString    )    = True
    (FL (LInt    _  ))    <? (FB BInt       )    = True
    (FL (LInt    _  ))    <? (FB BNumber    )    = True
    (FL (LFloat  _  ))    <? (FB BNumber    )    = True
    (FB  BInt        )    <? (FB BNumber    )    = True
    t1@(FTable ts1 tt1  ) <? t2@(FTable ts2 tt2) | tt1 == Unique && tt2 == Closed = sTable2 t1 t2
                                                 | tt1 `elem` [Fixed, Closed] && tt2 == Closed = sTable1 t1 t2 
                                                 | tt1 == Unique && tt2 `elem` [Unique, Open, Fixed] = sTable3 t1 t2
                                                 | tt1 == Open && tt2 == Closed = sTable4 t1 t2
                                                 | tt1 == Open && tt2 `elem` [Open, Fixed] = sTable5 t1 t2
                                                 | tt1 == Fixed && tt2 == Fixed = sTable6 t1 t2
    _                     <?  FValue             = True
    _                     <?  FAny               = True
    FAny                  <?  _                  = True
    FUnion fs             <? x                   = allT $ fmap (<? x) fs
    x                     <? FUnion fs           = anyT $ fmap (x <?) fs
    x                     <? y                   = x == y

data FieldSubtype = KVSubtype
                  | NotSubtype {_valType :: V}
                  | OnlyKSubtype
                  deriving(Show, Eq) 


sTable1, sTable2, sTable3, sTable4, sTable5, sTable6 :: F -> F -> Bool
sTable1 (FTable lefts tt1) (FTable rights tt2) =
    let rule (f', v') (f, v) = f <? f' && f' <? f && v `cSub` v'
        firstLaw = fmap (\x -> (fmap (rule x)  lefts)) rights
        forEachExists = allT $ fmap anyT firstLaw
    in  forEachExists


sTable2 (FTable ts1 tt1) (FTable ts2 tt2) = 
    let rule1 (f,v) (f',v') = if f <? f' then if v `uSub` v' then KVSubtype else OnlyKSubtype else NotSubtype v
        find :: [FieldSubtype] -> Bool
        find ((NotSubtype v):as) = (VF FNil) `oSub` v
        find (_:as) = find as
        find [] = False 
        condSubtyping1 = fmap (\x -> let subresult = fmap (rule1 x) ts2
                                     in if OnlyKSubtype `elem` subresult then False else if KVSubtype `elem` subresult then True else find subresult

                              ) ts1
    in allT condSubtyping1
 

sTable3 (FTable ts1 tt1) (FTable ts2 tt2) = 
    let lefts  = zip3 ([0..]) (fst <$> ts1) (snd <$> ts1)
        rights = zip3 ([0..]) (fst <$> ts2) (snd <$> ts2)
        lrProd = [(x,y) | x <- lefts, y <- rights]
        rule1 (i,f,v) (j,f',v') = f <? f' && v `uSub` v'
        firstLaw = fmap (\x -> (fmap (rule1 x) rights)) lefts
        forEachExists = allT $ fmap anyT firstLaw
        rule2 ((i, f, v),(j, f', v')) = if f <? f' then not (VF FNil `oSub` v') else True 
        forEachDoesNotExist = allT $ fmap rule2 lrProd
    in  forEachExists && forEachDoesNotExist


sTable4 (FTable ts1 tt1) (FTable ts2 tt2) = 
    let lefts  = zip3 ([0..]) (fst <$> ts1) (snd <$> ts1)
        rights = zip3 ([0..]) (fst <$> ts2) (snd <$> ts2)
        lrProd = [(x,y) | x <- lefts, y <- rights]
        firstLaw ((_, f, v),(_, f', v')) = if f <? f' then v `cSub` v' else True
        secondLaw ((i, f, v),(j, f', v')) = if f <? f' then not (VF FNil `oSub` v') else True 
        condSubtyping1 = fmap firstLaw lrProd
        condSubtyping2 = fmap secondLaw lrProd
    in allT condSubtyping1 && allT condSubtyping2


sTable5 (FTable ts1 tt1) (FTable ts2 tt2) = 
    let lefts  = zip3 ([0..]) (fst <$> ts1) (snd <$> ts1)
        rights = zip3 ([0..]) (fst <$> ts2) (snd <$> ts2)
        lrProd = [(x,y) | x <- lefts, y <- rights]
        rule1 (i,f,v) (j,f',v') = f <? f' && v `cSub` v'
        firstLaw = fmap (\x -> (fmap (rule1 x) rights)) lefts
        forEachExists = allT $ fmap anyT firstLaw
        rule2 ((i, f, v),(j, f', v')) = if f <? f' then not (VF FNil `oSub` v') else True 
        forEachDoesNotExist = allT $ fmap rule2 lrProd
    in  forEachExists && forEachDoesNotExist


sTable6 (FTable ts1 tt1) (FTable ts2 tt2) = 
    let lefts  = zip3 ([0..]) (fst <$> ts1) (snd <$> ts1)
        rights = zip3 ([0..]) (fst <$> ts2) (snd <$> ts2)
        rule12 (i,f,v) (j,f',v') = f <? f' && f' <? f && v `cSub` v'
        firstLaw = fmap (\x -> (fmap (rule12 x) rights)) lefts
        secondLaw = fmap (\x -> (fmap (rule12 x) lefts)) rights
        forEachExistsij = allT $ fmap anyT firstLaw
        forEachExistsji = allT $ fmap anyT secondLaw
    in  forEachExistsij && forEachExistsji


instance Subtype S where
    SUnion ss <? SP p      = allT $ fmap (<? p) ss
    SP p      <? SUnion ss = anyT $ fmap (p <?) ss
    SP p1     <? SP p2     = p1 <? p2


instance Subtype P where 
    P fs1 mf1 <? P fs2 mf2 = allT $ fmap (uncurry (<?)) (tupleZip fs1 mf1 fs2 mf2)


tupleZip ls l rs r | length ls == length rs = zip ls rs
                   | length ls < length rs = zip (ls ++ repeat (if isNothing l then FNil else fromJust l)) rs
                   | otherwise = zip ls (rs ++ repeat (if isNothing r then FNil else fromJust r))


instance Subtype T where
    TF f1         <? TF f2         = f1 <? f2
    TFilter x1 y1 <? TFilter x2 y2 = (x1 == x2) && (y1 == y2)
    TProj x1 i1   <? TProj x2 i2   = (x1 == x2) && (i1 == i2 )


instance Subtype E where
    E ts1 mt1 <? E ts2 mt2 = allT $ fmap (uncurry (<?)) (tupleZipE ts1 mt1 ts2 mt2)


tupleZipE ls l rs r | length ls == length rs = zip ls rs
                   | length ls < length rs = zip (ls ++ repeat (if isNothing l then (TF FNil) else fromJust l)) rs
                   | otherwise = zip ls (rs ++ repeat (if isNothing r then (TF FNil) else fromJust r))


-- subtyping for V
cSub, oSub, uSub :: V -> V -> Bool
cSub (VF f1) (VF f2) = f1 <? f2 && f2 <? f1
cSub (VConst f1) (VConst f2) = f1 <? f2
cSub (VF f1) (VConst f2) = f1 <? f2

uSub (VF f1) (VF f2) = f1 <? f2 
uSub (VConst f1) (VConst f2) = f1 <? f2
uSub (VConst f1) (VF f2) = f1 <? f2
uSub (VF f1) (VConst f2) = f1 <? f2

oSub (VF FNil) (VF f) = FNil <? f
oSub (VF FNil) (VConst f) = FNil <? f



