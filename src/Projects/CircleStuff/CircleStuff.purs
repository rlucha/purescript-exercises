module Projects.CircleStuff
  (create, update, Project, exportProjectObjects)
where

-- Todo Plane & Plane interpolation from 4 points (only 3 really needed)
-- Interpolate looks like an abstraction over n points
-- given 2 points, gives you a line, given 3+ gives you a surface

import Prelude
import Data.Int (toNumber)
import Data.List (List, (..), concat, zipWith)
import Data.Array (fromFoldable)
import Data.Traversable (traverse, traverse_, sequence_)
import Math (cos, sin) as Math

import Pure3.Point as P
import Pure3.Circle as C
import Pure3.Interpolate as Interpolate
import Pure3.Scene as Scene

import Three (createColor, createGeometry, getVector3Position, pushVertices, updateVector3Position)
import Three.Geometry.BoxGeometry (createBoxGeometry)
import Three.Types (Object3D, Object3D_, ThreeEff, Vector3)
import Three.Object3D (setPosition, unwrapObject3D, forceVerticesUpdate, getPosition) as Object3D
import Three.Object3D.Points (create) as Object3D.Points
import Three.Object3D.Mesh (create) as Object3D.Mesh
import Three.Materials.MeshBasicMaterial (createMeshBasicMaterial)

import Projects.Sealike.SeaMaterial (createSeaMaterial)

-- Project config, maybe move to Record
radius :: Number
radius = 100.0
steps :: Int
steps = 120
amplitude :: Number
amplitude = 20.0
speed :: Number
speed = 2.0
distance :: Number
distance = 15.0
elements :: Int
elements = 5
size = 3.0

centers :: List P.Point
centers = (\n -> P.create 0.0 0.0 (n * distance)) <<< toNumber <$> -elements..elements

-- aoid using a lambda here using applicative? problem is radius is not in a context
circles :: List C.Circle
circles = (\c -> C.create c radius) <$> centers

sq1Points :: List P.Point
sq1Points = concat $ (\c -> Interpolate.interpolate c steps) <$> circles

-- Create a union type of things that can go into a project
-- end be exported by it
-- Meaning... things can can be added to a ThreeJS scene

newtype Project = Project
  { objects :: Array Object3D
  , vectors :: List Vector3 }

-- make a function that aggregates project objects by type using the constructor
-- we can enum to begin with, but we should do a generic one
getProjectObjects :: Project -> Array Object3D
getProjectObjects (Project r) = r.objects

getProjectVectors :: Project -> List Vector3
getProjectVectors (Project r) = r.vectors

exportProjectObjects :: Project -> Array Object3D_
exportProjectObjects (Project r) = Object3D.unwrapObject3D <$> r.objects

-- Things that can be created on init
-- geometry
-- materials
-- vector3s
-- points

-- update shoud take all those and update positions only
-- Should a scene have State?, that way we can easily mutate a
-- scene state in a performant way.

updateVector :: Number -> Vector3 -> ThreeEff Unit
updateVector t v = do
  vpos <- getVector3Position v
  -- we need some initial position to use it as a reference point for
  -- incremental changes
  -- reader monad here?
  let delta = (vpos.x / vpos.y)
              -- 0pos    + pos dependant cos over time and amplitude
      waveOutX = (vpos.x + ((vpos.x * (Math.cos (t * speed))) * amplitude) * vpos.z / 10.0)
      waveOutY = (vpos.y + ((vpos.y * (Math.cos (t * speed))) * amplitude) * vpos.z / 10.0)
  updateVector3Position waveOutX waveOutY vpos.z v

-- Make this work for any kind of objects
-- Or better, split into two functions for boxes and points
-- updateObject :: Object3D -> ThreeEff Unit
-- updateObject t o = case o of
--   Points o' -> updateVector o'
--   Mesh o' -> updateVector o' v

-- TODO Object3D get position (and all Object3D stuff as a record representation)
-- get position or else eveything will get the same pos always
updateBox :: Number -> Object3D -> ThreeEff Unit
updateBox t o = do
  posV3 <- Object3D.getPosition o
  let waveOutX = posV3.x + ((posV3.x * Math.cos(t * speed)) * (posV3.z * 0.1) * 0.001)
      waveOutY = posV3.y + ((posV3.y * Math.cos(t * speed)) * (posV3.z * 0.1) * 0.001)
  Object3D.setPosition waveOutX waveOutY posV3.z o

updateBoxes :: Project -> Number -> ThreeEff Unit
updateBoxes p t = 
  let obs = getProjectObjects p
    in traverse_ (updateBox t) obs 

updatePoints :: Project -> Number -> ThreeEff Unit
updatePoints p t =
  let vs  = getProjectVectors p
      g   = getProjectObjects p
  in traverse_ (updateVector t) vs *> (sequence_ $ Object3D.forceVerticesUpdate <$> g)

update = updateBoxes

createBoxes :: List P.Point -> ThreeEff (Array Object3D)
createBoxes ps = do
  bgColor <- createColor "#ff0000"
  boxMat <- createMeshBasicMaterial bgColor  
  -- create an many boxes as points
  boxGs <- traverse (\_ -> createBoxGeometry size size size) ps  -- ps ThreeEff (Array Geometry) -- Points -> Threeff Geometry
  boxMeshes <- traverse (\g -> Object3D.Mesh.create g boxMat) boxGs
  -- Can't get my head around this...
  -- How to apply a binary function mapped over two list of arguments?
  _ <- sequence_ $ zipWith setPositionByPoint sq1Points boxMeshes
  pure $ fromFoldable boxMeshes

setPositionByPoint :: P.Point -> Object3D -> ThreeEff Unit
setPositionByPoint p o = 
  let {x, y, z} = P.unwrap p
  in Object3D.setPosition x y z o

create :: ThreeEff Project
create = do
  g <- createGeometry
  m <- createSeaMaterial
  -- this scene 'unparsing' will be done at the scene graph parsing level
  -- eventually
  vs <- traverse Scene.createVectorFromPoint sq1Points
  -- here we are mutating g in JS... then using the reference in create g
  -- should we express that effect somehow?
  _ <- traverse_ (pushVertices g) vs
  p <- Object3D.Points.create g m
  -- BOX -------------
  boxes <- createBoxes sq1Points
  -- Setting this position is not working because a weird type error
  -- _ <- sequence_ $ (setPositionByPoint <$> boxes) <*> fromFoldable sq1Points
  pure $ Project { objects: boxes, vectors: vs }

-- Explain why traverse works and pure fmap does not
-- traverse actually executes the effects , pure fmap does not...
-- traverese evaluates m b becase it needs to lift the value our of m to create t of m
-- fmap just needs to put b into f, without actually extracting the value
  -- _ <- traverse (pushVertices g) vs
  -- _ <- pure $ (pushVertices g) <$> vs


-- Scene now will use ThreeJS directly instead of just coordinate manipulation

-- var dotGeometry = new Geometry();
-- var dotMaterial = new PointsMaterial( { size: 1, sizeAttenuation: false } );
-- dotGeometry.vertices.push(new Vector3(x, y, z));
-- var dot = new Points(dotGeometry, dotMaterial);
-- scene.add(dot)

-- Make Scene not require empty lines to be created
-- scene = Scene.create
--   { points: sq1Points
--   , lines: []
--   , squares: []
--   , meshes: []
--   }
