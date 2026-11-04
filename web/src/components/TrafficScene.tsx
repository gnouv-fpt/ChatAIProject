import { useEffect, useRef, useState } from 'react';
import {
  Box,
  Camera,
  Compass,
  Expand,
  Layers,
  Pause,
  Play,
  RotateCcw,
  ShieldCheck,
  Sparkles,
  TrafficCone,
  X,
} from 'lucide-react';
import { Modal } from './Modal';

type SceneMode = 'intersection' | 'showroom';
type CameraPreset = 'overview' | 'driver' | 'topdown';
type VehicleKey = 'car' | 'moto' | 'truck' | 'ambulance' | 'fire';
type SignalPhase = 'green' | 'amber' | 'priority';

const VEHICLE_SPECS: Record<
  VehicleKey,
  {
    label: string;
    badge: string;
    license: string;
    rule: string;
    color: string;
  }
> = {
  car: {
    label: 'Ô tô con đô thị',
    badge: 'Hatchback 5 cửa · GLB 3D',
    license: 'Hạng B',
    rule: 'Đi thẳng trên đường cùng cấp: nhường xe ưu tiên và xe đi từ bên phải không vướng.',
    color: '#dc2626',
  },
  moto: {
    label: 'Mô tô hai bánh',
    badge: 'Sport Motorcycle · GLB 3D',
    license: 'Hạng A1 / A',
    rule: 'Rẽ phải tại ngã tư: bật tín hiệu báo hướng rẽ, đi sát lề đường bên phải.',
    color: '#d97706',
  },
  truck: {
    label: 'Xe tải thùng kín',
    badge: 'Box Truck · GLB 3D',
    license: 'Hạng C1 / C',
    rule: 'Rẽ trái qua giao lộ: phải nhường đường cho xe đi thẳng và xe rẽ phải đối diện.',
    color: '#0284c7',
  },
  ambulance: {
    label: 'Xe cứu thương',
    badge: 'Xe ưu tiên · GLB 3D',
    license: 'Quyền ưu tiên',
    rule: 'Đang thực hiện nhiệm vụ cấp cứu có đèn và còi: được đi trước các phương tiện thông thường.',
    color: '#16a34a',
  },
  fire: {
    label: 'Xe chữa cháy',
    badge: 'Ưu tiên số 1 · GLB 3D',
    license: 'Quyền ưu tiên số 1',
    rule: 'Thứ tự ưu tiên cao nhất theo Luật TTATGT đường bộ: mọi phương tiện phải nhường đường.',
    color: '#b91c1c',
  },
};

