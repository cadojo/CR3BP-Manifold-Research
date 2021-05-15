# Halo-Explorations

## Overview

This repository includes [reports](papers), [notebooks](notebooks), and [data](data) relevant to astrodynamics. Specifically, this project outlines Halo orbit solvers and manifold transfer calculations, and provides a [large collection](data/exp_pro/halos) of numerically periodic Halo orbits for common CR3BP systems in our solar system. This repository also includes notebooks and papers that describe Halo orbit solvers and manifold transfer calculations in more detail. The primary source for this project is [Rund's Masters Thesis](https://digitalcommons.calpoly.edu/theses/1853/)
at Cal Poly. 

In short, this repository contains:
* Over 130,000 numerically periodic [Halo orbits](data/exp_pro/halos) in our solar system
* A [Pluto notebook](notebooks/halo-solvers/Halo-Orbit-Solvers.pdf) that outlines Halo orbit solvers, and why they're useful
* A [paper](papers/halo-solvers/Carpinelli_Halo_Solvers.pdf) that describes Halo orbit solvers in more detail.
* A [Pluto notebook](notebooks/manifold-transfers/Manifolds.jl) that outlines invariant manifolds, and their applications in low-cost interplanetary transfer designs
* A [paper](papers/manifold-transfers/Carpinelli_Manifold_Transfers.pdf) that describes manifold transfer calcualtions in more detail

## Open Source Licenses

All works in this repository are licensed under the Unlicense Open Source license (that is, they are free and available within public domain) with __one__ exception: all papers under the `papers` directory are licensed with the permissive MIT license. 

## Background
Halo orbits are theoretically perfectly periodic orbits about equilibrium positions (a.k.a. 
[Lagrange points](https://en.wikipedia.org/wiki/Lagrange_point))
within the Circular Restricted Three-body Problem. All Halo Orbits are surrounded by 
stable and unstable manifolds. These manifolds can be used to carry a spacecraft closer
to a desired destination without spending fuel. As [Rund](https://digitalcommons.calpoly.edu/theses/1853/)
shows, this can be used to drastically lower the fuel costs required for interplanetary trajectories. 
Some colorful examples are shown directly below!

![Screen Shot 2021-04-18 at 8 42 10 PM](https://user-images.githubusercontent.com/12131808/115731173-ec2ec300-a354-11eb-853c-39561ee58f0f.jpeg)



![Screen Shot 2021-04-14 at 8 44 36 PM](https://user-images.githubusercontent.com/12131808/115730710-88a49580-a354-11eb-9c01-2e99d502f24f.png)


## Reproducability

This codebase uses the Julia Programming Language and [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/). As a result, this repository is entirely reproducable!

To (locally) reproduce this project, do the following:

1. Download this codebase. Note that raw data is _typically_ not included in the
   git-history and _may_ need to be re-created with included [scripts](scripts).
2. Open a Julia REPL and enter:

   ```julia
   julia> using Pkg
   julia> Pkg.activate("path/to/this/project")
   julia> Pkg.instantiate()
   ```


