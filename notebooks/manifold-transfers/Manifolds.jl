### A Pluto.jl notebook ###
# v0.15.0

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
* Duration should be reasonable
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
	manifold = unstable_manifold(orbit, T; eps=1e-5, 
								 num_trajectories = 100, duration=1T, saveat=1e-2)
	
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
		manifold = stable_manifold(orbit, T; duration=T, eps=-1e-7, saveat=1e-2)
		
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
		
		fig
		
	elseif mission_phase == "Phase Three"
		
		orbit, T = halo(SunJupiter; Az=300_000u"km", L=1)
		manifold = stable_manifold(orbit, T; duration=3T, eps=1e-9, saveat=1e-2);	
		
		LU  = (string ∘ normalized_length_unit)(orbit.system)
		fig = plot(; title = "Phase #3: Transfer Orbit to Sun-Jupiter Halo",
				     xlabel = "X ($LU)", ylabel = "Y ($LU)", zlabel = "Z ($LU)",
			   		 dpi = 250, legend = :topright)
		
		scatter!(fig, map(el->[el], secondary_synodic_position(orbit)[1:2])...; 
				 label = "Jupiter")
		
		for trajectory ∈ manifold
			plotpositions!(fig, trajectory; 
						   exclude_z  = false,
						   label     = :none, 
						   palette   = :reds, 
				           linestyle = :dot)
		end
		
		plotpositions!(fig, propagate(orbit, T); 
					   linewidth = 3, color = :black, legend = :topleft,
					   label = "Halo Orbit", exclude_z = true)
		
		fig
		
	end
	
	
end

# ╔═╡ da51983c-d826-4ac3-a38c-51b9e6444f79


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

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BlackBoxOptim = "a134a8b2-14d6-55f6-9291-3336d3ab0209"
ConcreteStructs = "2569d6c7-a4a2-43d3-a901-331e8e4be471"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
DifferentialEquations = "0c46a032-eb83-5123-abaf-570d42b7fbaa"
DrWatson = "634d3b9d-ee7a-5ddf-bec9-22491ea816e1"
GalacticOptim = "a75be94c-b780-496d-a8a9-0878b188d577"
GeneralAstrodynamics = "8068df5b-8501-4530-bd82-d24d3c9619db"
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
Latexify = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
NearestNeighbors = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Revise = "295af30f-e4ad-537b-8983-00126c2a3abe"
Rotations = "6038ab10-8711-5258-84ad-4b1120ba62dc"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"
UnitfulAngles = "6fb2a4bd-7999-5318-a3b2-8ad61056cd98"
UnitfulAstro = "6112ee07-acf9-5e0f-b108-d242c714bf9f"

[compat]
BlackBoxOptim = "~0.6.0"
ConcreteStructs = "~0.2.2"
DataFrames = "~1.1.1"
DifferentialEquations = "~6.17.1"
DrWatson = "~2.0.5"
GalacticOptim = "~2.0.3"
GeneralAstrodynamics = "~0.9.4"
LaTeXStrings = "~1.2.1"
Latexify = "~0.15.6"
NearestNeighbors = "~0.4.9"
Plots = "~1.16.7"
PlutoUI = "~0.7.9"
Revise = "~3.1.17"
Rotations = "~1.0.2"
StaticArrays = "~1.2.4"
Unitful = "~1.8.0"
UnitfulAngles = "~0.6.1"
UnitfulAstro = "~1.0.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractTrees]]
git-tree-sha1 = "03e0550477d86222521d254b741d470ba17ea0b5"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.3.4"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "f87e559f87a45bece9c9ed97458d3afe98b1ebb9"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.1.0"

