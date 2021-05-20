### A Pluto.jl notebook ###
# v0.14.5

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ a9092c8c-b3b2-4608-99c3-8cc73d7816f3
begin
	
	using DrWatson
	
	using Plots
	using Revise
	using PlutoUI
	using Latexify
	using Rotations
	using Statistics
	using DataFrames
	using StaticArrays
	using LaTeXStrings
	using LinearAlgebra
	using BlackBoxOptim
	using GalacticOptim
	using ConcreteStructs
	using NearestNeighbors
	using GeneralAstrodynamics
	using DifferentialEquations
	using Unitful, UnitfulAngles, UnitfulAstro

	macro terminal(expr)
		quote
			with_terminal() do 
				$(esc(expr))
			end
		end
	end
	
end;

# ╔═╡ d59d8616-a224-11eb-043c-d1f9fbaa616e
md"""
# Study: Interplanetary Superhighways
_🎢 Going to Jupiter with Julia, Halo orbits, and invariant manifolds._

__May $\mathbf{2021}$__ $(html"<br>")
__Joe Carpinelli__ $(html"<br>")

$(PlutoUI.TableOfContents(; title = "📚 Table of Contents", depth = 2))
$(html"<button onclick=present()>Toggle Presentation</button>")

"""

# ╔═╡ af8b6ac7-7391-4662-adec-01ca03d94a30
md"""
## Study Overview

### Mission Constraints
_Travel as cheap as possible._

* Travel from Earth, to Jupiter
* Requires a periodic, or semi-periodic destination orbit
* Mission is robotic – duration has __no upper bound__
* We want to use as __little fuel as possible__


* __Transfers along invariant manifolds within CR3BP are great options for these constraints!__
* An artist's interpretation of invariant manifolds in space is featured on [NASA's website](https://www.nasa.gov/mission_pages/genesis/media/jpl-release-071702.html), and is shown below
"""

# ╔═╡ 684c3b78-a47c-4fba-9a80-e6a07bc5e799
html"""
<figure>
<img src="https://www.nasa.gov/images/content/63114main_highway_med.jpg" alt="Invariant Manifolds in Space" style="display: block; margin-left: auto; margin-right: auto; width: 80%; border-radius: 5%; ">
</figure>

"""

# ╔═╡ afa41959-dbee-4e81-97a6-1717f476dd77
md"""
## Recall Lagrange Points
_The equilibrium points of CR3BP dynamics._

* Like any equilibrium points, they can be __stable__ or __unstable__
* We can verify the stability by looking at the __eigenvalues__ of the linearized CR3BP dynamics __at__ each Lagrange point

"""

# ╔═╡ 267edd09-82ea-4cf9-92e8-f871ac4f0f5c
md"""

__System:__ $(@bind lagrange_plot_sys PlutoUI.Select([
	"Earth-Moon" => "Earth-Moon",
	"Sun-Earth" => "Sun-Earth",
	"Sun-Mars" => "Sun-Mars",
	"Sun-Jupiter" => "Sun-Jupiter"
])) 

"""

# ╔═╡ 46d550bc-713e-43af-8b2e-8ffa65d0e600
let 
	
	if lagrange_plot_sys == "Earth-Moon"
		sys = EarthMoon
	elseif lagrange_plot_sys == "Sun-Earth"
		sys = SunEarth
	elseif lagrange_plot_sys == "Sun-Mars"
		sys = SunMars
	else
		sys = SunJupiter
	end
	
	# Plot lagrange points
	figure = lagrangeplot(sys)
	
	# Plot centers of mass
	plotbodies!(figure, sys; legend = :topright)
	
end

# ╔═╡ 3813dffe-54fb-48a1-a5fb-9a6c81ed1ad7
md"""
## Periodic Orbits within CR3BP
_Classifications don't really matter for this study!_
### Classifications
* __Lyapunov Orbits__ are periodic with $z \equiv 0$
* __Halo Orbits__ are periodic with $z \not\equiv 0$


"""

# ╔═╡ 50ee947b-7df3-4de6-9223-08bc1bd9398d
let

	options = (; reltol = 1e-16, abstol = 1e-16)
	Lyapunov  = propagate(halo(EarthMoon; Az = 0, L = 1)...; options...)
	Halo      = propagate(halo(EarthMoon; Az = 5_000u"km", L = 1)...; options...)
	
	fig = plotpositions(Lyapunov; title="Periodic CR3BP Orbits", 
						label="Lyapunov Orbit")
	plotpositions!(fig, Halo; label = "Halo Orbit")
	
end

# ╔═╡ 0e8c29c8-32d0-4b2b-aa20-e947cf36389c
md"""
## Analytical Halo Approximation
_As described in detail by Koon et al._

Richardson approximated CR3BP dynamics with a __third-order expansion__:

$\begin{align}
\ddot{x} - 2\dot{y} - (1 + 2c_2)x &= \frac{3}{2}c_3(2x^2-y^2-z^2) + 2c_4x(2x^2-3y^2-3z^2) + O(4) \\
\ddot{y}+2\dot{x}+(c_2-1)y &= -3c_3 x y - \frac{3}{2}c_4 y(4x^2-y^2-z^2) + O(4) \\
\ddot{z} + c_2z &= -3c_3 x z - \frac{3}{2}c_4 z(4x^2-y^2-z^2) + O(4)
\end{align}$

We can use the following facts to find a unique, periodic solution to this third-order expansion:
1. Nonlinearities affect the __frequency__ of the linearization (Lindstedt-Poincaré Method)
2. The amplitudes of the linearization solution produce __equal__ eigen-frequencies
3. The $X$, $Y$, and $Z$ amplitudes are __related__ and __unique__

__The analytical algorithm can return the orbital period, positions, and velocities.__

"""

# ╔═╡ de2eb7a9-3d36-42c0-b12a-f7f2303692f3
@terminal let μ = normalized_mass_parameter(EarthMoon)
	println("julia> μ = $μ")
	println("julia> analyticalhalo(μ; Az = 0.03, L = 1, steps = 1)\n")
	r, v, T = analyticalhalo(μ; Az = 0.03, L = 1, steps = 1)

	@show r
	@show v
	@show T
end

# ╔═╡ 272d58f1-4d59-4243-8de3-326b02d4628a
md"""
## Propagating Analytical Solutions
_It doesn't work!_

!!! note
	Remember, we used a __third-order expansion__ of the CR3BP dynamics. As a result, our analytical halo solutions are __approximations__!

__Include Propagation:__ $(@bind plot_analytical_propagation PlutoUI.CheckBox())

"""

