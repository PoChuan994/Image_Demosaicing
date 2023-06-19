# Image_Demosaicing

This project is used to reconstruct a full-color image from a single sensor that captures only a portion of the color information at each pixel location.
Bilinear interpolation is used in this project.

Data summary of gate-level simulation (by Quartus)
- Device: EP4CE55F23A7
- Total logic element: 282/55856(<1%)
- Total registers: 125
- Total pins 105/325(32%)
- Total virtual pins: 0
- Total memory bits: 0/2396160(%)

  File description
  - demosaic.v: This file is used to reconstruct full-color image.
  - testfixture.v: This file is used to convert data calculated by demosaic.v file into .raw file.
  - democsaic.vo/democsaic_v.sdo: These files are converted from demosaic.v by Quartus
