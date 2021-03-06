module Projects.Foo
  (create, update)
where

import Effect
import Effect.Class.Console as Console
import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.List (List, (..))
import Data.List as List
import Data.Traversable as Traversable
import Effect.Class.Console (log)
import Math as Math
import Projects.BaseProject (Project)
import Projects.BaseProject as BaseProject
import Pure3.Circle as Circle
import Pure3.Interpolate as Interpolate
import Pure3.Point as Point
import Pure3.Types (Circle, Point(..))
import Three as Three
import Three.Geometry.BoxGeometry as BoxGeometry
import Three.Materials.MeshPhongMaterial as MeshPhongMaterial
import Three.Object3D as Object3D
import Three.Object3D.Light.AmbientLight as AmbientLight
import Three.Object3D.Light.DirectionalLight as DirectionalLight
import Three.Object3D.Mesh as Object3D.Mesh
import Three.Types (Object3D)

radius = 150.0
steps = 120
amplitude = 0.5
speed = 0.015
distance = 150.0
elements = 1
size = 600.0
boxColor = "#FEEBA6"
directionalColor = "#AEDDFF"
ambientColor = "#AEFFD3"
boxSize = 5.0

-- Add normals
-- helpers = scene.children.filter(isMesh).map(o =>  new THREE.FaceNormalsHelper( o, 80, 0x00ff00, 1 ));
-- helpers.forEach(hj => scene.add(hj))


points :: List Point
points = Interpolate.interpolate steps circle
         where circle = flip Circle.create radius center
               center = Point.create 0.0 0.0 0.0

updateBox :: Number -> Point -> Object3D -> Effect Unit 
updateBox t (Point {x,y,z}) o = do
  let tLoop = Math.cos(t * speed)
      -- waveOutX = x + ((x * tLoop) * ((z * z * 0.1)))
      -- TODO Move rad <-> deg to library
      rot1 = (Math.atan2 y x)
      rot2 = rot1 + (t * speed)
      rot3 = Math.sin (y/x * 0.5)
      -- scale1 = (y/x)
  Object3D.setPosition x y z o
  Object3D.setRotation 0.0 0.0 rot1 o
  -- _ <- Console.log (show tLoop)
  -- Object3D.setScale rot0 rot0 rot0 o
  v3 <- Three.createVector3 0.0 1.0 0.0
  Object3D.rotateOnAxis v3 rot2 o

update :: Project -> Number -> Effect Unit
update p t = 
  Traversable.sequence_ $ Array.zipWith (updateBox t) (Array.fromFoldable points) (BaseProject.getProjectObjects p) 

createBoxes :: List Point -> Effect (Array Object3D)
createBoxes ps = do
  boxColor <- Three.createColor boxColor
  boxMat <- MeshPhongMaterial.create boxColor true
  boxGs <- Traversable.traverse (\_ -> BoxGeometry.create 40.0 boxSize 40.0) ps
  boxMeshes <- Traversable.traverse (flip Object3D.Mesh.create boxMat) boxGs
  -- _ <- sequence_ $ zipWith setPositionByPoint points boxMeshes
  pure $ Array.fromFoldable boxMeshes

setPositionByPoint :: Point -> Object3D -> Effect Unit
-- Maybe make Object3D.setPosition accept a Point || Vector3 so we can avoid unwrapping points here?
setPositionByPoint (Point {x, y, z}) o = Object3D.setPosition x y z o

create :: Effect Project
create = do
  boxes <- createBoxes points
  dColor <- Three.createColor directionalColor
  dlight <-  DirectionalLight.create dColor 1.0
  aColor <- Three.createColor ambientColor
  alight <- AmbientLight.create aColor 0.75
  pure $ BaseProject.Project { objects: Array.concat [boxes <> [dlight, alight]], vectors: [] }