# ╔═╡ 72492b56-30f3-44ad-81ff-1b59fced5d47
let 
	μ  = normalized_mass_parameter(EarthMoon)
	LU = string(normalized_length_unit(EarthMoon))
	
	# Analytical trajectory
	r, v, T = analyticalhalo(μ; Az = 0.0399, steps=1000, L=1)
		
	# Analytical trajectory plot
	fig = plotpositions(collect(eachrow(r)); 
						title  = "Halo Orbits about Earth-Moon L1", 
						label  = "Analytical Solution",
						xlabel = "X ($LU)", 
						ylabel = "Y ($LU)", 
						zlabel = "Z ($LU)")
	
	# Propagate the analytical solution!
	options = (; reltol = 1e-16, abstol = 1e-16)
	rₙ = position_vector.(propagate(CR3BPOrbit(r[1,:], v[1,:], μ), T; options...))
	
	# Propagated trajectory plot
	if plot_analytical_propagation
		plotpositions!(fig, rₙ; linewidth = 2, label = "Numerical Propagation")
	end
	
	fig
end

# ╔═╡ c761130f-88e5-4375-abba-9b196c9b0a27
md"""
## Numerical Halo Solver
_AKA a differential corrector!_

Recall the __differential correction algorithm__ introduced in ENAE$601$.

1. Start with a Halo guess of the form $r_0 = \begin{bmatrix} x_0 & 0 & z_0 \end{bmatrix},\ v_0 = \begin{bmatrix} 0 & \dot{y}_0 & 0 \end{bmatrix},\ T_0$
2. Propagate the solution for __half a period__ (until $y$ crosses the $x-z$ plane again)
3. Use a __differential correction__${}^\star$ to form a new Halo guess
4. Repeat until your half-period $\dot{x}_0$ and $\dot{z}_0$ values are within some acceptable tolerance of $0$

Literature shows __two__${}^\star$ acceptable differential correction calculations, with $\Phi$ representing the Jacobian of the Cartesian state at the half-period.

$\begin{bmatrix} z_0 \\  \dot{y}_0 \\ \frac{T_0}{2} \end{bmatrix} ⟽\begin{bmatrix} x_0 \\ \dot{y}_0 \\ \frac{T_0}{2} \end{bmatrix} - \text{inv}\left( \begin{bmatrix}
	\Phi_{1,4} & \Phi_{5,4} & \ddot{x} \\
	\Phi_{1,6} & \Phi_{5,6} & \ddot{z} \\
	\Phi_{1,2} & \Phi_{5,2} & \dot{y}
\end{bmatrix}\right) \begin{bmatrix} \dot{x} \\ \dot{y} \\ y \end{bmatrix} \tag{1}$

$\begin{bmatrix} x_0 \\  \dot{y}_0 \\ \frac{T_0}{2} \end{bmatrix} ⟽\begin{bmatrix} z_0 \\ \dot{y}_0 \\ \frac{T_0}{2} \end{bmatrix} - \text{inv}\left( \begin{bmatrix}
	\Phi_{3,4} & \Phi_{5,4} & \ddot{x} \\
	\Phi_{3,6} & \Phi_{5,6} & \ddot{z} \\
	\Phi_{3,2} & \Phi_{5,2} & \dot{y}
\end{bmatrix}\right) \begin{bmatrix} \dot{x} \\ \dot{y} \\ y \end{bmatrix} \tag{2}$

!!! tip
	You can't just _choose_ whatever corrector you want! If you're solving for a Lyapunov orbit $\left(z \equiv 0\right)$ then the $3\times3$ matrix will be singular (second row) if you choose equation $\left(1\right)$. In practive, I've learned to use a switch statement – if your desired $z$-axis ampltitude is $0$, then use $\left(2\right)$, and otherwise use $\left(1\right)$.
"""

# ╔═╡ dd9efeb6-359a-428b-b2be-93f7a3735734
md"""
## Propagating Numerical Solutions
_This ~does~ work!_

We can __combine__ the working analytical and numerical solvers to form one ergonomic halo solver!

$\text{Desired Attributes} \rightarrow \boxed{\text{Analytical}} \rightarrow \boxed{\text{Numerical}} \rightarrow \text{Halo Orbit}$

"""

# ╔═╡ 507a6e8c-52e2-4223-befc-82ad631af446
md"""
### 🥁 Halo Orbit Attributes

__System:__ $(@bind halo_attr_sys PlutoUI.Select([
	"Earth-Moon" => "Earth-Moon",
	"Sun-Earth" => "Sun-Earth",
	"Sun-Mars" => "Sun-Mars",
	"Sun-Jupiter" => "Sun-Jupiter"
])) 
   __Lagrange Point:__ $(@bind halo_attr_lagrange PlutoUI.Select([
	"1" => "1", 
	"2" => "2"
]))
__Z-axis Amplitude:__ $(@bind halo_attr_amp PlutoUI.NumberField(0.0:0.0001:0.05; default = 0.005))
"""

# ╔═╡ 2319c22e-4417-4c0a-9b0b-b951a8bf58f4
let 
	if halo_attr_sys == "Earth-Moon"
		sys = EarthMoon
	elseif halo_attr_sys == "Sun-Earth"
		sys = SunEarth
	elseif halo_attr_sys == "Sun-Mars"
		sys = SunMars
	else
		sys = SunJupiter
	end
	
	μ  = normalized_mass_parameter(sys)
	LU = (string ∘ normalized_length_unit)(sys)
	Az = halo_attr_amp
	L  = parse(Int, halo_attr_lagrange)
	
	rₐ, vₐ, Tₐ = analyticalhalo(μ; Az = Az, L = L, steps = 1000)
	
	fig = plotpositions((collect ∘ eachrow)(rₐ); 
						title  = "Halo Orbit about $(sys.name) L$L",
						label  = "Analytical Solution",
						xlabel = "X ($LU)", 
						ylabel = "Y ($LU)", 
						zlabel = "Z ($LU)",
						dpi    = 200)

	options = (; reltol = 1e-16, abstol = 1e-16)
	traj = propagate(halo(EarthMoon; Az = Az, L = L)...; options...)
	
	plotpositions!(fig, traj; label = "Numerical Solution")
		
	fig
