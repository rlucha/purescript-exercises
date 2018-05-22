module Projects.Sealike 
  (create, update, Project, getProjectObjects, exportProjectObjects)
where

-- Todo Plane & Plane interpolation from 4 points (only 3 really needed)
-- Interpolate looks like an abstraction over n points
-- given 2 points, gives you a line, given 3+ gives you a surface

import Prelude
import Data.Array (fromFoldable)
import Data.Traversable (traverse, traverse_)
import Math (cos) as Math

import Pure3.Point as P
import Pure3.Line as L
import Pure3.Square as SQ
import Pure3.Transform as T
import Pure3.Interpolate as Interpolate
import Pure3.Scene as Scene

import Three (createGeometry, pushVertices, updateVector3Position, getVector3Position)
import Three.Types (Object3D, ThreeEff, Vector3, Object3D_)
import Three.Object3D (forceVerticesUpdate, unwrapObject3D) as Object3D
import Three.Object3D.Points (create) as Object3D.Points
import Projects.Sealike.SeaMaterial (createSeaMaterial)

-- Project config, maybe move to Record
size = 3000.0    
steps = 60       
freq = 0.003     
speed = 2.0     
amplitude = 40.0

center :: P.Point
center = P.create (-size * 0.25) 0.0 (-size * 0.25)

a :: P.Point
a = P.create 0.0 0.0 0.0

b :: P.Point
b = P.create size 0.0 0.0

c :: P.Point
c = P.create 0.0 0.0 size

d :: P.Point
d = P.create size 0.0 size

sq1 :: SQ.Square
sq1 = SQ.createFromLines (L.create a b) (L.create c d)

sq1c :: SQ.Square
sq1c = T.translateSquare sq1 center

sq1Points :: Array P.Point
sq1Points = fromFoldable $ Interpolate.interpolate sq1c steps

newtype Project = Project
  { objects :: Array Object3D
  , vectors :: Array Vector3 }

getProjectObjects :: Project -> Array Object3D
getProjectObjects (Project r) = r.objects

getProjectVectors :: Project -> Array Vector3
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
  let delta = (vpos.x + vpos.z) * freq
      waveY = (Math.cos (delta + speed * t)) * amplitude
      wave2 = (Math.cos (vpos.z + speed * t)) * amplitude * 0.4
  updateVector3Position vpos.x ( waveY + wave2) vpos.z v

update :: Project -> Number -> ThreeEff Unit
update p t = 
  let vs  = getProjectVectors p
      g   = getProjectObjects p
  in traverse_ (updateVector t) vs *> traverse_ Object3D.forceVerticesUpdate g

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
  pure $ Project { objects: [p], vectors: vs }

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