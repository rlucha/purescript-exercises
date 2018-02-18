module Scenes.BoxToBox where

import Prelude
import Data.List (List, toUnfoldable, zipWith, concat)

import Point as P
import Line as L
import Scene as S

data Square = Square 
  { a :: P.Point, 
    b :: P.Point,
    c :: P.Point,
    d :: P.Point
  }

steps = 15
size = 100.0 
alt = size*0.5
center = -size*0.5

-- Move to Square module
create :: P.Point -> P.Point -> P.Point -> P.Point -> Square
create a b c d = Square {a:a, b:b, c:c, d:d}

interpolateSquare :: Square -> List P.Point
interpolateSquare (Square s) = 
  (squareInterpolation s.a s.b <>
   squareInterpolation s.b s.c <>
   squareInterpolation s.c s.d <>
   squareInterpolation s.d s.a)
  where squareInterpolation a b = L.interpolateLine steps $ L.create a b

a = P.create 0.0 0.0 0.0
b = P.create 0.0 0.0 size
c = P.create size 0.0 size
d = P.create size 0.0 0.0

e = P.create 0.0 0.0 alt
f = P.create alt 0.0 size
g = P.create size 0.0 alt
h = P.create alt 0.0 0.0


-- MOVE to translate module
translate x y z g = (P.create x y z) + g
translateX x g = translate x 0.0 0.0 g
translateY y g = translate 0.0 y 0.0 g
translateZ z g = translate 0.0 0.0 z g

-- How to implement rotation...
-- And rotate from where?

-- Implement scale too


scene :: Number -> S.Scene
scene t = (S.Scene (toUnfoldable $ translate center center center <$> zipSquareLines))
  where 
    square = interpolateSquare $ create a b c d
    square' = interpolateSquare $ create e f g h
    square2 = translateY t <$> square'
    tempInterpolation = (\a b -> L.interpolateLine steps $ L.create a b)
    zipSquareLines = concat $ zipWith tempInterpolation square square2