end

# ╔═╡ b489caad-6f05-4e1f-88a9-3c008e4ba98c
md"""
## Halo Orbit Families
_Variations in Z-axis amplitude._
* A Halo orbit _family_ is a collection of Halos with varying Z-axis amplitudes
* A collection of over $130,000$ Halo orbits in our solar system is available on GitHub [here](https://github.com/cadojo/Halo-Explorations/blob/main/data/exp_pro/halos/)!
"""

# ╔═╡ a4538dea-2e55-42c6-8573-e77c75607e7c
md"""
### Halo Family Attributes

__System:__ $(@bind family_attr_sys PlutoUI.Select([
	"Earth-Moon" => "Earth-Moon",
	"Sun-Earth" => "Sun-Earth",
	"Sun-Mars" => "Sun-Mars",
	"Sun-Jupiter" => "Sun-Jupiter"
])) 
   __Lagrange Point:__ $(@bind family_attr_lagrange PlutoUI.Select([
	"1" => "1", 
	"2" => "2"
]; default = "2"))

"""

# ╔═╡ fb847908-ee98-447e-ae03-23afd0b9d9e4
let 
	if family_attr_sys == "Earth-Moon"
		sys = EarthMoon
	elseif family_attr_sys == "Sun-Earth"
		sys = SunEarth
	elseif family_attr_sys == "Sun-Mars"
		sys = SunMars
	else
		sys = SunJupiter
	end
	
	μ   = normalized_mass_parameter(sys)
	LU  = (string ∘ normalized_length_unit)(sys)
	AZ  = [i * 1e-4 for i ∈ 1:4:100]
	L   = parse(Int, family_attr_lagrange)
	fig = plot()
	
	for Az ∈ AZ

		options = (; reltol = 1e-14, abstol = 1e-14)
		traj = propagate(halo(EarthMoon; Az = Az, L = L)...; options...)

		plotpositions!(fig, traj; 
					   label   = :none,
					   title   = "Halo Orbits about $(sys.name) L$L",
					   xlabel  = "X ($LU)", 
					   ylabel  = "Y ($LU)", 
					   zlabel  = "Z ($LU)",
					   dpi     = 200,
					   palette = :tab10)
	end
	
	savefig(fig, joinpath(plotsdir(), "halo_family_sj1.png"))
	
	fig
end

# ╔═╡ 8786e7d8-9d78-4b7c-bd19-d221a471a32a
md"""
## Manifolds Overview
_Superhighways in ~space~._

* Manifolds are __collections of trajectories__ that __converge to__ or __diverge from__ a periodic orbit or Lagrange point
* They are visualized by plotting trajectories _near_ a Lagrange point, or a periodic CR3BP orbit
"""

# ╔═╡ c850a977-9fab-4014-8887-6667e64e079a
let system = EarthMoon
	
	orbit, T = halo(system; Az = 0.03, L = 1)
	manifold = unstable_manifold(orbit, T; eps=1e-8, duration=3.3T, saveat=1e-2)
	
	LU  = string(normalized_length_unit(orbit.system))
	fig = plot(; palette = :rainbow, dpi = 200,
				 label  = "Halo Orbit", 
				 xlabel = "X ($LU)", ylabel = "Y ($LU)", zlabel = "Z ($LU)",
				 title  = "Unstable Manifold near $(system.name) L1")
	
	for trajectory ∈ manifold
		
		plotpositions!(fig, trajectory; linestyle = :dot, label = :none)
		
	end
		
	
	plotpositions!(fig, propagate(orbit, T); 
				   linewidth = 4, color = :black,
				   label = "Halo Orbit")
	
	fig
	
end

# ╔═╡ bd964ca0-534b-46b8-8538-d582186c1f94
md"""
## Mission Phases
_Manifold-based interplanetary missions are a $3$ step process._

1. Launch from Earth into a __stable manifold__ within the Sun-Earth system
2. Perturb from the Sun-Earth Halo onto an __unstable manifold__
3. Transfer onto a __stable manifold__ of the desired destination Halo orbit

__Mission Phase:__ $(@bind mission_phase PlutoUI.Select([
	"Phase One" => "Phase One",
	"Phase Two" => "Phase Two",
	"Phase Three" => "Phase Three"
])) 

"""

# ╔═╡ 88d150e7-609c-4a5f-a0fc-48cbae74b10b
let

	if mission_phase == "Phase One"
		
		orbit, T = halo(SunEarth; Az=100_000u"km", L=2)
		manifold = stable_manifold(orbit, T; duration=1.5T, eps=-1e-9, saveat=1e-2)
		
		LU  = (string ∘ normalized_length_unit)(orbit.system)
		fig = plot(; title = "Phase #1: Earth to Sun-Earth Halo", 
			   		 xlabel = "X ($LU)", ylabel = "Y ($LU)",
					 dpi = 250, legend = :topright)
		
		scatter!(fig, map(el->[el], secondary_synodic_position(orbit)[1:2])...; 
				 label = "Earth")
		
		scatter!(fig, map(el->[el], lagrange(SunEarth, 2)[1:2])...; 
				 markershape = :x, label = "Sun-Earth L2")
		
		for trajectory ∈ manifold
			plotpositions!(fig, trajectory; 
						   exclude_z  = true,
						   label     = :none, 
						   palette   = :blues, 
				           linestyle = :dot)
		end
		
		plotpositions!(fig, propagate(orbit, T); 
					   linewidth = 3, color = :black, legend = :topleft, 
					   label = "Halo Orbit", exclude_z = true)
		
		savefig(fig, joinpath(plotsdir(), "manifold_transfer_phase1.png"))
		fig
		
	elseif mission_phase == "Phase Two"
		
		orbit, T = halo(SunEarth; Az=100_000u"km", L=2)
		manifold = unstable_manifold(orbit, T; duration=3T, eps=1e-9, saveat=1e-2);	
		
		LU  = (string ∘ normalized_length_unit)(orbit.system)
		fig = plot(; title = "Phase #2: Sun-Earth Halo to Transfer Orbit", 
			   		 xlabel = "X ($LU)", ylabel = "Y ($LU)",
			   		 dpi = 250, legend = :topright)
		
		for trajectory ∈ manifold
			plotpositions!(fig, trajectory; 
						   exclude_z  = true,
						   label     = :none, 
						   palette   = :blues, 
				           linestyle = :dot)
		end
		
		plotpositions!(fig, propagate(orbit, T); 
					   linewidth = 3, color = :black, legend = :topright,
					   label = "Halo Orbit", exclude_z = true)
		
		savefig(fig, joinpath(plotsdir(), "manifold_transfer_phase2.png"))
		fig
		
	elseif mission_phase == "Phase Three"
		
		orbit, T = halo(SunJupiter; Az=100_000u"km", L=1)
		manifold = stable_manifold(orbit, T; duration=3T, eps=1e-9, saveat=1e-2);	
		
		LU  = (string ∘ normalized_length_unit)(orbit.system)
		fig = plot(; title = "Phase #3: Transfer Orbit to Sun-Jupiter Halo",
				     xlabel = "X ($LU)", ylabel = "Y ($LU)",
			   		 dpi = 250, legend = :topright)
		
		scatter!(fig, map(el->[el], secondary_synodic_position(orbit)[1:2])...; 
				 label = "Jupiter")
		
		for trajectory ∈ manifold
			plotpositions!(fig, trajectory; 
						   exclude_z  = true,
						   label     = :none, 
						   palette   = :reds, 
				           linestyle = :dot)
		end
		
		plotpositions!(fig, propagate(orbit, T); 
					   linewidth = 3, color = :black, legend = :topleft,
					   label = "Halo Orbit", exclude_z = true)
		
		savefig(fig, joinpath(plotsdir(), "manifold_transfer_phase3.png"))
		fig
		
	end
	
	