export function TrafficScene({ variant = 'full' }: { variant?: 'full' | 'compact' }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const hostRef = useRef<HTMLDivElement | null>(null);

  const [paused, setPaused] = useState(false);
  const [sceneMode, setSceneMode] = useState<SceneMode>('intersection');
  const [cameraPreset, setCameraPreset] = useState<CameraPreset>('overview');
  const [activeVehicle, setActiveVehicle] = useState<VehicleKey>('car');
  const [signalPhase, setSignalPhase] = useState<SignalPhase>('green');
  const [webglReady, setWebglReady] = useState(false);
  const [loadedModelsCount, setLoadedModelsCount] = useState(0);
  const [openSaHinhModal, setOpenSaHinhModal] = useState<'q490' | 'models' | null>(null);

  const stateRef = useRef({
    paused,
    sceneMode,
    cameraPreset,
    activeVehicle,
    signalPhase,
    resetTrigger: 0,
  });

  useEffect(() => {
    stateRef.current.paused = paused;
    stateRef.current.sceneMode = sceneMode;
    stateRef.current.cameraPreset = cameraPreset;
    stateRef.current.activeVehicle = activeVehicle;
    stateRef.current.signalPhase = signalPhase;
  }, [paused, sceneMode, cameraPreset, activeVehicle, signalPhase]);

  useEffect(() => {
    let disposed = false;
    let animationFrameId = 0;
    let cleanupFn: (() => void) | undefined;

    async function initThreeScene() {
      const canvas = canvasRef.current;
      const host = hostRef.current;
      if (!canvas || !host) return;

      try {
        const threeUrl = '/c2-3d/vendor/three/three.module.min.js';
        const orbitUrl = '/c2-3d/vendor/three/OrbitControls.js';
        const envUrl = '/c2-3d/vendor/three/RoomEnvironment.js';
        const detailedUrl = '/c2-3d/q490-detailed-models.js?v=city-1';
        const fleetUrl = '/c2-3d/review-detailed-fleet.js';

        const [THREE, { OrbitControls }, { RoomEnvironment }] = await Promise.all([
          import(/* @vite-ignore */ threeUrl),
          import(/* @vite-ignore */ orbitUrl),
          import(/* @vite-ignore */ envUrl),
        ]);

        if (disposed) return;

        const renderer = new THREE.WebGLRenderer({
          canvas,
          antialias: true,
          alpha: false,
          powerPreference: 'high-performance',
        });
        renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
        renderer.shadowMap.enabled = true;
        renderer.shadowMap.type = THREE.PCFSoftShadowMap;
        renderer.toneMapping = THREE.ACESFilmicToneMapping;
        renderer.toneMappingExposure = 1.15;

        const scene = new THREE.Scene();
        scene.background = new THREE.Color('#192430');

        const camera = new THREE.PerspectiveCamera(35, 16 / 10, 0.1, 220);
        camera.position.set(16.5, 12.8, 17.5);

        const controls = new OrbitControls(camera, renderer.domElement);
        controls.enableDamping = true;
        controls.dampingFactor = 0.08;
        controls.enablePan = false;
        controls.minDistance = 4.2;
        controls.maxDistance = 36;
        controls.maxPolarAngle = Math.PI / 2 - 0.06;
        controls.target.set(0, 0.6, 0);
        controls.update();

        const env = new RoomEnvironment();
        const pmrem = new THREE.PMREMGenerator(renderer);
        scene.environment = pmrem.fromScene(env, 0.04).texture;
        scene.environmentIntensity = 0.8;
        env.dispose();
        pmrem.dispose();

        const hemi = new THREE.HemisphereLight(0xfff6d6, 0x334155, 2.3);
        scene.add(hemi);

        const sun = new THREE.DirectionalLight(0xfffaed, 3.2);
        sun.position.set(14, 24, 12);
        sun.castShadow = true;
        sun.shadow.mapSize.set(1024, 1024);
        Object.assign(sun.shadow.camera, {
          left: -18,
          right: 18,
          top: 18,
          bottom: -18,
          near: 1,
          far: 60,
        });
        sun.shadow.bias = -0.0005;
        scene.add(sun);

        const intersectionGroup = new THREE.Group();
        const showroomGroup = new THREE.Group();
        showroomGroup.visible = false;
        scene.add(intersectionGroup);
        scene.add(showroomGroup);

        const matAsphalt = new THREE.MeshStandardMaterial({ color: '#24313e', roughness: 0.86, metalness: 0.08 });
        const matSidewalk = new THREE.MeshStandardMaterial({ color: '#e5d4a0', roughness: 0.78, metalness: 0.05 });
        const matGrass = new THREE.MeshStandardMaterial({ color: '#3b724e', roughness: 0.9 });
        const matWhiteLine = new THREE.MeshStandardMaterial({ color: '#f8fafc', roughness: 0.35 });
        const matYellowLine = new THREE.MeshStandardMaterial({
          color: '#facc15',
          emissive: '#ca8a04',
          emissiveIntensity: 0.3,
          roughness: 0.35,
        });
        const matCurbRed = new THREE.MeshStandardMaterial({ color: '#dc2626', roughness: 0.45 });
        const matPole = new THREE.MeshStandardMaterial({ color: '#94a3b8', metalness: 0.7, roughness: 0.3 });
        const matBox = new THREE.MeshStandardMaterial({ color: '#0f172a', roughness: 0.4 });

        // 1. 3D Road & Intersection Base
        const baseGround = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), matAsphalt);
        baseGround.rotation.x = -Math.PI / 2;
        baseGround.receiveShadow = true;
        intersectionGroup.add(baseGround);

        const roadHalf = 4.6;
        const cornerSize = 16;
        const corners = [
          [-1, -1],
          [1, -1],
          [-1, 1],
          [1, 1],
        ];
        corners.forEach(([sx, sz], idx) => {
          const cx = sx * (roadHalf + cornerSize / 2);
          const cz = sz * (roadHalf + cornerSize / 2);
          const block = new THREE.Mesh(new THREE.BoxGeometry(cornerSize, 0.28, cornerSize), matSidewalk);
          block.position.set(cx, 0.14, cz);
          block.receiveShadow = true;
          block.castShadow = true;
          intersectionGroup.add(block);

          const turf = new THREE.Mesh(new THREE.BoxGeometry(cornerSize - 1.6, 0.08, cornerSize - 1.6), matGrass);
          turf.position.set(cx + sx * 0.4, 0.3, cz + sz * 0.4);
          turf.receiveShadow = true;
          intersectionGroup.add(turf);

          for (let i = 0; i < 6; i++) {
            const stripeX = new THREE.Mesh(
              new THREE.BoxGeometry(1.1, 0.3, 0.24),
              i % 2 === 0 ? matCurbRed : matWhiteLine
            );
            stripeX.position.set(sx * (roadHalf + 0.8 + i * 1.15), 0.15, sz * (roadHalf + 0.12));
            intersectionGroup.add(stripeX);

            const stripeZ = new THREE.Mesh(
              new THREE.BoxGeometry(0.24, 0.3, 1.1),
              i % 2 === 0 ? matWhiteLine : matCurbRed
            );
            stripeZ.position.set(sx * (roadHalf + 0.12), 0.15, sz * (roadHalf + 0.8 + i * 1.15));
            intersectionGroup.add(stripeZ);
          }

          if (idx === 0 || idx === 3) {
            const bldgMat = new THREE.MeshStandardMaterial({
              color: idx === 0 ? '#f3dd99' : '#cbd5e1',
              roughness: 0.6,
            });
            const roofMat = new THREE.MeshStandardMaterial({
              color: idx === 0 ? '#b45309' : '#475569',
              roughness: 0.5,
            });
            const bldg = new THREE.Mesh(new THREE.BoxGeometry(4.0, idx === 0 ? 3.0 : 4.2, 4.0), bldgMat);
            bldg.position.set(sx * (roadHalf + 4.8), (idx === 0 ? 3.0 : 4.2) / 2 + 0.3, sz * (roadHalf + 4.8));
            bldg.castShadow = true;
            bldg.receiveShadow = true;
            intersectionGroup.add(bldg);

            const roof = new THREE.Mesh(new THREE.BoxGeometry(4.3, 0.35, 4.3), roofMat);
            roof.position.set(sx * (roadHalf + 4.8), (idx === 0 ? 3.0 : 4.2) + 0.45, sz * (roadHalf + 4.8));
            intersectionGroup.add(roof);
          }
        });

        for (const sign of [-1, 1]) {
          const centerLineX = new THREE.Mesh(new THREE.BoxGeometry(14, 0.02, 0.14), matYellowLine);
          centerLineX.position.set(sign * (roadHalf + 7.5), 0.015, 0);
          intersectionGroup.add(centerLineX);

          const centerLineZ = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.02, 14), matYellowLine);
          centerLineZ.position.set(0, 0.015, sign * (roadHalf + 7.5));
          intersectionGroup.add(centerLineZ);

          const stopX = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.02, roadHalf - 0.4), matWhiteLine);
          stopX.position.set(sign * (roadHalf + 0.9), 0.016, -sign * (roadHalf / 2));
          intersectionGroup.add(stopX);

          const stopZ = new THREE.Mesh(new THREE.BoxGeometry(roadHalf - 0.4, 0.02, 0.3), matWhiteLine);
          stopZ.position.set(sign * (roadHalf / 2), 0.016, sign * (roadHalf + 0.9));
          intersectionGroup.add(stopZ);

          for (let z = -roadHalf + 0.7; z <= roadHalf - 0.7; z += 0.95) {
            const zebraX = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.02, 0.42), matWhiteLine);
            zebraX.position.set(sign * (roadHalf + 0.1), 0.015, z);
            intersectionGroup.add(zebraX);

            const zebraZ = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.02, 1.5), matWhiteLine);
            zebraZ.position.set(z, 0.015, sign * (roadHalf + 0.1));
            intersectionGroup.add(zebraZ);
          }

          for (let d = 2.5; d < 14; d += 2.2) {
            for (const laneOffset of [-2.3, 2.3]) {
              const dashX = new THREE.Mesh(new THREE.BoxGeometry(1.0, 0.018, 0.1), matWhiteLine);
              dashX.position.set(sign * (roadHalf + d), 0.014, laneOffset);
              intersectionGroup.add(dashX);

              const dashZ = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.018, 1.0), matWhiteLine);
              dashZ.position.set(laneOffset, 0.014, sign * (roadHalf + d));
              intersectionGroup.add(dashZ);
            }
          }
        }

        const signalLights: { red: any; amber: any; green: any }[] = [];
        [
          { x: roadHalf + 0.7, z: roadHalf + 0.7, rotY: -Math.PI / 4 },
          { x: -(roadHalf + 0.7), z: -(roadHalf + 0.7), rotY: (3 * Math.PI) / 4 },
        ].forEach(cfg => {
          const rig = new THREE.Group();
          rig.position.set(cfg.x, 0.28, cfg.z);
          rig.rotation.y = cfg.rotY;

          const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.13, 3.8, 12), matPole);
          pole.position.y = 1.9;
          pole.castShadow = true;
          rig.add(pole);

          const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, 2.4, 10), matPole);
          arm.rotation.z = Math.PI / 2;
          arm.position.set(-1.1, 3.6, 0);
          rig.add(arm);

          const housing = new THREE.Mesh(new THREE.BoxGeometry(0.42, 1.15, 0.34), matBox);
          housing.position.set(-1.9, 3.45, 0);
          rig.add(housing);

          const makeBulb = (yOffset: number, colorHex: string) => {
            const mat = new THREE.MeshStandardMaterial({
              color: colorHex,
              emissive: colorHex,
              emissiveIntensity: 0.2,
              roughness: 0.2,
            });
            const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.11, 14, 14), mat);
            bulb.position.set(-1.9, 3.45 + yOffset, 0.16);
            rig.add(bulb);
            return mat;
          };

          signalLights.push({
            red: makeBulb(0.32, '#ef4444'),
            amber: makeBulb(0, '#f59e0b'),
            green: makeBulb(-0.32, '#22c55e'),
          });

          intersectionGroup.add(rig);
        });

        // Custom Arc-Length Smooth Route Builder (zero reliance on trimmed Curve classes)
        type SmoothRoute = {
          totalLength: number;
          sampleAt: (u: number) => { pos: any; tangent: any; nextTangent: any };
        };

        const buildSmoothRoute = (rawWaypoints: [number, number, number][], colorHex: string): SmoothRoute => {
          const wp = rawWaypoints.map(([x, y, z]) => new THREE.Vector3(x, y, z));
          const dense: any[] = [];
          const stepsPerSeg = 40;

          for (let i = 0; i < wp.length - 1; i++) {
            const p0 = wp[Math.max(0, i - 1)];
            const p1 = wp[i];
            const p2 = wp[i + 1];
            const p3 = wp[Math.min(wp.length - 1, i + 2)];
            for (let s = 0; s < stepsPerSeg; s++) {
              const t = s / stepsPerSeg;
              const t2 = t * t;
              const t3 = t2 * t;
              // Catmull-Rom spline formula
              const x =
                0.5 *
                (2 * p1.x +
                  (-p0.x + p2.x) * t +
                  (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                  (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3);
              const z =
                0.5 *
                (2 * p1.z +
                  (-p0.z + p2.z) * t +
                  (2 * p0.z - 5 * p1.z + 4 * p2.z - p3.z) * t2 +
                  (-p0.z + 3 * p1.z - 3 * p2.z + p3.z) * t3);
              dense.push(new THREE.Vector3(x, p1.y, z));
            }
          }
          dense.push(wp[wp.length - 1].clone());

          const distances = [0];
          for (let i = 1; i < dense.length; i++) {
            distances.push(distances[i - 1] + dense[i].distanceTo(dense[i - 1]));
          }
          const totalLength = distances[distances.length - 1] || 1;

          const getAtDistance = (dist: number) => {
            const clamped = Math.max(0, Math.min(totalLength, dist));
            let lo = 0;
            let hi = distances.length - 1;
            while (hi - lo > 1) {
              const mid = (lo + hi) >> 1;
              if (distances[mid] < clamped) lo = mid;
              else hi = mid;
            }
            const span = distances[hi] - distances[lo] || 1;
            const alpha = (clamped - distances[lo]) / span;
            return dense[lo].clone().lerp(dense[hi], alpha);
          };

          // Render 3D trajectory guide markers along the road
          const markerMat = new THREE.MeshStandardMaterial({
            color: colorHex,
            emissive: colorHex,
            emissiveIntensity: 0.55,
            roughness: 0.3,
          });
          const markerCount = 26;
          for (let m = 1; m < markerCount; m++) {
            const d = (m / markerCount) * totalLength;
            const pA = getAtDistance(d);
            const pB = getAtDistance(Math.min(totalLength, d + 0.5));
            const dir = pB.clone().sub(pA);
            const seg = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.026, 0.14), markerMat);
            seg.position.copy(pA);
            seg.rotation.y = Math.atan2(-dir.z, dir.x);
            intersectionGroup.add(seg);
          }

          return {
            totalLength,
            sampleAt(u: number) {
              const norm = Math.max(0, Math.min(1, u));
              const d = norm * totalLength;
              const pos = getAtDistance(d);
              const ahead = getAtDistance(Math.min(totalLength, d + 0.65));
              const further = getAtDistance(Math.min(totalLength, d + 1.35));
              const tangent = ahead.clone().sub(pos);
              if (tangent.lengthSq() < 1e-6) tangent.set(1, 0, 0);
              else tangent.normalize();
              const nextTangent = further.clone().sub(ahead);
              if (nextTangent.lengthSq() < 1e-6) nextTangent.copy(tangent);
              else nextTangent.normalize();
              return { pos, tangent, nextTangent };
            },
          };
        };

        // Keep each path inside its lane. Turns use a broad arc so long vehicles
        // do not cut across the centre of the junction or climb the kerbs.
        const routeCar = buildSmoothRoute(
          [[-18, 0.03, -2.3], [-8, 0.03, -2.3], [0, 0.03, -2.3], [8, 0.03, -2.3], [18, 0.03, -2.3]],
          '#ef4444'
        );

        const routeMoto = buildSmoothRoute(
          [[2.3, 0.03, 18], [2.3, 0.03, 8], [2.3, 0.03, 5], [1.7, 0.03, 3.1], [0, 0.03, 2.3], [-8, 0.03, 2.3], [-18, 0.03, 2.3]],
          '#f59e0b'
        );

        const routeTruck = buildSmoothRoute(
          [[18, 0.03, 2.3], [8, 0.03, 2.3], [5.2, 0.03, 2.3], [3.1, 0.03, 1.7], [2.3, 0.03, 0], [2.3, 0.03, -8], [2.3, 0.03, -18]],
          '#38bdf8'
        );

        const routePriority = buildSmoothRoute(
          [[-2.3, 0.03, -18], [-2.3, 0.03, -8], [-2.3, 0.03, 0], [-2.3, 0.03, 8], [-2.3, 0.03, 18]],
          '#22c55e'
        );

        // 2. Showroom Turntable Stage
        const turntable = new THREE.Group();
        const podium = new THREE.Mesh(
          new THREE.CylinderGeometry(3.8, 4.1, 0.24, 48),
          new THREE.MeshStandardMaterial({ color: '#1e293b', roughness: 0.45, metalness: 0.25 })
        );
        podium.position.y = -0.12;
        podium.receiveShadow = true;
        turntable.add(podium);

        const goldRing = new THREE.Mesh(
          new THREE.RingGeometry(3.5, 3.72, 64),
          new THREE.MeshStandardMaterial({
            color: '#facc15',
            emissive: '#ca8a04',
            emissiveIntensity: 0.55,
            side: THREE.DoubleSide,
          })
        );
        goldRing.rotation.x = -Math.PI / 2;
        goldRing.position.y = 0.015;
        turntable.add(goldRing);
        showroomGroup.add(turntable);

        const makeFallbackVehicle = (colorHex: string, length = 3.2, width = 1.5, height = 1.2) => {
          const root = new THREE.Group();
          const bodyMat = new THREE.MeshStandardMaterial({ color: colorHex, metalness: 0.35, roughness: 0.3 });
          const body = new THREE.Mesh(new THREE.BoxGeometry(length, height * 0.55, width), bodyMat);
          body.position.y = height * 0.42;
          body.castShadow = true;
          root.add(body);

          const cabin = new THREE.Mesh(
            new THREE.BoxGeometry(length * 0.52, height * 0.45, width * 0.86),
            new THREE.MeshStandardMaterial({ color: '#1e293b', metalness: 0.5, roughness: 0.15 })
          );
          cabin.position.set(-length * 0.05, height * 0.85, 0);
          root.add(cabin);

          return { root, wheelList: [] as any[] };
        };

        type RiggedVehicle = {
          root: any;
          wheelList: { pivot: any; spin: any; radius: number; front: boolean; direction?: number }[];
        };

        const intersectionActors: Record<
          'car' | 'moto' | 'truck' | 'ambulance',
          { rig: RiggedVehicle; route: SmoothRoute; order: number; scale: number; headingOffset: number; beacon?: any }
        > = {
          car: {
            rig: makeFallbackVehicle('#dc2626', 3.4, 1.55, 1.3),
            route: routeCar,
            order: 2,
            scale: 0.9,
            // The detailed hatchback asset faces -X; the route runs toward +X.
            headingOffset: Math.PI,
          },
          moto: {
            rig: makeFallbackVehicle('#f59e0b', 1.8, 0.65, 1.05),
            route: routeMoto,
            order: 1,
            scale: 1.05,
            headingOffset: 0,
          },
          truck: {
            rig: makeFallbackVehicle('#0284c7', 5.2, 1.9, 2.2),
            route: routeTruck,
            order: 3,
            scale: 0.72,
            headingOffset: 0,
          },
          ambulance: {
            rig: makeFallbackVehicle('#ffffff', 4.2, 1.75, 1.9),
            route: routePriority,
            order: 0,
            scale: 0.82,
            headingOffset: 0,
          },
        };

        Object.values(intersectionActors).forEach(actor => {
          intersectionGroup.add(actor.rig.root);
        });

        const showroomModels: Partial<Record<VehicleKey, RiggedVehicle>> = {};

        const updateSize = () => {
          if (!host || disposed) return;
          const w = Math.max(host.clientWidth, 280);
          const h = Math.max(host.clientHeight, 220);
          renderer.setSize(w, h, false);
          camera.aspect = w / h;
          camera.updateProjectionMatrix();
        };
        updateSize();
        const ro = new ResizeObserver(updateSize);
        ro.observe(host);

        setWebglReady(true);

        const cloneRigged = (sourceRig: RiggedVehicle): RiggedVehicle => {
          const clonedRoot = sourceRig.root.clone(true);
          const wheelList: RiggedVehicle['wheelList'] = [];
          clonedRoot.traverse((node: any) => {
            if (node.userData?.wheelRig && node.children[0]) {
              wheelList.push({
                pivot: node,
                spin: node.children[0],
                radius: 0.32,
                front: node.position.x > 0,
                direction: 1,
              });
            }
          });
          return { root: clonedRoot, wheelList };
        };

        const replaceIntersectionActor = (
          key: 'car' | 'moto' | 'truck' | 'ambulance',
          loadedRig: RiggedVehicle,
          addBeacon = false
        ) => {
          if (disposed) return;
          intersectionGroup.remove(intersectionActors[key].rig.root);
          const rig = cloneRigged(loadedRig);
          rig.root.scale.setScalar(intersectionActors[key].scale);
          if (addBeacon) {
            const beaconMat = new THREE.MeshStandardMaterial({
              color: '#ef4444',
              emissive: '#ef4444',
              emissiveIntensity: 2,
            });
            const beacon = new THREE.Mesh(new THREE.BoxGeometry(0.45, 0.14, 0.85), beaconMat);
            beacon.position.set(0.6, 2.35, 0);
            rig.root.add(beacon);
            intersectionActors[key].beacon = beaconMat;
          }
          intersectionActors[key].rig = rig;
          intersectionGroup.add(rig.root);
        };

        const registerShowroomModel = (key: VehicleKey, loadedRig: RiggedVehicle) => {
          if (disposed) return;
          const rig = cloneRigged(loadedRig);
          const box = new THREE.Box3().setFromObject(rig.root);
          const size = box.getSize(new THREE.Vector3());
          const center = box.getCenter(new THREE.Vector3());
          const maxDim = Math.max(size.x, size.y, size.z, 1);
          const targetSpan = key === 'moto' ? 2.8 : key === 'car' ? 3.9 : 4.9;
          const s = targetSpan / maxDim;
          rig.root.scale.setScalar(s);
          rig.root.position.set(-center.x * s, -box.min.y * s, -center.z * s);

          const wrapper = new THREE.Group();
          wrapper.add(rig.root);
          wrapper.visible = stateRef.current.activeVehicle === key;
          turntable.add(wrapper);
          showroomModels[key] = { root: wrapper, wheelList: rig.wheelList };
          setLoadedModelsCount(c => c + 1);
        };

        import(/* @vite-ignore */ detailedUrl)
          .then(mod => mod.loadDetailedVehicles())
          .then((detailed: { car: RiggedVehicle; moto: RiggedVehicle }) => {
            if (disposed) return;
            replaceIntersectionActor('car', detailed.car);
            replaceIntersectionActor('moto', detailed.moto);
            registerShowroomModel('car', detailed.car);
            registerShowroomModel('moto', detailed.moto);
          })
          .catch(() => {});

        import(/* @vite-ignore */ fleetUrl)
          .then(async mod => {
            const [truck, ambulance, fire] = await Promise.all([
              mod.loadFleetVehicle('truck'),
              mod.loadFleetVehicle('ambulance'),
              mod.loadFleetVehicle('fire'),
            ]);
            if (disposed) return;
            replaceIntersectionActor('truck', truck);
            replaceIntersectionActor('ambulance', ambulance, true);
            registerShowroomModel('truck', truck);
            registerShowroomModel('ambulance', ambulance);
            registerShowroomModel('fire', fire);
          })
          .catch(() => {});

        let simTime = 0;
        let lastFrame = performance.now();
        let lastMode: SceneMode = stateRef.current.sceneMode;
        let lastPreset: CameraPreset = stateRef.current.cameraPreset;
        let lastVehicle: VehicleKey = stateRef.current.activeVehicle;
        let lastReset = stateRef.current.resetTrigger;

        const applyCameraPreset = (mode: SceneMode, preset: CameraPreset) => {
          if (mode === 'showroom') {
            controls.target.set(0, 0.9, 0);
            camera.position.set(5.2, 2.5, 5.6);
            controls.autoRotate = true;
            controls.autoRotateSpeed = 1.8;
          } else {
            controls.autoRotate = false;
            if (preset === 'overview') {
              controls.target.set(0, 0.5, 0);
              camera.position.set(15.5, 12.2, 16.5);
            } else if (preset === 'driver') {
              controls.target.set(2, 1.0, 1.2);
              camera.position.set(-10.5, 2.5, 3.6);
            } else {
              controls.target.set(0, 0, 0);
              camera.position.set(0.01, 26.5, 3.5);
            }
          }
          controls.update();
        };

        applyCameraPreset(lastMode, lastPreset);

        const animate = (now: number) => {
          if (disposed) return;
          const dt = Math.min((now - lastFrame) / 1000, 0.08);
          lastFrame = now;

          const st = stateRef.current;

          if (st.sceneMode !== lastMode || st.cameraPreset !== lastPreset || st.resetTrigger !== lastReset) {
            lastMode = st.sceneMode;
            lastPreset = st.cameraPreset;
            lastReset = st.resetTrigger;
            intersectionGroup.visible = st.sceneMode === 'intersection';
            showroomGroup.visible = st.sceneMode === 'showroom';
            applyCameraPreset(st.sceneMode, st.cameraPreset);
          }

          if (st.activeVehicle !== lastVehicle) {
            lastVehicle = st.activeVehicle;
            (Object.keys(showroomModels) as VehicleKey[]).forEach(k => {
              const m = showroomModels[k];
              if (m) m.root.visible = k === st.activeVehicle;
            });
          }

          if (!st.paused) {
            const speedFactor = st.signalPhase === 'amber' ? 0.55 : st.signalPhase === 'priority' ? 1.2 : 1.0;
            simTime += dt * speedFactor;
          }

          signalLights.forEach(light => {
            light.green.emissiveIntensity = st.signalPhase === 'green' ? 2.4 : 0.12;
            light.amber.emissiveIntensity = st.signalPhase === 'amber' ? 2.4 : 0.12;
            light.red.emissiveIntensity = st.signalPhase === 'priority' ? 2.4 : 0.12;
          });

          if (st.sceneMode === 'intersection') {
            const movementDuration = 6.4;
            const movementGap = 1.8;
            const movementCycle = (movementDuration + movementGap) * 4;
            (Object.keys(intersectionActors) as ('car' | 'moto' | 'truck' | 'ambulance')[]).forEach(key => {
              const actor = intersectionActors[key];
              const startTime = actor.order * (movementDuration + movementGap);
              const elapsed = simTime - startTime;
              const cycleTime = elapsed < 0 ? -1 : elapsed % movementCycle;
              const u = cycleTime < 0 ? 0 : Math.min(1, cycleTime / movementDuration);
              const { pos, tangent, nextTangent } = actor.route.sampleAt(u);

              actor.rig.root.position.copy(pos);
              const yaw = Math.atan2(-tangent.z, tangent.x) + actor.headingOffset;
              actor.rig.root.rotation.set(0, yaw, 0);

              const steerDelta = Math.atan2(
                tangent.x * nextTangent.z - tangent.z * nextTangent.x,
                tangent.x * nextTangent.x + tangent.z * nextTangent.z
              );

              const distanceTravelled = u * actor.route.totalLength;
              actor.rig.wheelList.forEach(w => {
                const spinDir = w.direction ?? 1;
                w.spin.rotation.z = -spinDir * (distanceTravelled / Math.max(w.radius, 0.25));
                if (w.front) {
                  w.pivot.rotation.y = Math.max(-0.45, Math.min(0.45, -steerDelta * 4.5));
                }
              });

              if (actor.beacon) {
                const pulse = Math.sin(now * 0.014) > 0;
                actor.beacon.color.set(pulse ? '#ef4444' : '#3b82f6');
                actor.beacon.emissive.set(pulse ? '#ef4444' : '#3b82f6');
              }
            });
          } else {
            controls.autoRotate = !st.paused;
            const currentShowroom = showroomModels[st.activeVehicle];
            if (currentShowroom) {
              (Object.keys(showroomModels) as VehicleKey[]).forEach(k => {
                const m = showroomModels[k];
                if (m) m.root.visible = k === st.activeVehicle;
              });
              if (!st.paused) {
                currentShowroom.wheelList.forEach(w => {
                  const spinDir = w.direction ?? 1;
                  w.spin.rotation.z -= spinDir * dt * 3.2;
                });
              }
            }
          }

          controls.update();
          renderer.render(scene, camera);
          animationFrameId = requestAnimationFrame(animate);
        };

        animationFrameId = requestAnimationFrame(animate);

        cleanupFn = () => {
          ro.disconnect();
          controls.dispose();
          renderer.dispose();
        };
      } catch {
        setWebglReady(false);
      }
    }

    void initThreeScene();

    return () => {
      disposed = true;
      cancelAnimationFrame(animationFrameId);
      cleanupFn?.();
    };
  }, []);

  const currentSpec = VEHICLE_SPECS[activeVehicle];

  return (
    <div className={`traffic-scene-studio ${variant === 'compact' ? 'is-compact' : ''} ${paused ? 'is-paused' : ''}`}>
      <div className="ts-header-bar">
        <div className="ts-mode-tabs" role="tablist" aria-label="Chế độ mô phỏng 3D">
          <button
            type="button"
            role="tab"
            aria-selected={sceneMode === 'intersection'}
            className={`ts-mode-btn ${sceneMode === 'intersection' ? 'active' : ''}`}
            onClick={() => setSceneMode('intersection')}
          >
            <Layers size={14} /> Sa hình Ngã tư 3D
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={sceneMode === 'showroom'}
            className={`ts-mode-btn ${sceneMode === 'showroom' ? 'active' : ''}`}
            onClick={() => setSceneMode('showroom')}
          >
            <Box size={14} /> Model Xe 3D (360°)
          </button>
        </div>

        <div className="ts-header-right">
          <span className="ts-live-pill">
            <span className={`ts-led-dot phase-${signalPhase}`} />
            {loadedModelsCount > 0 ? `${loadedModelsCount} Model GLB 3D` : '3D WebGL Live'}
          </span>
          <button
            type="button"
            className="ts-action-chip"
            onClick={() => setOpenSaHinhModal('q490')}
            title="Mở mô phỏng Sa hình 3D Câu 490 toàn màn hình"
          >
            <Expand size={13} /> Sa hình Câu 490
          </button>
        </div>
      </div>

      <div ref={hostRef} className="ts-viewport">
        <canvas
          ref={canvasRef}
          className="ts-webgl-canvas"
          aria-label="Mô hình giao thông 3D tương tác: kéo chuột để xoay 360 độ, cuộn để phóng to"
        />

        {!webglReady && (
          <div className="ts-fallback-overlay" aria-hidden="true">
            <Sparkles size={20} /> Đang khởi tạo không gian 3D &amp; Model GLB…
          </div>
        )}

        {sceneMode === 'intersection' ? (
          <div className="ts-floating-controls">
            <div className="ts-chip-group" role="group" aria-label="Góc máy 3D">
              <button
                type="button"
                className={cameraPreset === 'overview' ? 'active' : ''}
                onClick={() => setCameraPreset('overview')}
              >
                <Camera size={12} /> Toàn cảnh 3D
              </button>
              <button
                type="button"
                className={cameraPreset === 'driver' ? 'active' : ''}
                onClick={() => setCameraPreset('driver')}
              >
                <Compass size={12} /> Góc người lái
              </button>
              <button
                type="button"
                className={cameraPreset === 'topdown' ? 'active' : ''}
                onClick={() => setCameraPreset('topdown')}
              >
                Sa hình trên cao
              </button>
            </div>

            <div className="ts-signal-switcher" role="group" aria-label="Tín hiệu đèn giao thông">
              <button
                type="button"
                className={`sig-btn green ${signalPhase === 'green' ? 'active' : ''}`}
                onClick={() => setSignalPhase('green')}
                title="Đèn xanh: lưu thông bình thường"
              >
                <i /> Xanh
              </button>
              <button
                type="button"
                className={`sig-btn amber ${signalPhase === 'amber' ? 'active' : ''}`}
                onClick={() => setSignalPhase('amber')}
                title="Đèn vàng: giảm tốc độ chú ý quan sát"
              >
                <i /> Vàng
              </button>
              <button
                type="button"
                className={`sig-btn red ${signalPhase === 'priority' ? 'active' : ''}`}
                onClick={() => setSignalPhase('priority')}
                title="Tình huống xe ưu tiên qua giao lộ"
              >
                <i /> Ưu tiên
              </button>
            </div>
          </div>
        ) : (
          <div className="ts-floating-controls">
            <div className="ts-chip-group" role="group" aria-label="Chọn model xe 3D">
              {(Object.keys(VEHICLE_SPECS) as VehicleKey[]).map(vKey => (
                <button
                  key={vKey}
                  type="button"
                  className={activeVehicle === vKey ? 'active' : ''}
                  onClick={() => setActiveVehicle(vKey)}
                >
                  {VEHICLE_SPECS[vKey].label}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="ts-hud-bar">
          {sceneMode === 'intersection' ? (
            <div className="ts-hud-info">
              <span className="ts-hud-badge">
                <TrafficCone size={13} /> QUỸ ĐẠO QUA GIAO LỘ 3D
              </span>
              <strong>Lần lượt: Xe ưu tiên → Mô tô → Ô tô → Xe tải</strong>
              <small>Mỗi phương tiện qua nút giao theo lượt để dễ quan sát quỹ đạo</small>
            </div>
          ) : (
            <div className="ts-hud-info">
              <span className="ts-hud-badge" style={{ borderColor: currentSpec.color }}>
                <ShieldCheck size={13} /> {currentSpec.license} · {currentSpec.badge}
              </span>
              <strong>{currentSpec.label}</strong>
              <small>{currentSpec.rule}</small>
            </div>
          )}

          <div className="ts-hud-actions">
            <button
              type="button"
              className="ts-icon-btn"
              aria-label="Đặt lại góc nhìn 3D ban đầu"
              title="Đặt lại góc nhìn 3D"
              onClick={() => {
                stateRef.current.resetTrigger += 1;
                setCameraPreset(p => p);
              }}
            >
              <RotateCcw size={14} />
            </button>
            <button
              type="button"
              className="ts-icon-btn scene-motion"
              aria-label={paused ? 'Bật chuyển động minh họa' : 'Tạm dừng chuyển động minh họa'}
              aria-pressed={paused}
              onClick={() => setPaused(value => !value)}
            >
              {paused ? <Play size={14} /> : <Pause size={14} />}
            </button>
          </div>
        </div>
      </div>

      {openSaHinhModal && (
        <Modal
          className="exam-modal-backdrop"
          label="Mô phỏng Sa hình 3D & Model Xe"
          onClose={() => setOpenSaHinhModal(null)}
        >
          <div className="ts-modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="ts-modal-header">
              <div>
                <span className="eyebrow">MÔ PHỎNG SA HÌNH 3D &amp; MODEL PHƯƠNG TIỆN</span>
                <h2>
                  {openSaHinhModal === 'q490'
                    ? 'Sa hình 3D Câu 490 · Quỹ đạo bánh xe & Thứ tự qua giao lộ'
                    : 'Phòng trưng bày Model Xe 3D cận cảnh'}
                </h2>
              </div>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <button
                  type="button"
                  className={openSaHinhModal === 'q490' ? 'btn-primary' : 'btn-secondary'}
                  style={{ padding: '7px 12px', fontSize: '12.5px' }}
                  onClick={() => setOpenSaHinhModal('q490')}
                >
                  Sa hình 3D Câu 490
                </button>
                <button
                  type="button"
                  className={openSaHinhModal === 'models' ? 'btn-primary' : 'btn-secondary'}
                  style={{ padding: '7px 12px', fontSize: '12.5px' }}
                  onClick={() => setOpenSaHinhModal('models')}
                >
                  Soi cận cảnh Model 3D
                </button>
                <button
                  type="button"
                  className="icon-button"
                  aria-label="Đóng cửa sổ 3D"
                  onClick={() => setOpenSaHinhModal(null)}
                >
                  <X size={18} />
                </button>
              </div>
            </div>
            <iframe
              className="ts-modal-iframe"
              title="Mô phỏng 3D Sa hình Giao thông"
              src={openSaHinhModal === 'q490' ? '/c2-3d/demo-q490-3d.html' : '/c2-3d/models.html'}
            />
          </div>
        </Modal>
      )}
    </div>
  );
}