[[ArrayInterface]]
deps = ["IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "045ff5e1bc8c6fb1ecb28694abba0a0d55b5f4f5"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "3.1.17"

[[ArrayLayouts]]
deps = ["FillArrays", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "a345029e95c7102ef1160cf208bfa075d93a2597"
uuid = "4c555306-a7a7-4459-81d9-ec55ddd5c99a"
version = "0.7.2"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[AstrodynamicalModels]]
deps = ["LinearAlgebra", "ModelingToolkit", "RuntimeGeneratedFunctions", "StaticArrays", "Symbolics"]
git-tree-sha1 = "53112e77e0296fb65da353ce049758082c3556c3"
uuid = "4282b555-f590-4262-b575-3e516e1493a7"
version = "0.2.6"

[[AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "a4d07a1c313392a77042855df46c5f534076fab9"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.0"

[[BandedMatrices]]
deps = ["ArrayLayouts", "FillArrays", "LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "6facee700024bdc7bc870657d235848043f5564c"
uuid = "aae01518-5342-5314-be14-df237901396f"
version = "0.16.9"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[BlackBoxOptim]]
deps = ["CPUTime", "Compat", "Distributed", "Distributions", "HTTP", "JSON", "LinearAlgebra", "Printf", "Random", "SpatialIndexing", "StatsBase"]
git-tree-sha1 = "514bbe6f2e46cb396e684eb4c12d8a6c30f3adf4"
uuid = "a134a8b2-14d6-55f6-9291-3336d3ab0209"
version = "0.6.0"

[[BoundaryValueDiffEq]]
deps = ["BandedMatrices", "DiffEqBase", "FiniteDiff", "ForwardDiff", "LinearAlgebra", "NLsolve", "Reexport", "SparseArrays"]
git-tree-sha1 = "fe34902ac0c3a35d016617ab7032742865756d7d"
uuid = "764a87c0-6b3e-53db-9096-fe964310641d"
version = "2.7.1"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c3598e525718abcc440f69cc6d5f60dda0a1b61e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.6+5"

[[CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[CPUTime]]
git-tree-sha1 = "2dcc50ea6a0a1ef6440d6eecd0fe3813e5671f45"
uuid = "a9c8d775-2e2e-55fc-8582-045d282d599e"
version = "1.0.0"

[[CSTParser]]
deps = ["Tokenize"]
git-tree-sha1 = "9723e1c07c1727082e169ca50789644a552fb023"
uuid = "00ebfdb7-1f24-5e51-bd34-a7502290713f"
version = "3.2.3"

[[CSV]]
deps = ["Dates", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode"]
git-tree-sha1 = "b83aa3f513be680454437a0eee21001607e5d983"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.8.5"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "e2f47f6d8337369411569fd45ae5753ca10394c6"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.0+6"

[[Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "be770c08881f7bb928dfd86d1ba83798f76cf62a"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "0.10.9"

[[CodeTracking]]
deps = ["InteractiveUtils", "UUIDs"]
git-tree-sha1 = "8ad457cfeb0bca98732c97958ef81000a543e73e"
uuid = "da1fd8a2-8d9e-5ec2-8556-3022fb5608a2"
version = "1.0.5"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random", "StaticArrays"]
git-tree-sha1 = "c8fd01e4b736013bc61b704871d20503b33ea402"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.12.1"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[CommonMark]]
deps = ["Crayons", "JSON", "URIs"]
git-tree-sha1 = "7632afc57f92720a01d9aedf23f413f4e5e21015"
uuid = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
version = "0.8.1"

[[CommonSolve]]
git-tree-sha1 = "68a0743f578349ada8bc911a5cbd5a2ef6ed6d1f"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.0"

[[CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "dc7dedc2c2aa9faf59a55c622760a25cbefbe941"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.31.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[ComponentArrays]]
deps = ["ArrayInterface", "ChainRulesCore", "LinearAlgebra", "Requires"]
git-tree-sha1 = "650d084f5ee7d5755033a32fa4a6f65b28e506ad"
uuid = "b0b7db55-cfe3-40fc-9ded-d10e2dbeff66"
version = "0.10.7"

[[CompositeTypes]]
git-tree-sha1 = "d5b014b216dc891e81fea299638e4c10c657b582"
uuid = "b152e2b5-7a66-4b01-a709-34e65c35f657"
version = "0.1.2"

[[ConcreteStructs]]
git-tree-sha1 = "d3cb9f9cd86434a8d6f9d7e43280f6da46d2fea5"
uuid = "2569d6c7-a4a2-43d3-a901-331e8e4be471"
version = "0.2.2"

[[ConsoleProgressMonitor]]
deps = ["Logging", "ProgressMeter"]
git-tree-sha1 = "3ab7b2136722890b9af903859afcf457fa3059e8"
uuid = "88cd18e8-d9cc-4ea6-8889-5259c0d15c8b"
version = "0.1.2"

[[ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f74e9d5388b8620b4cee35d4c5a618dd4dc547f4"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.3.0"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "ee400abb2298bd13bfc3df1c412ed228061a2385"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.7.0"

[[DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "66ee4fe515a9294a8836ef18eea7239c6ac3db5e"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.1.1"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "4437b64df1e0adccc3e5d1adbc3ac741095e4677"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.9"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelayDiffEq]]
deps = ["ArrayInterface", "DataStructures", "DiffEqBase", "LinearAlgebra", "Logging", "NonlinearSolve", "OrdinaryDiffEq", "Printf", "RecursiveArrayTools", "Reexport", "UnPack"]
git-tree-sha1 = "6eba402e968317b834c28cd47499dd1b572dd093"
uuid = "bcd4f6db-9728-5f36-b5f7-82caef46ccdb"
version = "5.31.1"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[DiffEqBase]]
deps = ["ArrayInterface", "ChainRulesCore", "DataStructures", "DocStringExtensions", "FastBroadcast", "FunctionWrappers", "IterativeSolvers", "LabelledArrays", "LinearAlgebra", "Logging", "MuladdMacro", "NonlinearSolve", "Parameters", "Printf", "RecursiveArrayTools", "RecursiveFactorization", "Reexport", "Requires", "SciMLBase", "Setfield", "SparseArrays", "StaticArrays", "Statistics", "SuiteSparse", "ZygoteRules"]
git-tree-sha1 = "9488cb4c384de8d8dc79de9ab02ca320e0e9465e"
uuid = "2b5f629d-d688-5b77-993f-72d75c75574e"
version = "6.67.0"

[[DiffEqCallbacks]]
deps = ["DataStructures", "DiffEqBase", "ForwardDiff", "LinearAlgebra", "NLsolve", "OrdinaryDiffEq", "RecipesBase", "RecursiveArrayTools", "StaticArrays"]
git-tree-sha1 = "0972ca167952dc426b5438fc188b846b7a66a1f3"
uuid = "459566f4-90b8-5000-8ac3-15dfb0a30def"
version = "2.16.1"

[[DiffEqFinancial]]
deps = ["DiffEqBase", "DiffEqNoiseProcess", "LinearAlgebra", "Markdown", "RandomNumbers"]
git-tree-sha1 = "db08e0def560f204167c58fd0637298e13f58f73"
uuid = "5a0ffddc-d203-54b0-88ba-2c03c0fc2e67"
version = "2.4.0"

[[DiffEqJump]]
deps = ["ArrayInterface", "Compat", "DataStructures", "DiffEqBase", "FunctionWrappers", "LinearAlgebra", "PoissonRandom", "Random", "RandomNumbers", "RecursiveArrayTools", "StaticArrays", "TreeViews", "UnPack"]
git-tree-sha1 = "210ae4148a9b687680c74d13f415cc190fb2c101"
uuid = "c894b116-72e5-5b58-be3c-e6d8d4ac2b12"
version = "6.14.2"

[[DiffEqNoiseProcess]]
deps = ["DiffEqBase", "Distributions", "LinearAlgebra", "Optim", "PoissonRandom", "QuadGK", "Random", "Random123", "RandomNumbers", "RecipesBase", "RecursiveArrayTools", "Requires", "ResettableStacks", "StaticArrays", "Statistics"]
git-tree-sha1 = "3d8842936fdb1d3d95929fcb99645a48d08fd0d7"
uuid = "77a26b50-5914-5dd7-bc55-306e6241c503"
version = "5.8.0"

[[DiffEqPhysics]]
deps = ["DiffEqBase", "DiffEqCallbacks", "ForwardDiff", "LinearAlgebra", "Printf", "Random", "RecipesBase", "RecursiveArrayTools", "Reexport", "StaticArrays"]
git-tree-sha1 = "8f23c6f36f6a6eb2cbd6950e28ec7c4b99d0e4c9"
uuid = "055956cb-9e8b-5191-98cc-73ae4a59e68a"
version = "3.9.0"

[[DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[DiffRules]]
deps = ["NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "214c3fcac57755cfda163d91c58893a8723f93e9"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.0.2"

[[DifferentialEquations]]
deps = ["BoundaryValueDiffEq", "DelayDiffEq", "DiffEqBase", "DiffEqCallbacks", "DiffEqFinancial", "DiffEqJump", "DiffEqNoiseProcess", "DiffEqPhysics", "DimensionalPlotRecipes", "LinearAlgebra", "MultiScaleArrays", "OrdinaryDiffEq", "ParameterizedFunctions", "Random", "RecursiveArrayTools", "Reexport", "SteadyStateDiffEq", "StochasticDiffEq", "Sundials"]
git-tree-sha1 = "5166b3ea4fbddcd9eb16a9e10a9bd5bec16e8582"
uuid = "0c46a032-eb83-5123-abaf-570d42b7fbaa"
version = "6.17.1"

[[DimensionalPlotRecipes]]
deps = ["LinearAlgebra", "RecipesBase"]
git-tree-sha1 = "af883a26bbe6e3f5f778cb4e1b81578b534c32a6"
uuid = "c619ae07-58cd-5f6d-b883-8f17bd6a98f9"
version = "1.2.0"

[[Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "abe4ad222b26af3337262b8afb28fab8d215e9f8"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.3"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Distributions]]
deps = ["FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns"]
git-tree-sha1 = "a837fdf80f333415b69684ba8e8ae6ba76de6aaa"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.24.18"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "a32185f5428d3986f47c2ab78b1f216d5e6cc96f"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.5"

[[DomainSets]]
deps = ["CompositeTypes", "IntervalSets", "LinearAlgebra", "StaticArrays", "Statistics", "Test"]
git-tree-sha1 = "6cdd99d0b7b555f96f7cb05aa82067ee79e7aef4"
uuid = "5b8099bc-c8ec-5219-889f-1d9e522a28bf"
version = "0.5.2"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[DrWatson]]
deps = ["Dates", "FileIO", "LibGit2", "MacroTools", "Pkg", "Random", "Requires", "UnPack"]
git-tree-sha1 = "b180694335d459ae755a79a86b5b57a6bbf3d7d0"
uuid = "634d3b9d-ee7a-5ddf-bec9-22491ea816e1"
version = "2.0.5"

[[DynamicPolynomials]]
deps = ["DataStructures", "Future", "LinearAlgebra", "MultivariatePolynomials", "MutableArithmetics", "Pkg", "Reexport", "Test"]
git-tree-sha1 = "b17c665e4994b1e0f30148ffdd16188cae4e9d1b"
uuid = "7c1d4256-1411-5781-91ec-d7bc3513ac07"
version = "0.3.17"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "92d8f9f208637e8d2d28c664051a00569c01493d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.1.5+1"

[[EllipsisNotation]]
deps = ["ArrayInterface"]
git-tree-sha1 = "8041575f021cba5a099a456b4163c9a08b566a02"
uuid = "da5c29d0-fa7d-589e-88eb-ea29b0a81949"
version = "1.1.0"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[ExponentialUtilities]]
deps = ["ArrayInterface", "LinearAlgebra", "Printf", "Requires", "SparseArrays"]
git-tree-sha1 = "ad435656c49da7615152b856c0f9abe75b0b5dc9"
uuid = "d4d017d3-3776-5f7e-afef-a10c40355c18"
version = "1.8.4"

[[ExprTools]]
git-tree-sha1 = "10407a39b87f29d47ebaca8edbc75d7c302ff93e"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.3"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "LibVPX_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "3cc57ad0a213808473eafef4845a74766242e05f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.3.1+4"

[[FastBroadcast]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "26be48918640ce002f5833e8fc537b2ba7ed0234"
uuid = "7034ab61-46d4-4ed7-9d0f-46aef9175898"
version = "0.1.8"

[[FastClosures]]
git-tree-sha1 = "acebe244d53ee1b461970f8910c235b259e772ef"
uuid = "9aa1b823-49e4-5ca5-8b0f-3971ec8bab6a"
version = "0.3.2"

[[FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "256d8e6188f3f1ebfa1a5d17e072a0efafa8c5bf"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.10.1"

[[FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "a603e79b71bb3c1efdb58f0ee32286efe2d1a255"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.11.8"

[[FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "f6f80c8f934efd49a286bb5315360be66956dfc4"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.8.0"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "35895cf184ceaab11fd778b4590144034a167a2f"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.1+14"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "NaNMath", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "e2af66012e08966366a43251e1fd421522908be6"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.18"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "cbd58c9deb1d304f5a245a0b7eb841a2560cfec6"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.1+5"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[FunctionWrappers]]
git-tree-sha1 = "241552bc2209f0fa068b6415b1942cc0aa486bcc"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.2"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "dba1e8614e98949abfa60480b13653813d8f0157"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+0"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "b83e3125048a9c3158cbb7ca423790c7b1b57bea"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.57.5"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "e14907859a1d3aee73a019e7b3c98e9e7b8b5b3e"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.57.3+0"

[[GalacticOptim]]
deps = ["ArrayInterface", "ConsoleProgressMonitor", "DiffResults", "DocStringExtensions", "Logging", "LoggingExtras", "Printf", "ProgressLogging", "Reexport", "Requires", "SciMLBase", "TerminalLoggers"]
git-tree-sha1 = "fd355a5e3657d4159fb8dbf9d04138b115ac1442"
uuid = "a75be94c-b780-496d-a8a9-0878b188d577"
version = "2.0.3"

[[GeneralAstrodynamics]]
deps = ["AstrodynamicalModels", "CSV", "ComponentArrays", "Contour", "Crayons", "DataFrames", "DelimitedFiles", "DifferentialEquations", "Distributed", "DocStringExtensions", "Interpolations", "LinearAlgebra", "Logging", "PhysicalConstants", "Plots", "Reexport", "Roots", "SciMLBase", "StaticArrays", "SymbolicUtils", "Symbolics", "Unitful", "UnitfulAngles", "UnitfulAstro"]
git-tree-sha1 = "1907e8da4384cfd988c8ff54c9c24f9a9f24e5ce"
uuid = "8068df5b-8501-4530-bd82-d24d3c9619db"
version = "0.9.4"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "15ff9a14b9e1218958d3530cc288cf31465d9ae2"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.3.13"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "47ce50b742921377301e15005c96e979574e130b"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.1+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "c6a1fff2fd4b1da29d3dccaffb1e1001244d844e"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.12"

[[Hwloc]]
deps = ["Hwloc_jll"]
git-tree-sha1 = "92d99146066c5c6888d5a3abc871e6a214388b91"
uuid = "0e44f5e4-bd66-52a0-8798-143a42290a1d"
version = "2.0.0"

[[Hwloc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3395d4d4aeb3c9d31f5929d32760d8baeee88aaf"
uuid = "e33a78d0-f292-5ffc-b300-72abe9b543c8"
version = "2.5.0+0"

[[IfElse]]
git-tree-sha1 = "28e837ff3e7a6c3cdb252ce49fb412c8eb3caeef"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.0"

[[Inflate]]
git-tree-sha1 = "f5fc07d4e706b84f72d54eedcc1c13d92fb0871c"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.2"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[Interpolations]]
deps = ["AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "1470c80592cf1f0a35566ee5e93c5f8221ebc33a"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.13.3"

[[IntervalSets]]
deps = ["Dates", "EllipsisNotation", "Statistics"]
git-tree-sha1 = "3cc368af3f110a767ac786560045dceddfc16758"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.5.3"

[[InvertedIndices]]
deps = ["Test"]
git-tree-sha1 = "15732c475062348b0165684ffe28e85ea8396afc"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.0.0"

[[IterTools]]
git-tree-sha1 = "05110a2ab1fc5f932622ffea2a003221f4782c18"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.3.0"

[[IterativeSolvers]]
deps = ["LinearAlgebra", "Printf", "Random", "RecipesBase", "SparseArrays"]
git-tree-sha1 = "1a8c6237e78b714e901e406c096fc8a65528af7d"
uuid = "42fd0dbc-a981-5370-80f2-aaf504508153"
version = "0.9.1"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "81690084b6198a2e1da36fcfda16eeca9f9f24e4"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.1"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[JuliaFormatter]]
deps = ["CSTParser", "CommonMark", "DataStructures", "Pkg", "Tokenize"]
git-tree-sha1 = "9e7476b5e1dc749e525497eef53809893cb6c898"
uuid = "98e50ef6-434e-11e9-1051-2b60c6c9e899"
version = "0.14.8"

[[JuliaInterpreter]]
deps = ["CodeTracking", "InteractiveUtils", "Random", "UUIDs"]
git-tree-sha1 = "31c2eee64c1eee6e8e3f30d5a03d4b5b7086ab29"
uuid = "aa1ae85d-cabe-5617-a682-6adf51b2e16a"
version = "0.8.18"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "c7f1c695e06c01b95a67f0cd1d34994f3e7db104"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.2.1"

[[LabelledArrays]]
deps = ["ArrayInterface", "LinearAlgebra", "MacroTools", "StaticArrays"]
git-tree-sha1 = "248a199fa42ec62922225334131c9330e1dd72f6"
uuid = "2ee39098-c373-598a-b85f-a56591580800"
version = "1.6.1"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a4b12a1bd2ebade87891ab7e36fdbce582301a92"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.6"

[[LeftChildRightSiblingTrees]]
deps = ["AbstractTrees"]
git-tree-sha1 = "71be1eb5ad19cb4f61fa8c73395c0338fd092ae0"
uuid = "1d6d02ad-be62-4b6b-8a6d-2f90e265016e"
version = "0.1.2"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[LibVPX_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "12ee7e23fa4d18361e7c2cde8f8337d4c3101bc7"
uuid = "dd192d2f-8180-539f-9fb4-cc70b1dcf69a"
version = "1.10.0+0"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "761a393aeccd6aa92ec3515e428c26bf99575b3b"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+0"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LightGraphs]]
deps = ["ArnoldiMethod", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "432428df5f360964040ed60418dd5601ecd240b6"
uuid = "093fc24a-ae57-5d10-9952-331d41423f4d"
version = "1.3.5"

[[LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "f27132e551e959b3667d8c93eae90973225032dd"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.1.1"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["DocStringExtensions", "LinearAlgebra"]
git-tree-sha1 = "1ba664552f1ef15325e68dc4c05c3ef8c2d5d885"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.2.4"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "dfeda1c1130990428720de0024d4516b1902ce98"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "0.4.7"

[[LoopVectorization]]
deps = ["ArrayInterface", "DocStringExtensions", "IfElse", "LinearAlgebra", "OffsetArrays", "Polyester", "Requires", "SLEEFPirates", "Static", "StrideArraysCore", "ThreadingUtilities", "UnPack", "VectorizationBase"]
git-tree-sha1 = "20316f08f70fae085ed90c7169ae318c036ee83b"
uuid = "bdcacae8-1622-11e9-2a5c-532679323890"
version = "0.12.49"

[[LoweredCodeUtils]]
deps = ["JuliaInterpreter"]
git-tree-sha1 = "4bfb8b57df913f3b28a6bd3bdbebe9a50538e689"
uuid = "6f1432cf-f94c-5a45-995e-cdbf5db27b0b"
version = "2.1.0"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "6a8a2a625ab0dea913aba95c11370589e0239ff0"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.6"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measurements]]
deps = ["Calculus", "LinearAlgebra", "Printf", "RecipesBase", "Requires"]
git-tree-sha1 = "31c8c0569b914111c94dd31149265ed47c238c5b"
uuid = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
version = "2.6.0"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "4ea90bd5d3985ae1f9a908bd4500ae88921c5ce7"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.0"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[ModelingToolkit]]
deps = ["AbstractTrees", "ArrayInterface", "ConstructionBase", "DataStructures", "DiffEqBase", "DiffEqJump", "DiffRules", "Distributed", "Distributions", "DocStringExtensions", "DomainSets", "IfElse", "JuliaFormatter", "LabelledArrays", "Latexify", "Libdl", "LightGraphs", "LinearAlgebra", "MacroTools", "NaNMath", "NonlinearSolve", "RecursiveArrayTools", "Reexport", "Requires", "RuntimeGeneratedFunctions", "SafeTestsets", "SciMLBase", "Serialization", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArrays", "SymbolicUtils", "Symbolics", "UnPack", "Unitful"]
git-tree-sha1 = "7344cc0ba1e2c4933f9b2545b8860483a9acf0d4"
uuid = "961ee093-0014-501f-94e3-6117800e7a78"
version = "5.21.0"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[MuladdMacro]]
git-tree-sha1 = "c6190f9a7fc5d9d5915ab29f2134421b12d24a68"
uuid = "46d2c3a1-f734-5fdb-9937-b9b9aeba4221"
version = "0.2.2"

[[MultiScaleArrays]]
deps = ["DiffEqBase", "FiniteDiff", "ForwardDiff", "LinearAlgebra", "OrdinaryDiffEq", "Random", "RecursiveArrayTools", "SparseDiffTools", "Statistics", "StochasticDiffEq", "TreeViews"]
git-tree-sha1 = "258f3be6770fe77be8870727ba9803e236c685b8"
uuid = "f9640e96-87f6-5992-9c3b-0743c6a49ffa"
version = "1.8.1"

[[MultivariatePolynomials]]
deps = ["DataStructures", "LinearAlgebra", "MutableArithmetics"]
git-tree-sha1 = "db4718c1b40e0b0ff739159c7230d5266bbfc7db"
uuid = "102ac46a-7ee4-5c85-9060-abc95bfdeaa3"
version = "0.3.17"

[[MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "3927848ccebcc165952dc0d9ac9aa274a87bfe01"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "0.2.20"

[[NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "50608f411a1e178e0129eab4110bd56efd08816f"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.0"

[[NLsolve]]
deps = ["Distances", "LineSearches", "LinearAlgebra", "NLSolversBase", "Printf", "Reexport"]
git-tree-sha1 = "019f12e9a1a7880459d0173c182e6a99365d7ac1"
uuid = "2774e3e8-f4cf-5e23-947b-6d7e65073b56"
version = "4.5.1"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "16baacfdc8758bc374882566c9187e785e85c2f0"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.9"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[NonlinearSolve]]
deps = ["ArrayInterface", "FiniteDiff", "ForwardDiff", "IterativeSolvers", "LinearAlgebra", "RecursiveArrayTools", "RecursiveFactorization", "Reexport", "SciMLBase", "Setfield", "StaticArrays", "UnPack"]
git-tree-sha1 = "ef18e47df4f3917af35be5e5d7f5d97e8a83b0ec"
uuid = "8913a72c-1f9b-4ce2-8d82-65094dcecaec"
version = "0.3.8"

[[OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "2bf78c5fd7fa56d2bbf1efbadd45c1b8789e6f57"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.10.2"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7937eda4681660b4d6aeeecc2f7e1c81c8ee4e2f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+0"

[[OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Optim]]
deps = ["Compat", "FillArrays", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "d34366a3abc25c41f88820762ef7dfdfe9306711"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.3.0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[OrdinaryDiffEq]]
deps = ["Adapt", "ArrayInterface", "DataStructures", "DiffEqBase", "DocStringExtensions", "ExponentialUtilities", "FastClosures", "FiniteDiff", "ForwardDiff", "LinearAlgebra", "Logging", "MacroTools", "MuladdMacro", "NLsolve", "Polyester", "RecursiveArrayTools", "Reexport", "SparseArrays", "SparseDiffTools", "StaticArrays", "UnPack"]
git-tree-sha1 = "f865c198eb4041535c9d27e0835c5b59cdb759d4"
uuid = "1dea7af3-3e70-54e6-95c3-0bf5283fa5ed"
version = "5.59.2"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "4dd403333bcf0909341cfe57ec115152f937d7d8"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.1"

[[ParameterizedFunctions]]
deps = ["DataStructures", "DiffEqBase", "DocStringExtensions", "Latexify", "LinearAlgebra", "ModelingToolkit", "Reexport", "SciMLBase"]
git-tree-sha1 = "d290c172dae21d73ae6a19a8381abbb69ef0a624"
uuid = "65888b18-ceab-5e60-b2b9-181511a3b968"
version = "5.10.0"

[[Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "2276ac65f1e236e0a6ea70baff3f62ad4c625345"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.2"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "c8abc88faa3f7a3950832ac5d6e690881590d6dc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "1.1.0"

[[PhysicalConstants]]
deps = ["Measurements", "Roots", "Unitful"]
git-tree-sha1 = "2bc26b693b5cbc823c54b33ea88a9209d27e2db7"
uuid = "5ad8b20f-a522-5ce9-bfc9-ddf1d5bda6ab"
version = "0.2.1"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "ae9a295ac761f64d8c2ec7f9f24d21eb4ffba34d"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.10"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs"]
git-tree-sha1 = "df601eed7c9637235a26b26f9f648deccd277178"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.16.7"

[[PlutoUI]]
deps = ["Base64", "Dates", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "Suppressor"]
git-tree-sha1 = "44e225d5837e2a2345e69a1d1e01ac2443ff9fcb"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.9"

[[PoissonRandom]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "44d018211a56626288b5d3f8c6497d28c26dc850"
uuid = "e409e4f3-bfea-5376-8464-e040bb5c01ab"
version = "0.4.0"

[[Polyester]]
deps = ["ArrayInterface", "IfElse", "Requires", "Static", "StrideArraysCore", "ThreadingUtilities", "VectorizationBase"]
git-tree-sha1 = "04a03d3f8ae906f4196b9085ed51506c4b466340"
uuid = "f517fe37-dbe3-4b94-8317-1923a5111588"
version = "0.3.1"

[[PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "cde4ce9d6f33219465b55162811d8de8139c0414"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.2.1"

[[PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "0d1245a357cc61c8cd61934c07447aa569ff22e6"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.1.0"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[ProgressLogging]]
deps = ["Logging", "SHA", "UUIDs"]
git-tree-sha1 = "80d919dee55b9c50e8d9e2da5eeafff3fe58b539"
uuid = "33c8b6b6-d38a-422a-b730-caa89a2f386c"
version = "0.1.4"

[[ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "afadeba63d90ff223a6a48d2009434ecee2ec9e8"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.1"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "12fbe86da16df6679be7521dfb39fbc861e1dc7b"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.1"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Random123]]
deps = ["Libdl", "Random", "RandomNumbers"]
git-tree-sha1 = "0e8b146557ad1c6deb1367655e052276690e71a3"
uuid = "74087812-796a-5b5d-8853-05524746bad3"
version = "1.4.2"

[[RandomNumbers]]
deps = ["Random", "Requires"]
git-tree-sha1 = "441e6fc35597524ada7f85e13df1f4e10137d16f"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.4.0"

[[Ratios]]
git-tree-sha1 = "37d210f612d70f3f7d57d488cb3b6eff56ad4e41"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.0"

[[RecipesBase]]
git-tree-sha1 = "b3fb709f3c97bfc6e948be68beeecb55a0b340ae"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.1.1"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "9b8e57e3cca8828a1bc759840bfe48d64db9abfb"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.3.3"

[[RecursiveArrayTools]]
deps = ["ArrayInterface", "ChainRulesCore", "DocStringExtensions", "LinearAlgebra", "RecipesBase", "Requires", "StaticArrays", "Statistics", "ZygoteRules"]
git-tree-sha1 = "b20384ee84f3e0e89cee36dbcb9c44b8bd61e133"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "2.14.3"

[[RecursiveFactorization]]
deps = ["LinearAlgebra", "LoopVectorization"]
git-tree-sha1 = "2e1a88c083ebe8ba69bc0b0084d4b4ba4aa35ae0"
uuid = "f2c3362d-daeb-58d1-803e-2bc74f2840b4"
version = "0.1.13"

[[Reexport]]
git-tree-sha1 = "5f6c21241f0f655da3952fd60aa18477cf96c220"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.1.0"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[ResettableStacks]]
deps = ["StaticArrays"]
git-tree-sha1 = "622b3e491fb0a85fbfeed6f17dc320a9f46d8929"
uuid = "ae5879a3-cd67-5da8-be7f-38c6eb64a37b"
version = "1.1.0"

[[Revise]]
deps = ["CodeTracking", "Distributed", "FileWatching", "JuliaInterpreter", "LibGit2", "LoweredCodeUtils", "OrderedCollections", "Pkg", "REPL", "Requires", "UUIDs", "Unicode"]
git-tree-sha1 = "410bbe13d9a7816e862ed72ac119bda7fb988c08"
uuid = "295af30f-e4ad-537b-8983-00126c2a3abe"
version = "3.1.17"

[[Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[Roots]]
deps = ["CommonSolve", "Printf"]
git-tree-sha1 = "4d64e7c43eca16edee87219b0b11f167f09c2d84"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "1.0.9"

[[Rotations]]
deps = ["LinearAlgebra", "StaticArrays", "Statistics"]
git-tree-sha1 = "2ed8d8a16d703f900168822d83699b8c3c1a5cd8"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.0.2"

[[RuntimeGeneratedFunctions]]
deps = ["ExprTools", "SHA", "Serialization"]
git-tree-sha1 = "5975a4f824533fa4240f40d86f1060b9fc80d7cc"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.2"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[SLEEFPirates]]
deps = ["IfElse", "Static", "VectorizationBase"]
git-tree-sha1 = "da6d214ffc85b1292f300649ef86d3c4f9aaf25d"
uuid = "476501e8-09a2-5ece-8869-fb82de89a1fa"
version = "0.6.22"

[[SafeTestsets]]
deps = ["Test"]
git-tree-sha1 = "36ebc5622c82eb9324005cc75e7e2cc51181d181"
uuid = "1bc83da4-3b8d-516f-aca4-4fe02f6d838f"
version = "0.0.1"

[[SciMLBase]]
deps = ["ArrayInterface", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "RecipesBase", "RecursiveArrayTools", "StaticArrays", "Statistics", "Tables", "TreeViews"]
git-tree-sha1 = "7d60436171978e9b4f73790ebf436fccd307df51"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "1.14.0"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "ffae887d0f0222a19c406a11c3831776d1383e3d"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.3"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "Requires"]
git-tree-sha1 = "d5640fc570fb1b6c54512f0bd3853866bd298b3e"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "0.7.0"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "daf7aec3fe3acb2131388f93a4c409b8c7f62226"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "2ec1962eba973f383239da22e75218565c390a96"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.0"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SparseDiffTools]]
deps = ["Adapt", "ArrayInterface", "Compat", "DataStructures", "FiniteDiff", "ForwardDiff", "LightGraphs", "LinearAlgebra", "Requires", "SparseArrays", "VertexSafeGraphs"]
git-tree-sha1 = "be20320958ccd298c98312137a5ebe75a654ebc8"
uuid = "47a9eef4-7e08-11e9-0b38-333d64bd3804"
version = "1.13.2"

[[SpatialIndexing]]
git-tree-sha1 = "fb7041e6bd266266fa7cdeb80427579e55275e4f"
uuid = "d4ead438-fe20-5cc5-a293-4fd39a41b74c"
version = "0.1.3"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "LogExpFunctions", "OpenSpecFun_jll"]
git-tree-sha1 = "a50550fa3164a8c46747e62063b4d774ac1bcf49"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.5.1"

[[Static]]
deps = ["IfElse"]
git-tree-sha1 = "2740ea27b66a41f9d213561a04573da5d3823d4b"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.2.5"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "745914ebcd610da69f3cb6bf76cb7bb83dcb8c9a"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.4"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "1958272568dc176a1d881acb797beb909c785510"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.0.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "2f6792d523d7448bbe2fec99eca9218f06cc746d"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.8"

[[StatsFuns]]
deps = ["LogExpFunctions", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "30cd8c360c54081f806b1ee14d2eecbef3c04c49"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.8"

[[SteadyStateDiffEq]]
deps = ["DiffEqBase", "DiffEqCallbacks", "LinearAlgebra", "NLsolve", "Reexport", "SciMLBase"]
git-tree-sha1 = "3df66a4a9ba477bea5cb10a3ec732bb48a2fc27d"
uuid = "9672c7b4-1e72-59bd-8a11-6ac3964bc41f"
version = "1.6.4"

[[StochasticDiffEq]]
deps = ["ArrayInterface", "DataStructures", "DiffEqBase", "DiffEqJump", "DiffEqNoiseProcess", "DocStringExtensions", "FillArrays", "FiniteDiff", "ForwardDiff", "LinearAlgebra", "Logging", "MuladdMacro", "NLsolve", "OrdinaryDiffEq", "Random", "RandomNumbers", "RecursiveArrayTools", "Reexport", "SparseArrays", "SparseDiffTools", "StaticArrays", "UnPack"]
git-tree-sha1 = "aee830c3b2c96d0e2e9fa40c5cae30d281db0dbd"
uuid = "789caeaf-c7a9-5a7d-9973-96adeb23e2a0"
version = "6.35.0"

[[StrideArraysCore]]
deps = ["ArrayInterface", "Requires", "ThreadingUtilities", "VectorizationBase"]
git-tree-sha1 = "efcdfcbb8cf91e859f61011de1621be34b550e69"
uuid = "7792a7ef-975c-4747-a70f-980b88e8d1da"
version = "0.1.13"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "000e168f5cc9aded17b6999a560b7c11dda69095"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.0"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"

[[Sundials]]
deps = ["CEnum", "DataStructures", "DiffEqBase", "Libdl", "LinearAlgebra", "Logging", "Reexport", "SparseArrays", "Sundials_jll"]
git-tree-sha1 = "4acae01957a38544ee0d00bc10c53d137c1e4439"
uuid = "c3572dad-4567-51f8-b174-8c6c989267f4"
version = "4.5.1"

[[Sundials_jll]]
deps = ["CompilerSupportLibraries_jll", "Libdl", "OpenBLAS_jll", "Pkg", "SuiteSparse_jll"]
git-tree-sha1 = "013ff4504fc1d475aa80c63b455b6b3a58767db2"
uuid = "fb77eaff-e24c-56d4-86b1-d163f2edb164"
version = "5.2.0+1"

[[Suppressor]]
git-tree-sha1 = "a819d77f31f83e5792a76081eee1ea6342ab8787"
uuid = "fd094767-a336-5f1f-9728-57cf17d0bbfb"
version = "0.2.0"

[[SymbolicUtils]]
deps = ["AbstractTrees", "ChainRulesCore", "Combinatorics", "ConstructionBase", "DataStructures", "DynamicPolynomials", "IfElse", "LabelledArrays", "LinearAlgebra", "MultivariatePolynomials", "NaNMath", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArrays", "TimerOutputs"]
git-tree-sha1 = "91659406d1c4a06bcbf074a11727dff49c35240c"
uuid = "d1185830-fcd6-423d-90d6-eec64667417b"
version = "0.13.0"

[[Symbolics]]
deps = ["ConstructionBase", "DiffRules", "Distributions", "DocStringExtensions", "DomainSets", "IfElse", "Latexify", "Libdl", "LinearAlgebra", "MacroTools", "NaNMath", "RecipesBase", "Reexport", "Requires", "RuntimeGeneratedFunctions", "SciMLBase", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArrays", "SymbolicUtils", "TreeViews"]
git-tree-sha1 = "09066de1f9d3b2e1c9cdd9d147cc20bf625c022f"
uuid = "0c5d862f-8b57-4792-8d23-62f2024744c7"
version = "1.2.1"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "8ed4a3ea724dac32670b062be3ef1c1de6773ae8"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.4.4"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[TerminalLoggers]]
deps = ["LeftChildRightSiblingTrees", "Logging", "Markdown", "Printf", "ProgressLogging", "UUIDs"]
git-tree-sha1 = "d620a061cb2a56930b52bdf5cf908a5c4fa8e76a"
uuid = "5d786b92-1e48-4d6f-9151-6b4477ca9bed"
version = "0.1.4"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[ThreadingUtilities]]
deps = ["VectorizationBase"]
git-tree-sha1 = "28f4295cd761ce98db2b5f8c1fe6e5c89561efbe"
uuid = "8290d209-cae3-49c0-8002-c8c24d57dab5"
version = "0.4.4"

[[TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "9f494bc54b4c31404a9eff449235836615929de1"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.10"

[[Tokenize]]
git-tree-sha1 = "37018506dc445ad7db288442fbb846105f26c43f"
uuid = "0796e94c-ce3b-5d07-9a54-7f471281c624"
version = "0.5.17"

[[TreeViews]]
deps = ["Test"]
git-tree-sha1 = "8d0d7a3fe2f30d6a7f833a5f19f7c7a5b396eae6"
uuid = "a2a6695c-b41b-5b7d-aed9-dbfdeacea5d7"
version = "0.3.0"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[Unitful]]
deps = ["ConstructionBase", "Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "b3682a0559219355f1e3c8024e9f97adce2d4623"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.8.0"

[[UnitfulAngles]]
deps = ["Dates", "Unitful"]
git-tree-sha1 = "dd21b5420bf6e9b76a8c6e56fb575319e7b1f895"
uuid = "6fb2a4bd-7999-5318-a3b2-8ad61056cd98"
version = "0.6.1"

[[UnitfulAstro]]
deps = ["Unitful", "UnitfulAngles"]
git-tree-sha1 = "b154be4ca9610e9c9dbb9dba98b2bd750539630b"
uuid = "6112ee07-acf9-5e0f-b108-d242c714bf9f"
version = "1.0.1"

[[VectorizationBase]]
deps = ["ArrayInterface", "Hwloc", "IfElse", "Libdl", "LinearAlgebra", "Static"]
git-tree-sha1 = "0ba060e248edfacacafd764926cdd6de51af1343"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.20.19"

[[VertexSafeGraphs]]
deps = ["LightGraphs"]
git-tree-sha1 = "b9b450c99a3ca1cc1c6836f560d8d887bcbe356e"
uuid = "19fa3120-7c27-5ec5-8db8-b0b0aa330d6f"
version = "0.1.2"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll"]
git-tree-sha1 = "2839f1c1296940218e35df0bbb220f2a79686670"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.18.0+4"

[[WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "59e2ad8fd1591ea019a5259bd012d7aee15f995c"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.3"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[ZygoteRules]]
deps = ["MacroTools"]
git-tree-sha1 = "9e7a1e8ca60b742e508a315c17eef5211e7fbfd7"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.1"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "acc685bcf777b2202a904cdcb49ad34c2fa1880c"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.14.0+4"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7a5780a0d9c6864184b3a2eeeb833a0c871f00ab"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "0.1.6+4"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "c45f4e40e7aafe9d086379e5578947ec8b95a8fb"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+0"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d713c1ce4deac133e3334ee12f4adff07f81778f"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2020.7.14+2"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "487da2f8f2f0c8ee0e83f39d13037d6bbf0a45ab"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.0.0+3"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─d59d8616-a224-11eb-043c-d1f9fbaa616e
# ╟─af8b6ac7-7391-4662-adec-01ca03d94a30
# ╟─684c3b78-a47c-4fba-9a80-e6a07bc5e799
# ╠═afa41959-dbee-4e81-97a6-1717f476dd77
# ╠═267edd09-82ea-4cf9-92e8-f871ac4f0f5c
# ╠═46d550bc-713e-43af-8b2e-8ffa65d0e600
# ╟─3813dffe-54fb-48a1-a5fb-9a6c81ed1ad7
# ╟─50ee947b-7df3-4de6-9223-08bc1bd9398d
# ╟─0e8c29c8-32d0-4b2b-aa20-e947cf36389c
# ╟─de2eb7a9-3d36-42c0-b12a-f7f2303692f3
# ╟─272d58f1-4d59-4243-8de3-326b02d4628a
# ╠═72492b56-30f3-44ad-81ff-1b59fced5d47
# ╟─c761130f-88e5-4375-abba-9b196c9b0a27
# ╟─dd9efeb6-359a-428b-b2be-93f7a3735734
# ╠═507a6e8c-52e2-4223-befc-82ad631af446
# ╠═2319c22e-4417-4c0a-9b0b-b951a8bf58f4
# ╟─b489caad-6f05-4e1f-88a9-3c008e4ba98c
# ╟─a4538dea-2e55-42c6-8573-e77c75607e7c
# ╠═fb847908-ee98-447e-ae03-23afd0b9d9e4
# ╟─8786e7d8-9d78-4b7c-bd19-d221a471a32a
# ╠═c850a977-9fab-4014-8887-6667e64e079a
# ╠═bd964ca0-534b-46b8-8538-d582186c1f94
# ╠═88d150e7-609c-4a5f-a0fc-48cbae74b10b
# ╟─da51983c-d826-4ac3-a38c-51b9e6444f79
# ╟─36b46ffb-bcb0-43d4-a08b-fd8c9dda185f
# ╟─8c772140-a05c-47cb-aac5-2149a28fc151
# ╟─0929f835-bef5-462b-9477-c95f70dcd2ba
# ╟─2b852e42-915f-4088-89c1-bf5436384b13
# ╠═a9092c8c-b3b2-4608-99c3-8cc73d7816f3
# ╟─39b25fb5-89c0-46aa-b521-de42989a942c
# ╠═6bae2db8-3ba3-46aa-b65b-a75ca21a3d05
# ╟─3fc0b719-850f-481c-935d-ca4af12a6c53
# ╠═286dad18-e175-4eae-91e7-667f6a6d944e
# ╟─f8d40fa2-73f1-4a3d-b081-846324f10e38
# ╟─9e5cd21c-23ac-4cf1-97f6-48b1647e7359
# ╠═a0739712-bd5b-49b0-a9ae-9da5bac7c345
# ╟─35b796d2-2780-4190-b8d6-5d507083cc38
# ╟─1444c267-8f14-4194-a2af-031f406d90fd
# ╠═715dd0bb-cb36-4bab-b53e-bdbeb2ed8d51
# ╟─7d2894c5-5670-42da-9225-34d29583fd74
# ╟─25158dd7-ee8f-4781-8c6d-a8b1c9bbe657
# ╠═6ad80a71-fbd2-42e9-8254-a85f2c6ee228
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