end

# ╔═╡ d91d9336-b6e8-44b3-9c59-5db794faca6f
md"""
## Phase #1: Earth to Sun-Earth
_Where should we point our launch vehicle?_




"""

# ╔═╡ 35a0ea98-d918-4883-a6da-cb87a2aea814
md"""
## Phase #2 and #3: Optimal Intersection
_How can we get to the Sun-Jupiter manifold?_
"""

# ╔═╡ da51983c-d826-4ac3-a38c-51b9e6444f79


# ╔═╡ d244c56b-2323-4504-98a7-e9557d2e9689
md"""
## Lessons Learned

### Issues
* Some results may be incorrect due to book-keeping, including...
  * CR3BP to HCI
  * Lambert scanner issues

### Forward Work
* Fix Lambert issues, confirm CR3BP to HCI calculations
* Compare correct manifold-transfer mission results to Hohmann, Lambert (without manifold)
* Use nonlinear optimizer to find optimal departure and arrival Halo orbit amplitudes
* Use ephemeris data for realistic mission planning

### Package Announcement
* New Julia package: `Pkg.install("GeneralAstrodynamics")`
* Features include:
  * R2BP, CR3BP, and NBP definitions
  * Position, velocity, zero-velocity-curve, Lagrange point plotting
  * Ephemeris interpolation
  * Orbit propagation
  * Kepler, Lambert, and Halo solvers 
  * More to come!
"""

# ╔═╡ 36b46ffb-bcb0-43d4-a08b-fd8c9dda185f
md"""
## Project References
"""

# ╔═╡ 8c772140-a05c-47cb-aac5-2149a28fc151
md"""
* NASA,NASAs Lunar Exploration Program Overview, 2020.
* Rund, M. S., “Interplanetary Transfer Trajectories Using the Invariant Manifolds of Halo Orbits,” , 2018.
* Richardson, D., “Analytical construction of periodic orbits about the collinear points of the Sun-Earth system.” asdy, 1980, p. 127.
* Koon,W.S.,Lo,M.W.,Marsden,J.E.,andRoss,S.D.,“Dy- namical systems, the three-body problem and space mission design,” Free online Copy: Marsden Books, 2008.
* Howell, K. C., “Three-dimensional, periodic,haloorbits,” Ce- lestial mechanics, Vol. 32, No. 1, 1984, pp. 53–71.
* Carpinelli, J., “Exploring Invariant Manifolds and Halo Orbits,” https://github.com/cadojo/Halo-Orbit-Solvers, 2020- 2021.
* Carpinelli, J., “GeneralAstrodynamics.jl,” https://github.com/cadojo/GeneralAstrodynamics.jl, 2021.
* Bezanson, J., Edelman, A., Karpinski, S., and Shah, V. B., “Julia: A fresh approach to numerical computing,” SIAM review, Vol. 59, No. 1, 2017, pp. 65–98. URL https://doi.org/10.1137/141000671.
* van der Plas, F., “Pluto.jl,” https://github.com/fonsp/Pluto.jl, 2020.
* Williams, J., Lee, D. E., Whitley, R. J., Bokelmann, K. A., Davis, D. C., and Berry, C. F., “Targeting cislunar near recti- linear halo orbits for human space exploration,” 2017.
* Vallado, D. A., Fundamentals of astrodynamics and applica- tions, Vol. 12, Springer Science & Business Media, 2001.
* Lara,M.,Russell,R.,andVillac,B.,“Classificationofthedis- tant stability regions at Europa,” Journal of Guidance, Control, and Dynamics, Vol. 30, No. 2, 2007, pp. 409–418.
* Zimovan-Spreen, E. M., Howell, K. C., and Davis, D. C., “Near rectilinear halo orbits and nearby higher-period dynam- ical structures: orbital stability and resonance properties,” Ce- lestial Mechanics and Dynamical Astronomy, Vol. 132, No. 5, 2020, pp. 1–25.
"""

# ╔═╡ 0929f835-bef5-462b-9477-c95f70dcd2ba
md"""
# Extras
"""

# ╔═╡ 2b852e42-915f-4088-89c1-bf5436384b13
md"""
## Dependencies
"""

# ╔═╡ 39b25fb5-89c0-46aa-b521-de42989a942c
md"""
## Halo Orbit Destination
"""

# ╔═╡ 3fc0b719-850f-481c-935d-ca4af12a6c53
md"""
## Sun-Earth Halo
"""

# ╔═╡ 42e66a2a-3f4d-4eb5-a6bd-a1359c225c79
md"""
## Manifold Intersection with Nearest Neighbors
"""

# ╔═╡ 224bfed5-eccb-4da8-8ed1-f629ebfc9f8b
md"""
## Optimal Manifold Intersection
"""

# ╔═╡ 6144fd4d-0fc0-4a85-930e-94df9c06912b
md"""
### Pre-compute Halo Orbit States
"""

