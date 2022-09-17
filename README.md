# PointPillars in UnityCG

<img src="https://i.imgur.com/JG3ICV4.png" align="middle"/>

### NOTE: This was built and tested with Unity 2019.4.32f1 using built-in render pipeline, there may be shader compatibility issues with other versions.

## Table of Contents
- [Overview](#overview)
- [Problems](#problems)
- [Setup](#setup)
- [C++ Code](#c-code)
- [Model Architecture](#model-architecture)
- [GPU Implementation](#gpu-implementation)
- [Resources](#resources)
- [Datasets](#datasets)

## Overview

Simple implementation of [PointPillars: Fast Encoders for Object Detection from Point Clouds](https://arxiv.org/abs/1812.05784) in Unity for VRChat using just fragment and geometry shaders without any additional dependencies. This is more of an educational tool than a practical implementation. This implementation takes ~40 frames to compute a single frame of input while running at ~20 FPS. The original runs around ~60 FPS in PyTorch.

## Problems

Slow computations aside, actual lidar data also returns a reflectance value. One of the key features used by the network during classification.

<img src="https://i.imgur.com/7R79oj7.png" align="middle" width="500"/>

The table above was directly lifted from the PointPillars paper. It shows how reflectance raised the average precision from the base XYZ location information. This implementation supports reflectance, however, I modified it to a constant value of 0.15 because there is no easy way to estimate reflectance without extra information.

## Setup

1. Either clone the repo or download from [Release](https://github.com/SCRN-VRC/Point-Pillars-in-UnityCG/releases).
2. Drag and drop the prefab in the `Prefabs` folder into the scene. Or open up the scene that came with the package.
3. Run the network in Playmode.

The network outputs up to 100 predictions, only 33 of the bounding boxes are shown. Invalid predictions are returned as -1. All 100 predictions are rendered into `PointPillars\RenderTextures\Output3.renderTexture`. You can read it in a shader by importing the .cginc `PointPillars\Shaders\PointPillarsInclude.cginc`

#### Shader properties:
```C
    Properties
    {
        _ControllerTex ("Controller", 2D) = "black" {}
        _DataTex ("Data Texture", 2D) = "black"
    }
```
`PPControllerBuffer.renderTexture` goes into _ControllerTex, `Output3.renderTexture` goes into _DataTex. `PPControllerBuffer.renderTexture` contains a count of all predictions.

#### Includes:
```C
#include "PointPillarsInclude.cginc"
```

#### Functions:
```C
int count = getCount(_ControllerTex);
float4 sizeRot = getPredictionSizeRotation(_DataTex, id);
float3 pos = getPredictionPosition(_DataTex, id);
```
`id` is the index going from 0 to 99. An example of how to draw the bounding boxes with the following functions is in `PointPillars\Display\BBoxes\BBoxDraw.shader`.


## C++ Code
The C++ code included with the repo is just an exact CPU clone of how PointPillars would run on the GPU. No additional dependency is required to compile but it runs very slowly.

## Model Architecture
<img src="https://i.imgur.com/zSKsDQI.png" align="middle"/>

Figure from the original PointPillars paper. The network begins by voxelizing the lidar data into a 2D grid without bounding Z. Hence the name "pillars". This serves to condense the data into a dense matrix. Then it's fed into a classic 2D CNN classifier as the backbone, and ending with a single shot detector network structure, like YOLOv4.

## GPU Implementation
<img src="https://i.imgur.com/mnNYfS8.png" align="middle" width="500"/>

The GPU implementation for VRChat consists of 40+ cameras rendering to about 1GB of render textures. Moving points into pillar voxels required using a bitonic merge sort and d4rk's compact sparse texture code. One million particles were used in a geometry shader to scatter extracted features into the dense matrix for the 2D CNN.

PointPillars spits out 321408 predictions towards the end. But because most of the outputs are 0, they can be filtered with d4rk's compact sparse texture method into a 32x32 render texture and sorted again.

## Resources
- [PointPillars: Fast Encoders for Object Detection from Point Clouds](https://arxiv.org/abs/1812.05784)
- [A Simple PointPillars PyTorch Implenmentation](https://github.com/zhulf0804/PointPillars)
- [Compact Sparse Texture Demo](https://github.com/d4rkc0d3r/CompactSparseTextureDemo)
- [Bitonic Merge Sort](https://en.wikipedia.org/wiki/Bitonic_sorter)
- [Quaternius Lowpoly Assets](https://www.patreon.com/posts/tutorials-on-all-61128248)

## Datasets
- [KITTI 3D Object Detection Evaluation 2017](https://www.cvlibs.net/datasets/kitti/eval_object.php?obj_benchmark=3d)

Thanks to [d4rkpl4y3r](https://github.com/d4rkc0d3r/) for the Compact Sparse Texture Demo that made this possible.

If you have questions or comments, you can reach me on Discord: SCRN#8008 or Twitter: https://twitter.com/SCRNinVR