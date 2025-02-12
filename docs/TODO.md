# TODOs

List of ToDo's for SignedMCRT.

## Additional Features
### Finished Features
- [x] Make CI run tests
- [x] Add Code Coverage reports
- [x] Remove spurious implicit nones
- [x] Make sure all optical properties are the same for a model instance (SDF)
### Minor Features
- [ ] Add more saved state to photon_origin to save compute time
- [ ] Finish Circular, focus, and annulus source types
    - [ ] Circular
    - [ ] Focus
    - [x] Annulus. Partially done via control of Beta parameter. 
- [ ] Add Direction component to rest of Detectors
    - [x] Circle
    - [x] Camera
    - [ ] Annulus
- [ ] Add photon trajectory history tracking
    - [ ] Fix openMP troubles
    - [ ] Fix speed issues
- [ ] Add "Scattering" kernels
    - [x] path length counter method
    - [ ] Weight method
- [ ] Add phase tracking. To be done by Masters Student?
### Major Features
- [ ] Make code work on Windows
- [ ] Automate benchmarking so we can catch performance regressions
- [ ] Add voxel geometry
- [ ] Add mesh geometry
- [ ] Improve performance of SDF intersection
    - [ ] Implement KD trees in 2D
    - [ ] Implement KD trees in 3D
- [ ] Make code serializable so that we can checkpoint simulations
     - [ ] Save input toml file
     - [ ] photons run
     - [ ] Save output data
        - [ ] Detectors
        - [ ] Fluence
        - [ ] Absorb
        - [ ] NScatt
- [ ] Add optics to Camera type

## Testing

- [x] Vec3 class
- [x] Matrix class
- [x] Vec4 Class
- [ ] SDF Class
- [ ] Detector Class
    - [ ] Circle
    - [ ] Camera
    - [ ] Annulus
- [ ] Photon class
    - [x] Uniform
    - [x] Point
    - [x] Pencil
    - [ ] Circular
    - [ ] Annulus
    - [ ] Scattering
     - [ ] Isotropic
     - [ ] Henyey-Greenstein
     - [ ] Importance sampling biased scattering
- [ ] Photon movement code
- [ ] History Stack Class
- [ ] I/O
- [ ] Random Numbers
- [x] Fresnel reflections
    - [x] Simple reflect
    - [x] Simple refract
    - [x] Complex reflect
    - [x] Complex refract
- [ ] End to End tests
    - [x] Scattering Test
    - [ ] Others

## Bugs
- [ ] Fix CI so that build on Macos run, and builds using Intel run.
    - [ ] Macos
    - [ ] Intel
- [ ] Can't operate trackHistory in parallel
    - [ ] Make each thread write to tmp file and finish method collate results