# ╔═╡ ff9be5b4-4fab-4abb-ade3-f295acefe1c8
md"""
### Pre-compute Halo Orbit Monodromy Matrices
"""

# ╔═╡ dfd99ef6-eea3-4b7d-a350-2a9f3d3a7863
md"""
### Cost Function
"""

# ╔═╡ fbc3584f-40fc-4272-9fdc-2ae32863e873
methods(halo)

# ╔═╡ 36890bc5-c54e-431a-8bf3-9d0ecfd30d3d
md"""
### Box Optimization
"""

# ╔═╡ cf856229-e383-4843-9e38-9883038eefe8
md"""
## Modidified Hohmann Transfer
"""

# ╔═╡ f8d40fa2-73f1-4a3d-b081-846324f10e38
md"""
## Support Types
"""

# ╔═╡ 9e5cd21c-23ac-4cf1-97f6-48b1647e7359
md"""
### Halos
"""

# ╔═╡ a0739712-bd5b-49b0-a9ae-9da5bac7c345
begin
	struct Halo{O<:CR3BPOrbit, T<:Real}
		orbit::O
		period::T
	end
	
	function Halo(param::P; kwargs...) where P<:Union{Real, CR3BPSystem}
		orbit, T = halo(param; kwargs...)
		return Halo(orbit, T)
	end
end;

# ╔═╡ 6bae2db8-3ba3-46aa-b65b-a75ca21a3d05
begin
	
	# Destination Halo
	arrival_halo = Halo(halo(SunJupiter; Az = 400_000u"km", L = 1)...)
	
	@terminal print("Destination Halo:\n", arrival_halo.orbit)
end

# ╔═╡ 35b796d2-2780-4190-b8d6-5d507083cc38
md"""
## Support Functions
"""

# ╔═╡ 1444c267-8f14-4194-a2af-031f406d90fd
md"""
### CR3BP to R2BP
"""

# ╔═╡ 715dd0bb-cb36-4bab-b53e-bdbeb2ed8d51
function R2BP(orb::CR3BPOrbit, body_index::Int, body::R2BPSystem; 
			  frame = Inertial, i = 0u"°")

	@assert body_index ∈ (1,2) "Second argument must be 1 or 2."
	
	# Normalized, synodic reference frame
	orbit = (synodic ∘ normalize)(orb)
	
	# Spacecraft state (Synodic, normalized)
	rₛ = position_vector(orbit)
	vₛ = velocity_vector(orbit)
	tₛ = epoch(orbit.state)
	
	# Body state (Synodic, normalized)
	rᵢ = body_index == 1 ? primary_synodic_position(orbit) : 
						   secondary_synodic_position(orbit)
	
	# Synodic to bodycentric inertial
	rₛ = inertial(rₛ - rᵢ, tₛ) |> MVector
	vₛ = inertial(vₛ + MVector{3}(0,0,1) × rᵢ, tₛ) |> MVector
	
	# Canonical to dimensioned
	DU = normalized_length_unit(orbit)
	TU = normalized_time_unit(orbit)
	rₛ = rₛ .* DU
	vₛ = vₛ .* DU/TU
	tₛ = tₛ  * TU
	
	# Rotate about x by the inclination angle i
	Rx(θ) = transpose(RotX(θ)) # produces [1 0 0; 0 cθ sθ; 0 -sθ cθ]
	rₛ = Rx(i) * rₛ
	vₛ = Rx(i) * vₛ
	
	# Cartesian state
	state = CartesianState(
		uconvert.(u"km", rₛ), 
		uconvert.(u"km/s", vₛ), 
		uconvert(u"s", tₛ), 
		frame
	)
	
	# Orbit structure
	return R2BPOrbit(state, body)
	
end;

# ╔═╡ 7d2894c5-5670-42da-9225-34d29583fd74
md"""
## Julia vs. MATLAB
_What's the difference?_

* MATLAB is commercial software, while Julia is free and open-source
* Julia has a robust package manager, and can run faster than MATLAB __during execution__
* Julia is _just-ahead-of-time_ compiled, so you pay by __waiting for your code to compile__ the first time you execute it (microseconds to seconds)

| Task | MATLAB | Julia | 
| ---- | ------ | ----- |
| Print to the console | disp('Hello, world!') | print("Hello, world!") |
| Make a random 3×3 matrix | M = rand(3,3) | M = randn(3,3) | 
| Take the determinant | det(M) | det(M) | 
| Matrix multiplication | M * M | M * M |
| Element-wise multiplication | M .* M | M .* M |
| Two-norm of a vector | norm(vec) | norm(vec) |
| Vectorize function (1/2)| for i = vec, f(i), end | for i = vec; f(i); end |
| Vectorize function (2/2)| n/a | f.(vec) _or_ map(f, vec) |
| Numerical integration | ode45(f, x0, p t) | solve(ODEProblem(f, x₀, p, t)) |
| Anonymous function | f = @(x,y) x^2 + y^2 | f = (x,y) -> x^2 + y^2 |
| Symbolic math | syms x y z | @variables x y z | 
| Manual | help f | @doc f |
 
"""

# ╔═╡ 25158dd7-ee8f-4781-8c6d-a8b1c9bbe657
md"""
## Solar System Inclination
"""

# ╔═╡ 6ad80a71-fbd2-42e9-8254-a85f2c6ee228
begin
	
	earth, t = let
		ephem  = joinpath(datadir(), "exp_pro", "ephemeris")
		state  = interpolator(joinpath(ephem, "wrt_sun", "Earth.txt"))
		trange = range(state.timespan[1]; 
				  stop   = state.timespan[2], 
				  length = 1_000_000)
		t -> R2BPOrbit(state.state(t), Sun), trange
	end
	
	jupiter = let
		ephem  = joinpath(datadir(), "exp_pro", "ephemeris")
		state  = interpolator(joinpath(ephem, "wrt_sun", "Jupiter.txt"))
		t -> R2BPOrbit(state.state(t), Sun)
	end
	
	moon = let
		ephem = joinpath(datadir(), "exp_pro", "ephemeris")
		state = interpolator(joinpath(ephem, "wrt_earth", "Moon.txt"))
		t -> R2BPOrbit(state.state(t), Earth)
	end
	
	ˢiₑ = mean(inclination.(earth.(t)))
	ˢiⱼ = mean(inclination.(jupiter.(t)))
	ᵉiₘ = mean(inclination.(moon.(t)))
	
	
	@terminal let
		println("Average Inclination:")
		println("    Earth wrt Sun: ", ˢiₑ)
		println("  Jupiter wrt Sun: ", ˢiⱼ)
		println("   Moon wrt Earth: ", ᵉiₘ)
	end	
