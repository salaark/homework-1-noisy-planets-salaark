import {vec3, vec4} from 'gl-matrix';
import * as Stats from 'stats-js';
import * as DAT from 'dat-gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import Drawable from './rendering/gl/Drawable';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 6,
  'Load Scene': loadScene, // A function pointer, essentially
};

let icosphere: Icosphere;
let square: Square;
let cube: Cube;

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
  cube = new Cube(2);
  cube.create();
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  var shadertype = { shader: 2 };
  gui.add(shadertype, 'shader', { Lambert: 0, Fireball: 1, Planet: 2} );
  var shapetype = { shape: 0 };
  gui.add(shapetype, 'shape', { Icosphere: 0, Square: 1, Cube: 2 } );
  var sunparam = { intensity: 50.0 }
  gui.add(sunparam, 'intensity', 0.0, 200.0).onChange(updateIntensity);
  var colparam = {diffuse: [ 255.0, 0.0, 0.0, 1.0 ], specular: [ 255.0, 255.0, 0.0, 1.0 ], fog: [ 55.0, 85.0, 135.0, 1.0 ] };
  gui.addColor(colparam,'fog').onChange(updateFog);
  gui.addColor(colparam,'diffuse').onChange(updateColor);
  gui.addColor(colparam,'specular').onChange(updateSpecular);
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'Load Scene');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.1, 0.1, 0.1, 1);
  gl.enable(gl.DEPTH_TEST);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/lambert-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/lambert-frag.glsl')),
  ]);
  const fireball = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/fireball-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/fireball-frag.glsl')),
  ]);
  const planet = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/planet-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/planet-frag.glsl')),
  ]);

  // This function will be called every frame
  let time:number = 0;
  function tick() {
    time++;
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    let myshader: ShaderProgram = shadertype.shader == 1 ? fireball : shadertype.shader == 2 ? planet : lambert;
    let myshape: Drawable = shapetype.shape == 0 ? icosphere : shapetype.shape == 1 ? square : cube;
    myshader.setTime(time);
    myshader.setCameraPos(camera.position);
    renderer.render(camera, myshader, [ myshape ]);
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  //Update render color on gui change
  function updateColor() {
    lambert.setGeometryColor(vec4.fromValues(colparam.diffuse[0]/255, colparam.diffuse[1]/255,
        colparam.diffuse[2]/255, 1.0));
    fireball.setGeometryColor(vec4.fromValues(colparam.diffuse[0]/255, colparam.diffuse[1]/255,
        colparam.diffuse[2]/255, 1.0));
  }
  function updateSpecular() {
    lambert.setGeometrySpecular(vec4.fromValues(colparam.specular[0]/255, colparam.specular[1]/255,
        colparam.specular[2]/255, 1.0));
    fireball.setGeometrySpecular(vec4.fromValues(colparam.specular[0]/255, colparam.specular[1]/255,
        colparam.specular[2]/255, 1.0));
  }
  function updateFog() {
    planet.setFogColor(vec4.fromValues(colparam.fog[0]/255, colparam.fog[1]/255,
        colparam.fog[2]/255, 1.0));
  }
  function updateIntensity() {
    planet.setSunIntensity(sunparam.intensity);
  }
  updateColor();
  updateSpecular();
  updateIntensity();
  updateFog();

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