end

# ╔═╡ 286dad18-e175-4eae-91e7-667f6a6d944e
begin

	departure_halo = Halo(SunEarth; Az = 25_000u"km", L = 2)
	
	earth_departure = let 

			
		man = stable_manifold(departure_halo.orbit, departure_halo.period;
							  duration = 3 * departure_halo.period,
							  eps = -1e-2, num_trajectories = 25, 
							  saveat = 1e-2,
							  reltol = 1e-14, abstol = 1e-14)

		targets = vcat(man...)
		indices = [i for i ∈ 1:length(targets)]

		filter!(
			i -> 0.5u"Rearth" ≤ scalar_position(
				R2BP(targets[i], 2, Earth; frame = ECI, i = ᵉiₘ)
			) ≤ 2u"Rearth",
			indices
		)
		
		optimal_index = findmin(
			i -> let
				orbit = R2BP(targets[i], 2, Earth; frame = ECI, i = ᵉiₘ)
				      (ustrip ∘ upreferred ∘ inclination)(orbit)^2 + 
					  (ustrip ∘ upreferred ∘ epoch)(orbit.state)^2
			end, indices
		)[2]
		
		targets[optimal_index]
		
	end
		

	@terminal let
		orbit = R2BP(earth_departure, 2, Earth; frame = ECI, i = ᵉiₘ)
		println(orbit)
		println("  Orbit Properties:\n")
		println("    T = $(abs(uconvert(u"d", epoch(orbit.state))))")
		println("   C3 = $(C3(orbit))")
		println("  alt = $(uconvert(u"km", scalar_position(orbit) - 1u"Rearth"))")
	end

end

# ╔═╡ 27f75a11-0d76-4e0b-a0e0-d7479e71483f
md"""
* Let's assume a Halo orbit with a $50,000$ km Z-axis amplitude about Sun-Earth $L2$
* We need to find a state within the Halo's __stable manifold__ that is __easy__ to get to from Earth
* The cost function used to evaluate each orbital state, and the resulting __optimal__ Earth-departure orbit are shown below
* __Let's only search for orbital states within 2 Earth radii of Earth's center of mass!__

$\text{COST}({}^{\text{ECI}}r_{\text{sc}}, {}^{\text{ECI}}v_{\text{sc}}, t_{(\text{to halo})})= {}^{\text{ECI}}i_{\text{sc}}^2 + t_{(\text{to halo})}^2$

#### Optimal Earth-departure Target

*  $(latexify(round(ustrip(u"yr", abs(epoch(R2BP(earth_departure, 2, Earth; frame = ECI, i = ᵉiₘ).state))), digits=4))) years to Halo
"""

# ╔═╡ fc2c5ff7-b52f-4bad-8afc-1edbdd0c0d69
@terminal let
	orbit = R2BP(earth_departure, 2, Earth; frame = ECI, i = ᵉiₘ)
	println(orbit)
	println("  Orbit Properties:\n")
	println("    C3 = $(C3(orbit))")
	println("     i =  $(inclination(orbit))")
end

# ╔═╡ 76410560-afa3-4ea0-b7a8-a18f400c1e05
halos = (
	sun_earth = propagate(departure_halo.orbit, departure_halo.period; 
						  saveat=1e-6, reltol=1e-14, abstol=1e-14),
	sun_jupiter = propagate(arrival_halo.orbit, arrival_halo.period;
						  saveat=1e-6, reltol=1e-14, abstol=1e-14)
);

# ╔═╡ 4bbb7585-6225-43f1-9ea6-7bb33b68d951
begin
	
	halo_monodromy = (
		sun_earth = monodromy(departure_halo.orbit, departure_halo.period),
		sun_jupiter = monodromy(arrival_halo.orbit, arrival_halo.period)
	)
	
	halo_unstable_eigenvector = (
		sun_earth   = unstable_eigenvector(halo_monodromy.sun_earth),
		sun_jupiter = unstable_eigenvector(halo_monodromy.sun_jupiter)
	)
	
	halo_stable_eigenvector = (
		sun_earth   = stable_eigenvector(halo_monodromy.sun_earth),
		sun_jupiter = stable_eigenvector(halo_monodromy.sun_jupiter)
	)
	
end;

# ╔═╡ 3d8fbf1c-bacf-4d07-ada1-58fe355de6d8
nearest_neighbor_plot, nearest_neighbor = let
		
	arrival_manifold_dv = 0.3
	arrival_manifold_duration = 5 * arrival_halo.period
	
	transfer_manifold_duration = 5 * departure_halo.period
	transfer_manifold_dv = 0.3
		
	arrival_manifold = stable_manifold(arrival_halo.orbit, 
									   arrival_halo.period;
									   eps = arrival_manifold_dv,
									   saveat = 1e-2,
									   num_trajectories = 100,
									   reltol = 1e-14,
									   abstol = 1e-14,
									   duration = arrival_manifold_duration)

	arrivals_wrt_sun = map(
		traj -> map(orbit -> R2BP(orbit, 1, Sun; frame = HCI, i = ˢiⱼ), traj),
		arrival_manifold)


	transfer_manifold = unstable_manifold(departure_halo.orbit, 
										  departure_halo.period;
										  eps      = transfer_manifold_dv,
										  saveat   = 1e-2,
										  num_trajectories = 100,
										  reltol   = 1e-14, 
										  abstol   = 1e-14,
										  duration = transfer_manifold_duration)
	transfers_wrt_sun = map(
		traj -> map(orbit -> R2BP(orbit, 1, Sun; frame = HCI, i = ˢiₑ), traj),
		transfer_manifold)


	@assert string(lengthunit(first(first(transfers_wrt_sun)))) == 
			string(lengthunit(first(first(arrivals_wrt_sun))))
	LU = string(lengthunit(first(first(transfers_wrt_sun))))
	
	fig = plot(; title  = "Invariant Manifolds (Heliocentric Inertial Frame)",
				 xlabel = "X ($LU)", ylabel = "Y ($LU)", zlabel = "Z ($LU)",
				 dpi    = 200)
	for trajectory ∈ transfers_wrt_sun
		plotpositions!(fig, position_vector.(trajectory); 
					   label = :none, palette = :blues)
	end
	for trajectory ∈ arrivals_wrt_sun
		plotpositions!(fig, position_vector.(trajectory); 
					   label = :none, palette = :reds)
	end		

	fig
	
	min_distance = min(
		nn(
			KDTree(ustrip.(u"km", 
					hcat(position_vector.(vcat(transfers_wrt_sun...))...))), 
			ustrip.(u"km", hcat(position_vector.(vcat(arrivals_wrt_sun...))...))
		)[2]...
	) * u"km"

	fig, min_distance
	
end;

# ╔═╡ 947a5745-ff84-40fa-8e52-28f9c70a4a31
md"""
## Phase #2 and #3: Manifold Intersection
_First attempt – where can the Sun-Earth manifold take us?_

* Compute the __unstable manifold__ near your Sun-Earth Halo orbit
* Compute the __stable manifold__ near your Sun-Jupiter destination Halo orbit
* Find the __optimal__ intersection between the two manifolds
* If positions are identical, the difference in velocity can be treated as an impulsive maneuver!


* First try: pre-compute both manifolds, and use the [Nearest Neighbors](https://github.com/KristofferC/NearestNeighbors.jl) algorithm to quickly find the closest pair of points
* Unfortunately, this isn't close enough! The closest distance between manifolds, as found with Nearest Neighbors, is $(latexify(ustrip(u"km", nearest_neighbor))) km

"""

# ╔═╡ aa6d7608-59c3-414e-a8f5-3717d509884f
nearest_neighbor_plot

# ╔═╡ 953b6e4f-9d20-42f2-8475-8cc824b491d3
begin
	
	function optimal_intersection(x, p)
		
		sun_earth_halo_index     = x[1]
		sun_jupiter_halo_index   = x[2]
		sun_earth_perturbation   = x[3]
		sun_jupiter_perturbation = x[4]
		
		sun_earth_halo_index   = (Int ∘ floor)(sun_earth_halo_index)
		sun_jupiter_halo_index = (Int ∘ floor)(sun_jupiter_halo_index)
		
		departure = manifold(
			halos.sun_earth[sun_earth_halo_index], 
			halo_unstable_eigenvector.sun_earth;
			eps = sun_earth_perturbation
		)
		
		arrival = manifold(
			halos.sun_jupiter[sun_jupiter_halo_index],
			halo_stable_eigenvector.sun_jupiter;
			eps = sun_jupiter_perturbation
		)
		
		
		to_jupiter = propagate(
			departure, 10.0; saveat=1e-4, reltol=1e-14, abstol=1e-14
		)

		from_jupiter = propagate(
			arrival, -10.0; saveat=1e-4, reltol=1e-14, abstol=1e-14
		)
		
		to_jupiter   = R2BP.(to_jupiter, 1, Sun; frame = HCI, i = ˢiₑ)
		from_jupiter = R2BP.(from_jupiter, 1, Sun; frame = HCI, i = ˢiⱼ)
		
		closest_approach = let
			D = ustrip.(u"km", hcat(position_vector.(to_jupiter)...))
			A = ustrip.(u"km", hcat(position_vector.(from_jupiter)...))
			
			distances = nn(KDTree(D), A)[2]
			
			min(distances...)

		end

	end
	
end;

# ╔═╡ 37d724a3-c23a-4b55-9e5e-d0bdb4bd2689
begin
	
	x = Float64[
		length(halos.sun_earth) ÷ 2,
		length(halos.sun_jupiter) ÷ 2,
		-1e-3, 
		1e-3
	]
	
	lb = Float64[1, 1, -1, -1]
	ub = Float64[length(halos.sun_earth), length(halos.sun_jupiter), 1, 1]
	
	problem = GalacticOptim.OptimizationProblem(
		optimal_intersection, x; lb = lb, ub = ub
	)
	
	@terminal println("julia> solve(problem, BBO()) # This runs \"forever\"!")

end

# ╔═╡ ffbc7fe3-130f-4da7-aec6-d392b5a578aa
begin
	
	ear = Halo(SunEarth; Az = 400_000u"km", L = 2, hemisphere = :northern)
	jup = Halo(SunJupiter; Az = 25_000u"km", L = 1, hemisphere = :northern)
	
	departure_manifold = map(
		trajectory -> map(orbit -> R2BP(orbit, 1, Sun; frame = HCI, i = ˢiₑ),
						  trajectory),
		unstable_manifold(
			ear.orbit, ear.period; 
			saveat = 1e-2, num_trajectories = 500,
			eps = 1, duration = 5.0, reltol = 1e-14, abstol = 1e-14)
	)
	
	arrival_manifold = map(
		trajectory -> map(orbit -> R2BP(orbit, 1, Sun; frame = HCI, i = ˢiⱼ),
						  trajectory),
		unstable_manifold(
			jup.orbit, jup.period; 
			saveat = 1e-2, num_trajectories = 600,
			eps = -1.1, duration = 5.0, reltol = 1e-14, abstol = 1e-14)
	)
	
	from_earth = map(
		trajectory -> interpolator(trajectory),
		departure_manifold
	)
	
	
	to_jupiter = map(
		trajectory -> interpolator(trajectory),
		arrival_manifold
	)
	
end;

# ╔═╡ bd66a3ce-a15a-43dd-aba9-dccf8c48abeb
let
	
	
	function findmin(ball, mitt)
		
		function cost(x,p)
			δr = (sqrt ∘ abs ∘ ustrip ∘ upreferred ∘ norm)(
				position_vector(ball.state(x[1] * u"s")) - 
				position_vector(mitt.state(x[2] * u"s")))
		end
		
		x₀ = mean(ustrip.(u"s", ball.timespan))

		lb = ustrip.(u"s", [min(ball.timespan...), min(mitt.timespan...)])
		ub = ustrip.(u"s", [max(ball.timespan...), max(mitt.timespan...)])


		sol = solve(
			GalacticOptim.OptimizationProblem(cost, x₀; lb = lb, ub = ub),
			BBO(); reltol = 1e-14, abstol = 1e-14
		)
			
		return sol.minimum
	end
	
	

	mins = [
		findmin(from_earth[rand(1:length(from_earth))], to_jupiter[j]) 
		for j = 1:length(to_jupiter)
	]

	min(mins...)
		
	
end

# ╔═╡ 6289f398-ddf3-4bda-b95b-735fcc24d8da
begin
	
	E = map(
		trajectory -> ustrip.(u"km", vcat(position_vector.(trajectory)'...)),
		departure_manifold
	)
	
	J = map(
		trajectory -> ustrip.(u"km", vcat(position_vector.(trajectory)'...)),
		arrival_manifold
	)
	
	
	man = plot()
	
	for pos ∈ E
		x = @views pos[:,1]
		y = @views pos[:,2]
		z = @views pos[:,3]
		plot!(
			man, x, y,
			label = :none, palette = :greens, 
			dpi = 150, aspect_ratio = 1
		)
	end
	
	for pos ∈ J
		x = @views pos[:,1]
		y = @views pos[:,2]
		z = @views pos[:,3]
		plot!(
			man, x, y,
			label = :none, palette = :reds, 
			dpi = 150, aspect_ratio = 1, linestyle = :dot
		)
	end
	
	plot!(man, xlims=[-1.5e8, 1.5e8], ylims=[-1e8, 1e8])

end

# ╔═╡ Cell order:
# ╟─d59d8616-a224-11eb-043c-d1f9fbaa616e
# ╟─af8b6ac7-7391-4662-adec-01ca03d94a30
# ╟─684c3b78-a47c-4fba-9a80-e6a07bc5e799
# ╟─afa41959-dbee-4e81-97a6-1717f476dd77
# ╟─267edd09-82ea-4cf9-92e8-f871ac4f0f5c
# ╟─46d550bc-713e-43af-8b2e-8ffa65d0e600
# ╟─3813dffe-54fb-48a1-a5fb-9a6c81ed1ad7
# ╟─50ee947b-7df3-4de6-9223-08bc1bd9398d
# ╟─0e8c29c8-32d0-4b2b-aa20-e947cf36389c
# ╟─de2eb7a9-3d36-42c0-b12a-f7f2303692f3
# ╟─272d58f1-4d59-4243-8de3-326b02d4628a
# ╠═72492b56-30f3-44ad-81ff-1b59fced5d47
# ╟─c761130f-88e5-4375-abba-9b196c9b0a27
# ╟─dd9efeb6-359a-428b-b2be-93f7a3735734
# ╟─507a6e8c-52e2-4223-befc-82ad631af446
# ╟─2319c22e-4417-4c0a-9b0b-b951a8bf58f4
# ╟─b489caad-6f05-4e1f-88a9-3c008e4ba98c
# ╟─a4538dea-2e55-42c6-8573-e77c75607e7c
# ╠═fb847908-ee98-447e-ae03-23afd0b9d9e4
# ╟─8786e7d8-9d78-4b7c-bd19-d221a471a32a
# ╟─c850a977-9fab-4014-8887-6667e64e079a
# ╟─bd964ca0-534b-46b8-8538-d582186c1f94
# ╟─88d150e7-609c-4a5f-a0fc-48cbae74b10b
# ╟─d91d9336-b6e8-44b3-9c59-5db794faca6f
# ╟─27f75a11-0d76-4e0b-a0e0-d7479e71483f
# ╟─fc2c5ff7-b52f-4bad-8afc-1edbdd0c0d69
# ╟─947a5745-ff84-40fa-8e52-28f9c70a4a31
# ╟─aa6d7608-59c3-414e-a8f5-3717d509884f
# ╟─35a0ea98-d918-4883-a6da-cb87a2aea814
# ╟─da51983c-d826-4ac3-a38c-51b9e6444f79
# ╟─d244c56b-2323-4504-98a7-e9557d2e9689
# ╟─36b46ffb-bcb0-43d4-a08b-fd8c9dda185f
# ╟─8c772140-a05c-47cb-aac5-2149a28fc151
# ╟─0929f835-bef5-462b-9477-c95f70dcd2ba
# ╟─2b852e42-915f-4088-89c1-bf5436384b13
# ╠═a9092c8c-b3b2-4608-99c3-8cc73d7816f3
# ╟─39b25fb5-89c0-46aa-b521-de42989a942c
# ╠═6bae2db8-3ba3-46aa-b65b-a75ca21a3d05
# ╟─3fc0b719-850f-481c-935d-ca4af12a6c53
# ╠═286dad18-e175-4eae-91e7-667f6a6d944e
# ╟─42e66a2a-3f4d-4eb5-a6bd-a1359c225c79
# ╠═3d8fbf1c-bacf-4d07-ada1-58fe355de6d8
# ╟─224bfed5-eccb-4da8-8ed1-f629ebfc9f8b
# ╟─6144fd4d-0fc0-4a85-930e-94df9c06912b
# ╠═76410560-afa3-4ea0-b7a8-a18f400c1e05
# ╟─ff9be5b4-4fab-4abb-ade3-f295acefe1c8
# ╠═4bbb7585-6225-43f1-9ea6-7bb33b68d951
# ╟─dfd99ef6-eea3-4b7d-a350-2a9f3d3a7863
# ╠═953b6e4f-9d20-42f2-8475-8cc824b491d3
# ╠═fbc3584f-40fc-4272-9fdc-2ae32863e873
# ╟─36890bc5-c54e-431a-8bf3-9d0ecfd30d3d
# ╠═37d724a3-c23a-4b55-9e5e-d0bdb4bd2689
# ╟─cf856229-e383-4843-9e38-9883038eefe8
# ╠═ffbc7fe3-130f-4da7-aec6-d392b5a578aa
# ╠═bd66a3ce-a15a-43dd-aba9-dccf8c48abeb
# ╠═6289f398-ddf3-4bda-b95b-735fcc24d8da
# ╟─f8d40fa2-73f1-4a3d-b081-846324f10e38
# ╟─9e5cd21c-23ac-4cf1-97f6-48b1647e7359
# ╠═a0739712-bd5b-49b0-a9ae-9da5bac7c345
# ╟─35b796d2-2780-4190-b8d6-5d507083cc38
# ╟─1444c267-8f14-4194-a2af-031f406d90fd
# ╠═715dd0bb-cb36-4bab-b53e-bdbeb2ed8d51
# ╟─7d2894c5-5670-42da-9225-34d29583fd74
# ╟─25158dd7-ee8f-4781-8c6d-a8b1c9bbe657
# ╠═6ad80a71-fbd2-42e9-8254-a85f2c6ee228
