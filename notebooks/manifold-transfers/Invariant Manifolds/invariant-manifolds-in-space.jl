### A Pluto.jl notebook ###
# v0.16.1

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

# ╔═╡ f4e67586-4fdd-4fa3-9b55-5174345cb5eb
begin
	
	using Lazy
	using Optim
	using LazySets
	using Markdown
	using Rotations
	using StaticArrays
	using LinearAlgebra
	using GalacticOptim
	using BlackBoxOptim
	using ReachabilityAnalysis
	using GeneralAstrodynamics
	using AstrodynamicalModels
	using DifferentialEquations
	using Unitful, UnitfulAstro
	using Plots, PlutoUI, Latexify
	
	# We want the `system` and `frame` functions from GeneralAstrodynamics
	system = GeneralAstrodynamics.system
	frame  = GeneralAstrodynamics.frame
	
	# We want the `OptimizationProblem` function from GalacticOptim
	OptimizationProblem = GalacticOptim.OptimizationProblem
	
	# I need to make a `withstm` function...
	withstm(orbit::CR3BPOrbit) = Orbit(
		CartesianStateWithSTM(state(orbit)),
		system(orbit),
		epoch(orbit);
		frame = frame(orbit)
	)
	
	# Is the provided Halo orbit valid?
	validhalo(H) = !isnan(H.period) && H.period ≥ 1
	
end;

# ╔═╡ 243ac0ae-0e77-11ec-3472-a75caee1ed6d
md"""
# 🪐 Manifold Transfers
_Exploring invariant manifolds within CR3BP dynamics for low-cost interplanetary transfer designs._

__Author: Joe Carpinelli__

!!! note
	This is an informal notebook used for exploring different calculations, and succinctly explaining the underlying methodolgies! Some words written here may appear again in formal papers. For more information and content, see [cadojo/CR3BP-Manifold-Research](https://github.com/cadojo/CR3BP-Manifold-Research) on GitHub.

!!! warning
	If you're running this notebook (e.g. not reading a PDF or HTML copy), then all code may take several minutes to finish running!
 $(PlutoUI.TableOfContents(; title="📖 Table of Contents", depth=2))
"""

# ╔═╡ ae686dd1-983d-44dd-87cf-2c508f24f35c
md"""
## _Abstract_
_A formal introduction to this document._

While the definition of Circular Restricted Three-body Problem (CR3BP) dynamics may seem arbitrary, the case of two celestial bodies circularly orbiting their common center of mass can be a surprisingly accurate model for astrodynamical systems of interest in our solar system. For this reason, behaviors described by CR3BP dynamics may be used for early analysis, and mission planning for human activity in space. Two such behaviors described by CR3BP dynamics are particularly relevant for future space science and exploration missions: periodic orbits about equilibrium positions, and invariant manifolds about those periodic orbits. Periodic orbits are useful for mission continuity throughout space science missions, and allow for desirable orbital traits such as eclipse avoidance. Invariant manifolds, which converge to and diverge from these periodic orbits, can allow for low-cost travel within a CR3BP system, and by using CR3BP patched-conic approximations, can also allow for low-cost travel throughout our solar system. Existing periodic-orbit-finding algorithms, and manifold calculations will be discussed, as will their direct applications in an example space mission context: a low-cost transfer from Earth to Jupiter.

"""

# ╔═╡ 31126436-f264-499f-904f-ff63a5507cfc
md"""
## Introduction
_An informal introduction to this document._

Now that the formal abstract is out of the way, let's introduce manifold-based transfer designs with less jargon. In all technical fields, we (humans) make simplifying assumptions to _approximately_ describe reality with models. Reality is far too complex to _perfectly_ describe the motion of a body in our solar system! For this reason, astrodynamicists have developed several sets of equations of motion, each with their own simplifying assumptions, benefits, and detriments. Each set of equations of motion may be called a __model__.

!!! tip "Definition"
	__Model__ – a set of equations of motion which approximately decribe reality, with some defined simplifying assumptions.

One such simplified model is known as the Circular Restricted Three-body Problem (CR3BP). This model has __several__ assumptions, and if these assumptions are not _approximately_ true, then the model is not accurate enough to be useful. Each assumption is listed below, with the equations of motion for this model following.

### CR3BP Assumptions

* The spacecraft is only affected by the gravity of __two__ celestial bodies 
* Both celestial bodies orbit their common center of mass in a circular motion (in the inertial frame centered at their common center of mass)
* The spacecraft's mass is negligably small when compared with the masses of the two celestial bodies (note this condition holds for planets, stars, and most moons, but does not hold for small asteroids)

### CR3BP Equations of Motion

The equations of motion are shown below. Note that one additional caveat must be stated before we can use these equations – all spacecraft states are __normalized__, and described by a __rotating reference frame__ often known as the __synodic frame__. 

Let's focus on the synodic frame first. The spacecraft's state is simply the spacecraft's position and velocity, described by some coordinate frame. The equations below assume the spacecraft's state is described by a coordinate frame which is centered at the center of mass of the system (identically, the center of mass of the two celestial bodies), and which __rotates__ at the same rate as the two celestial bodies' orbits about their common center of mass. In other words, all $\left[x, y, z, \dot{x}, \dot{y}, \dot{z}\right]$ values are described with respect to a rotating reference frame placed at the center of mass of the system.

The spacecraft's state must also be __normalized__ for the equations below to hold. The normalized units are simple: all lengths are described as scalar multiples of the distance between the celestial bodies, and all times are described as scalar multiples of the orbital period of the two celestial bodies. Put simply – take each spacecraft's position and velocity with respect to the center of mass of the system, divide the position by the distance between the celestial bodies, and divide the velocity by the same distance and multiply that result by the orbital period of the celestial bodies. 

With all of these assumptions and caveats defined – behold! The equations of motion for a spacecraft in the Circular Restricted Three-body Problem, courtesy of `ModelingToolkit.jl` and `AstrodynamicalModels.jl`.
"""

# ╔═╡ abd7be96-0340-4ec4-a277-eb05cadbbb8a
CR3BP |> equations .|> simplify |> latexify

# ╔═╡ 6a41abea-df8e-4d81-bbe0-219dbf7c3156
md"""
## Periodic Orbits
_How can we find them?_

Periodic orbits are desirable for applications in human space missions, and therefore algorithms have been developed to find periodic orbits within CR3BP dynamics. An analytical algorithm was developed by [Richardson](https://link.springer.com/article/10.1007/BF01229511) – this algorithm expands the dynamics to the third order, and provides an analytical approximation for periodic initial conditions. These initial conditions are __not__ yet numerically periodic, though. These analytical approximations may be used as an initial guess, but the guess must be refined, as with an [iterative numerical solver](http://cosweb1.fau.edu/~jmirelesjames/hw5Notes.pdf) as described by Dr. Mireles at FSU.

Each algorithm is described in more detail in the following sub-sections.

"""

# ╔═╡ 8662f0e5-8c74-4d96-ab45-73099ba3609f
md"""
### Richardson's Analytical Solution

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

__The analytical algorithm can return the orbital period, positions, and velocities.__ More detail about this algorithm are provided in many reference texts, including a [free textbook](http://www.cds.caltech.edu/~marsden/volume/missiondesign/KoLoMaRo_DMissionBk.pdf) authored by Koon et al. In particular, equations to describe the parameters $c_1$ through $c_4$ are succinctly described by [Rund's Masters Thesis](http://www.cds.caltech.edu/~marsden/volume/missiondesign/KoLoMaRo_DMissionBk.pdf). The algorithm is implemented by the `analyticalhalo` function in `GeneralAstrodynamics`.

Recall that this analytical solution is not numerically periodic! The code and accompanying plot below illustrate this point.

"""

# ╔═╡ cdab4e44-ec01-49ad-b30b-32f6f7ed3d72
let sys = EarthMoon, Az = 0.04, L = 1
	
	# Analytical trajectory
	r, v, T = analyticalhalo(
		massparameter(sys); 
		Az    = Az, 
		steps = 1000, 
		L     = L
	)
		
	# Analytical trajectory plot
	figure = let x = r[:,1], y=r[:,2], z=r[:,3]
		plot(x,y,z; lw=2, label="Analytical Solution")
	end

	# Construct an `Orbit` with the initial state
	orbit = let 
		state = CartesianState(
			r[1,:], v[1,:]; 
			lengthunit  = lengthunit(sys), 
			timeunit    = timeunit(sys), 
			angularunit = angularunit(sys)
		)
		
		Orbit(state, sys)
	end

	# Propagate the initial condition in time
	trajectory = propagate(orbit, T)
	
	# Propagated trajectory plot
	plot!(trajectory; lw = 2, label = "Numerical Propagation")
	
	# Add labels
	plot!(; 
		title  = "Halo Orbits about Earth-Moon L1", 
		xlabel = "X $(lengthunit(sys))",
		ylabel = "Y $(lengthunit(sys))",
		zlabel = "Z $(lengthunit(sys))"
	)
	
	# Show the plot to the world
	figure
	
end

# ╔═╡ 3f953f28-b48c-4342-ace8-9156f7489ddc
md"""
### Mireles' Modified Numerical Algorithm

As shown above, the analytical solution gives us a solution which is _close_ to a periodic solution. We need to refine this initial guess! A rough procedure for iterating on an initial guess for a periodic orbit is described below. As mentioned previously, [Mireles' publicly available notes](http://cosweb1.fau.edu/~jmirelesjames/hw5Notes.pdf) are an excellent resource for further studying this algorithm. This algorithm is implemented by the `halo` function in `GeneralAstrodynamics`.

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
	You can't just _choose_ whatever corrector you want! If you're solving for a Lyapunov orbit $\left(z \equiv 0\right)$ then the $3\times3$ matrix will be singular (second row) if you choose equation $\left(1\right)$. In practive, consider a switch statement – if your desired $z$-axis ampltitude is $0$, then use $\left(2\right)$, and otherwise use $\left(1\right)$.
"""


# ╔═╡ 270303d8-fbfa-493e-82da-4f6adcf7f9bb
md"""

## Invariant Manifolds

In previous sections, we discussed how to find periodic orbits within CR3BP dynamics. Recall, this is the __first__ dynamical behavior which is relevant to space mission designs! The __second__ dynamical behavior which was previously introduced is the existance of __invariant manifolds__ which converge to, and diverge from all periodic orbits within the CR3BP dynamics. 

While the term _manifold_ is mathematically accurate, a simpler definition exists: each manifold is simply a __tube of trajectories__ in space which approach or depart from a periodic orbit. We can find these trajectories by perturbing our spacecraft off of the orbit in specific directions. These directions are defined by the real-valued eigenvectors of the __local linearization__ of the spacecraft's state at any point along the periodic orbit. That's a mouthful, so let's back up a bit.

!!! tip "Definition"
	__Manifold__ – in an astrodynamical context, a manifold is a tube of trajectories in space.

The equations of motion for a spacecraft in the CR3BP model have been previously shown. These equations are nonlinear! We can _linearize_ these equations by calculating a matrix of partial derivatives, with each each equation mapping to each row, and each partial derivative mapping to each column. The result is known as the Jacobian – in this case, the Jacobian of the spacecraft's state vector is a $6\times6$ matrix. The analytical expression for the Jacobian is provided below, courtesy of `ModelingToolkit` and `AstrodynamicalModels`.


"""

# ╔═╡ c9fff891-3101-4aec-bbc1-ce8ff4f110c9
CR3BP |> calculate_jacobian .|> simplify |> latexify

# ╔═╡ d5f69f3a-5113-4110-90e6-51f0d6d0ff4f
md"""
If we evaluate this Jacobian at the spacecraft's current state, we are left with a numerical matrix which describes the spacecraft's local linearization at that state. We can take advantage of common linear analysis techniques to determine which directions our spacecraft must be perturbed to be placed on an invariant manifold. This linear analysis technique is simple – we calculate the eigenvalues and eigenvectors of the local linearization, and note the two real-valued eigenvalue-eigenvector pairs. The eigenvector associated with the larger eigenvalue is the direction the spacecraft must be perturbed to arrive on the __unstable manifold__ near the periodic orbit. This tube of trajectories __diverges from__ the orbit. The eigenvector associated with the smaller eigenvalue is the direction the spacecraft must be perturbed to arrive on the __stable manifold__. This manifold __converges to__ the orbit. Note that in order to visualize a stable manifold, you'll need to propagate the dynamics __backwards in time__.

There's one (minor) problem with this approach, however. Calculating eigenvalues and eigenvectors of the local linearization can be computationally expensive! To accomplish the same manifold calculations with fewer CPU cycles, we can use a mathematical trick – instead of calculating the eigenvalues and eigenvectors of each local linearization, we can calculate the eigenvalues and eigenvectors of the __Monodromy Matrix__. We can then left-multiply the stable and unstable eigenvectors of the Monodromy Matrix by the local linearization of the spacecraft's state to find the direction of stable and unstable manifolds at each point along the periodic orbit.

The Monodromy Matrix is defined as the local linearization of the spacecraft after it travels for __one orbital period__. This calculation is implemented by the `monodromy` function in `GeneralAstrodynamics`. More information about the Monodromy Matrix can be found in [Vallado's Fundamentals of Astrodynamics and Applications](https://arc.aiaa.org/doi/abs/10.2514/2.4291?journalCode=jgcd). A rough procedure for calculating the Monodromy Matrix is described below.

1. Construct a $42$ element state vector for your periodic orbit, which includes the traditional $6$ position and velocity elements, and all $36$ elements of a $6\times6$ __state transition matrix__, which is initialized to the identity matrix.
2. Propagate the state vector for one orbital period. The equations of motion for the state transition matrix are simply $\dot{\Phi} = J \Phi$, where $J$ is the local linearization of the spacecraft, and $\Phi$ is the state transition matrix.
3. The state transition matrix at the final time point is equivalent to the Mondromy Matrix!

A symbolic representation of the Monodromy Matrix is shown below, once again, courtesy of `ModelingToolkit.jl` and `AstrodynamicalModels.jl`! 😁
"""

# ╔═╡ 4cd20c37-97ec-4a1f-aa60-b138605c7c95
CR3BP |> calculate_jacobian .|> simplify |> latexify

# ╔═╡ d6bea59b-d8d3-49c5-9296-b77969b984c9
md"""

Once the Monodromy Matrix is calculated, the local linearization of every point along a periodic orbit can be applied (read, left-multiplied) to the stable ($V^S$) or unstable ($V^U$) eigenvector of the Monodromy Matrix to find the _direction_ of the stable or unstable manifold at that point. A small perturbation amplitude $\epsilon$ is used to control the magnitude of the perturbation. The equations below calculate the stable and unstable manifolds of a periodic orbit within CR3BP dynamics. Note that superscript $S$ denotes the stable direction in state space, the the superscript $U$ denotes the unstable direction. The subscript $i$ may be read as "at time $i$". The state transition matrix at time $i$ is labeled $\Phi(t_0 + t_i, t_0)$. 

$\begin{align}
	V_i^{S} &= \Phi(t_0 + t_i, t_0) V^S \\
    V_i^{U} &= \Phi(t_0 + t_i, t_0) V^U \\
    X_i^{S} &= X_i \pm \epsilon \frac{V_i^S}{|V_i^S|} \\
    X_i^{U} &= X_i \pm \epsilon \frac{V_i^U}{|V_i^U|} \\
\end{align}$

These calculations have been implemented in the `manifold` function in `GeneralAstrodynamics`. All that's required are a periodic orbit, and the orbit's period. Other inputs, including the number of trajectories within the manifold to calculate, are optional keyword arguments. 

An example periodic orbit, stable manifold, and unstable manifold are shown in a visualization below. The stable manifold, which converges to the periodic orbit shown in black, is plotted in blue. The unstable manifold is plotted in red. Earth's center of mass is shown in green – note that the some trajectories in the stable manifold get __very__ close! This indicates we may be able to launch a spacecraft directly from Earth, onto the stable manifold of a nearby periodic orbit.

"""

# ╔═╡ 4d71c69d-95b4-40ca-ac39-1cbd61ba491a
let sys = SunEarth, Az = 250_000u"km", L = 2
	
	# Calculate a periodic orbit
	orbit, T = halo(sys; Az = Az, L = L)
	
	# Calculate a stable manifold which converges
	# to this periodic orbit
	stable = manifold(
		orbit, T; 
		direction    = Val{:stable}, 
		duration 	 = 1.7T,
		trajectories = 25, 
		eps          = -1e-7
	)
	
	# Calculate an unstable manifold which diverges
	# from this periodic orbit
	unstable = manifold(
		orbit, T;
		direction    = Val{:unstable},
		duration 	 = 1.7T,
		trajectories = 25,
		eps 		 = -1e-7
	)
	
	# Visualize the stable manifold
	plot(
		stable; 
		vars      = :XY, 
		palette   = :blues,
		dpi       = 250, 
		linestyle = :dash
	)
	
	# Visualize the unstable manifold
	plot!(
		unstable; 
		vars      = :XY, 
		palette   = :reds, 
		dpi       = 250, 
		linestyle = :dash)
	
	# Visualize the periodic orbit
	let trajectory = propagate(orbit, T; abstol=1e-16)
		plot!(
			trajectory; 
			label        = "Halo Orbit", 
			vars         = :XY, 
			linewidth    = 6, 
			color        = :black, 
			aspect_ratio = 1,
			dpi 		 = 250
		)
	end
	
	# Let's plot Earth!
	let μ = massparameter(sys)
		scatter!(
			[1-μ], [0]; 
			markersize  = 7, 
			markercolor = :green, 
			label       = "Earth Center of Mass"
		)
	end
	
	# Finally, some plot cleanup
	plot!(; 
		title  = "Stable and Unstable Manifolds near Earth", 
		legend = :bottomleft 
	)
	
end

# ╔═╡ c293ea93-4b76-47b3-8a06-656d2d8ad85c
md"""
## Super-highways in Space
_How can we use invariant manifolds to travel throughout our solar system?_

Previous research, including Rund's [Masters Thesis](https://digitalcommons.calpoly.edu/theses/1853/), has shown that invariant manifolds can be used for low-cost interplanetary transfer designs. But how can we use these manifolds for interplanetary transfers?

You may have noticed something about the above visualization – trajectories move from Earth onto a periodic orbit, and then other trajectories move from the periodic orbit out away from Earth. In fact, we can show that some trajectories escape the CR3BP system altogether, and travel out into interplanetary space; if those trajectories __intersect__ with the stable manifold of _another_ CR3BP system, then we may apply an impulsive maneuver at the intersection to change the velocity of our spacecraft, and follow the stable manifold trajectory onto a periodic orbit in our desired destination system. 

Let's use the Sun-Jupiter system as an example. Say we'd like to leave Earth, and arrive at Jupiter. Let's assume we can launch from Earth onto a stable manifold of a Sun-Earth periodic orbit – this mean's that after we launch, we can take our proverbial foot of the gas! Eventually, our spacecraft will converge onto the chosen periodic orbit near Earth. We can then apply a small perturbation to transfer our spacecraft onto the periodic orbit's unstable manifold. If we choose our perturbation amplitude, and Sun-Earth periodic orbit correctly, then our spacecraft will be carried out into interplanetary space on the periodic orbit's unstable manifold. 

If the unstable manifold of our chosen Sun-Earth orbit (shown in red in the plot below) intersects with the stable manifold of our chosen Sun-Jupiter orbit (shown in blue), then all we need to do is apply a velocity change at the intersection (commonly referred to as an "impulsive manuever") to transfer our spacecraft onto the stable manifold of our destination system. Once again, we can "take our foot off the gas" – the spacecraft will be carried by the Sun-Jupiter stable manifold onto our chosen periodic orbit near Jupiter.

This approach may be called a "CR3BP patched-conics" method – we are turning the dynamics of the Sun-Earth and Sun-Jupiter systems "on" and "off" as appropriate to approximate the spacecraft's motion throughout our solar system. Of course, in reality, there will be uncertainties in vehicle performance, and other dynamical perturbations which kick our spacecraft slightly off-course. This patched-conics approach simply serves as a quick analysis to see where some useful trajectories throughout our solar system lie. 
"""

# ╔═╡ 60b13469-ef77-4df5-9080-d75d768f1195

let 
	
	# Start near Earth
	O₁, T₁ = halo(
		SunEarth; 
		Az = 50_000u"km", 
		L  = 2
	)
	
	# And end up near Jupiter
	O₂, T₂ = halo(
		SunJupiter; 
		Az = 100_000u"km", 
		L  = 1
	)
	
	# Calculate the unstable manifold, which will carry our 
	# spacecraft into interplanetary space
	M₁ = manifold(
		O₁, T₁; 
		direction    = Val{:unstable}, 
		duration     = 2T₁,
		eps          = 1e-7,
		aspect_ratio = 1
	)
	
	# Calculate the stable manifold, which will carry our
	# spacecraft onto a periodic orbit near Jupiter
	M₂ = manifold(
		O₂, T₂; 
		direction    = Val{:stable}, 
		duration     = 2T₁,
		eps          = 1e-7,
		aspect_ratio = 1
	)
	
	# Plot both manifolds as subplots
	P₁ = plot(
		M₁; vars = :XY, palette = :reds,  
		dpi = 250, title = "Depart Earth"
	)
	P₂ = plot(
		M₂; vars = :XY, palette = :blues, 
		dpi = 250, title = "Arrive at Jupiter"
	)
	plot(P₁, P₂; layout=(2,1))
	
end

# ╔═╡ a9776dd4-a461-402f-a6cb-9a92c27122fc
md"""
## Coordinate Frames
_Positions and velocities with respect to what?_

Up until this point, all visualizations and descriptions have been shown in the __Synodic__ reference frame. As previously defined, the Synodic is a rotating reference frame which coincides with the center of mass of the system. If we want to find the intersection of two manifolds, each described in their own Synodic reference frames, then we'll need to apply a coordinate transformation to relate both manifolds in the same reference frame! 

That's where the following `CR3BPtoR2BP` function comes in. This function transforms a state described in a CR3BP Synodic reference frame to a state in a Heliocentric Inertial (a R2BP) reference frame. 
"""

# ╔═╡ 2aff66ca-1504-465b-bf40-93c777432800
"""
Converts a CR3BP orbit to a R2BP orbit.
"""
function CR3BPtoR2BP(orbit::CR3BPOrbit, body_index::Int, body::R2BPParameters; 
					 inclination = 0u"°")

	@assert body_index ∈ (1,2) "Second argument must be 1 or 2."

	# Spacecraft state (Synodic, normalized)
	rₛ = state(orbit).r
	vₛ = state(orbit).v
	DU = lengthunit(orbit)
	TU = timeunit(orbit)
	μ  = massparameter(system(orbit))
	
	# Body state (Synodic, normalized)
	rᵢ = body_index == 1 ? MVector(-μ, 0, 0) : MVector(1-μ, 0, 0)	   
	
	# Synodic to bodycentric inertial
	Rz(θ) = transpose(RotZ(θ)) # produces [cθ sθ 0; -sθ cθ 0; 0 0 1]
	rₛ = Rz(ustrip(TU)) * (rₛ - rᵢ)
	vₛ = Rz(ustrip(TU)) * (vₛ + MVector{3}(0,0,1) × rᵢ)
	
	# Canonical to dimensioned
	rₛ = rₛ .* DU
	vₛ = vₛ .* DU/TU
	
	# Rotate about x by the inclination angle i
	Rx(θ) = transpose(RotX(θ)) # produces [1 0 0; 0 cθ sθ; 0 -sθ cθ]
	rₛ = Rx(inclination) * rₛ
	vₛ = Rx(inclination) * vₛ
	
	# Cartesian state
	cart = CartesianState(
		uconvert.(u"km", rₛ), 
		uconvert.(u"km/s", vₛ)
	)
	
	# Orbit structure
	return Orbit(cart, body, epoch(orbit))
	
end;

# ╔═╡ c5239fb2-c92e-422f-a32b-1ea604b21cc2
md"""
Let's also make a method for raw vectors, as opposed to `Orbit` instances.
"""

# ╔═╡ ca0e7686-df99-4e74-8d77-de9fdee68ba7
"""
Converts a CR3BP orbit to a R2BP orbit.
"""
function CR3BPtoR2BP(r, v, μ, DU, TU, body_index, body::R2BPParameters; 
					 inclination = 0u"°")

	@assert body_index ∈ (1,2) "Second argument must be 1 or 2."

	# Body state (Synodic, normalized)
	rᵢ = body_index == 1 ? MVector(-μ, 0, 0) : MVector(1-μ, 0, 0)	   
	
	# Synodic to bodycentric inertial
	Rz(θ) = transpose(RotZ(θ)) # produces [cθ sθ 0; -sθ cθ 0; 0 0 1]
	rₛ = Rz(ustrip(TU)) * (r - rᵢ)
	vₛ = Rz(ustrip(TU)) * (v + MVector{3}(0,0,1) × rᵢ)
	
	# Canonical to dimensioned
	rₛ = rₛ .* DU
	vₛ = vₛ .* DU/TU
	
	# Rotate about x by the inclination angle i
	Rx(θ) = transpose(RotX(θ)) # produces [1 0 0; 0 cθ sθ; 0 -sθ cθ]
	rₛ = Rx(inclination) * rₛ
	vₛ = Rx(inclination) * vₛ
	
	# Cartesian state
	cart = CartesianState(
		uconvert.(u"km", rₛ), 
		uconvert.(u"km/s", vₛ)
	)
	
	# Orbit structure
	return Orbit(cart, body)
	
end;

# ╔═╡ e20e3843-8a32-4d44-95af-3f5a5135d7c8
md"""
## Mission Designs

Let's assume we can launch our spacecraft _from_ Earth _into_ a stable manifold of a periodic orbit about Sun-Earth L2. We know that we can then perturb our spacecraft off of the periodic orbit, _onto_ the orbit's unstable manifold, to kick our spacecraft out into interplanetary space. 

Once we're traveling along the Sun-Earth unstable manifold, where can we travel to throughout our solar system? Some examples are shown below. Click through to see various mission designs! Note that all units are system-normalized. A value for the departure system is **not** necessarily the same units as the arrival system!

|Mission Phase|CR3BP System|Halo Amplitude|Lagrange Point|Perturbation Amplitude (×10⁻⁸)|Manifold Duration|
|---|---|---|---|---|---|
|**Depature**|$(@bind S₁ Select(["Sun-Earth", "Sun-Mars", "Sun-Jupiter"]))|$(@bind A₁ NumberField(0.00 : 0.00025 : 0.0075; default=0.005))|$(@bind L₁ Select(["1"=>"L1","2"=>"L2"]; default="2"))|$(@bind ϵ₁ NumberField(-1000:1000; default=100))|$(@bind T₁ NumberField(1:100; default=5))|
|**Arrival**|$(@bind S₂ Select(["Sun-Earth", "Sun-Mars", "Sun-Jupiter"]; default="Sun-Jupiter"))|$(@bind A₂ NumberField(0.00 : 0.0001 : 0.0075; default=0.005))|$(@bind L₂ Select(["1"=>"L1","2"=>"L2"]))|$(@bind ϵ₂ NumberField(-1000:1000; default=-100))|$(@bind T₂ NumberField(1:100; default=5))|

The results from your inputs above are shown below. Do the departure and arrival manifolds get close to one another? If you tweak parameters, can you get them to intersect (in the XY plane)?


"""

# ╔═╡ 7ff01084-f500-46ba-ae75-68a5a20199c6
md"""
### Orbit Constructors
"""

# ╔═╡ 50982260-3e11-489d-8659-92f9f16dc8b4
md"""
##### Departure Halo
"""

# ╔═╡ db3addaf-89ab-44a8-865d-a9c6b96ef529
H₁ = let L₁ = parse(Int, L₁), S₁ = eval(Symbol(replace(S₁, "-"=>"")))
	
	halo(S₁; Az = A₁, L = L₁)
	
end;

# ╔═╡ 7b4c0e2a-1b2c-4da1-93a2-0a6d0d72b2bf
md"""
##### Arrival Halo
"""

# ╔═╡ 5b4187f1-6a3f-46f5-93c1-603cfd670cd3
H₂ = let L₂ = parse(Int, L₂), S₂ = eval(Symbol(replace(S₂, "-"=>"")))
	
	halo(S₂; Az = A₂, L = L₂)
	
end;

# ╔═╡ 836e4188-851a-4a7c-be7b-39ceaf45954c
md"""
### Manifold Constructors
"""

# ╔═╡ b3d059b7-a1a4-4023-83bb-d2ace7f1d399
md"""
##### Departure Manifold
"""

# ╔═╡ 91e3b0ec-ad90-4acf-b622-1e6b8450054f
if validhalo(H₁)
	M₁ = let ϵ₁ = ϵ₁ * 1e-8
	
		orbit, period = H₁
		traj = propagate(withstm(orbit), period; saveat=period/10)
		manifold(traj; eps = ϵ₁, duration = T₁ * period)
	
	end
end;

# ╔═╡ 85da49f7-fddf-4b8e-98f2-1cddea80c340
md"""
##### Arrival Manifold
"""

# ╔═╡ 4b06ade4-11e5-4e84-a954-e7a78275bd3b
if validhalo(H₂)
	M₂ = let ϵ₂ = ϵ₂ * 1e-8

		orbit, period = H₂
		traj = propagate(withstm(orbit), period; saveat=period/10)
		manifold(traj; eps = ϵ₂, duration = T₂ * period)

	end
end;

# ╔═╡ ae4e6317-793d-4f14-8e33-f7880948bb12
md"""
### Synodic to HCI Transformations
"""

# ╔═╡ 4c66e648-174a-47a2-a77c-f67d7173eaaa
md"""
##### Departure Manifold (HCI)
"""

# ╔═╡ 65d5c1a8-d268-44b3-a611-7d79723ad9ab
if validhalo(H₁)
	ˢM₁ = [
		map(t -> CR3BPtoR2BP(Orbit(traj, t), 1, Sun), traj.solution.t)
		for traj ∈ M₁.solution
	]
end;

# ╔═╡ 4c243d99-17e8-45cf-b887-f89f8b221107
md"""
##### Arrival Manifold (HCI)
"""

# ╔═╡ 9be51126-bd53-4112-8f59-5bd023a8f522
if validhalo(H₂)
	ˢM₂ = [
		map(t -> CR3BPtoR2BP(Orbit(traj, t), 1, Sun), traj.solution.t)
		for traj ∈ M₂.solution
	]
end;

# ╔═╡ 234fbfdb-4f87-4a6d-b887-c603b112e82e
if !validhalo(H₁)
	md"""
	!!! danger "Invalid Departure Halo Orbit"
		Your departure halo orbit has a period that is far too
		small to be a valid periodic orbit! Try setting another departure orbit 
		amplitude.
	"""
elseif !validhalo(H₂)
	md"""
	!!! danger "Invalid Arrival Halo Orbit"
		Your arrival halo orbit has a period that is far too
		small to be a valid periodic orbit! Try setting another arrival orbit 
		amplitude.
	"""
else
	
	figure = plot()
	
	for T ∈ ˢM₁
		plot!(figure, T, vars=:XY, palette=:blues)
	end
	
	for T ∈ ˢM₂
		plot!(figure, T, vars=:XY, palette=:reds)
	end
	
	
	plot!(figure,  title = "$S₁ L$L₁ to $S₂ L$L₂")
end

# ╔═╡ 4aba4714-4bce-46f9-9e51-81397042c2ec
md"""
# 🧪 Experiments

This section is incomplete by design! Some analysis may be present in a subsection, but the methods may not be explained completely, or at all. This is really just a scratch space for trying out different methods for computing the intersection of two manifolds.

One interesting method is Reachability Analysis. It seems promising! At the very least, it would be interesting to follow up on. 

"""

# ╔═╡ 467b8efe-6009-4f8e-bcaf-3f795ac98694
md"""
## Reachability Analysis
"""

# ╔═╡ 8101681a-771f-44e7-ae20-4fc77cb92bf5
md"""
In order to perform reachability analysis with these dynamics, we'll need to _symbolically_ transform CR3BP dynamics to the Heliocentric Inertial reference frame. That's a lot, especially with the manifold perturbation dynamics. It's definitely possible, but for now, let's just look at one manifold.
"""

# ╔═╡ 6481c3f5-30e7-44bb-8764-061b618e1460
md"""
### Formal Reachability
"""

# ╔═╡ fba1fba4-8e88-4064-9c9a-48b2c055b035
let # this is Marcelo Forret's code from Discourse!
	
	LazySets.set_ztol(Float64, 1e-14) # for plots

	@taylorize function f!(du, u, p, t)
		local μ = 3.003480593992993e-6

		x, y, z, vx, vy, vz = u

		du[1] = vx
		du[2] = vy
		du[3] = vz

		aux0 = sqrt(y^2 + z^2 + (x + μ - 1)^2)^-3
		aux01 = (sqrt(y^2 + z^2 + (x + μ)^2)^-3)*(1 - μ)

		aux1 = μ*(x + μ - 1)*aux0
		aux2 = (x + μ)*aux01
		du[4] = x + 2*vy - aux1 - aux2

		aux3 = y*(μ*aux0 + aux01)
		du[5] = y - 2*vx - aux3

		aux4 = -μ*aux0 - aux01
		du[6] = z*aux4

		return du
	end

	U0 = Singleton([
			1.00838, -2.32256e-9, 0.000155935, 8.01709e-9, 0.00976067, 1.67212e-10
	])
	prob = @ivp(u' = f!(u), u(0) ∈ U0, dim=6)
	alg = TMJets(orderQ=2, orderT=6, abstol=1e-12)

	T = 3.0293993740463603
	sol = solve(prob, T=T, alg=alg);

	plot(sol, vars=(1,2))
	
end

# ╔═╡ fce654cd-0db7-42b2-8988-b29d7ba79029
md"""
### Convexified Perturbations

The idea here is to pre-compute both manifolds, and then _convexify_ each manifold into a symbolic approximation. Then, we can use set theory to find the intersection of the two (approximate) symbolic manifolds. 

"""


# ╔═╡ 721766a4-d140-47f1-9a4e-5890a815c67c
let (orbit, T) = halo(SunEarth; Az = 25_000u"km", L = 2)
	

	LazySets.set_ztol(Float64, 1e-14) # for plots

	@taylorize function f!(du, u, p, t)

		x, y, z, vx, vy, vz = u
		μ, = p
		
		du[1] = vx
		du[2] = vy
		du[3] = vz

		aux0 = sqrt(y^2 + z^2 + (x + μ - 1)^2)^-3
		aux01 = (sqrt(y^2 + z^2 + (x + μ)^2)^-3)*(1 - μ)

		aux1 = μ*(x + μ - 1)*aux0
		aux2 = (x + μ)*aux01
		du[4] = x + 2*vy - aux1 - aux2

		aux3 = y*(μ*aux0 + aux01)
		du[5] = y - 2*vx - aux3

		aux4 = -μ*aux0 - aux01
		du[6] = z*aux4

		return du
	end

	
	# The direction of the unstable manifold in state space
	direction  = unstable_eigenvector(monodromy(orbit, T))

	# We'll need the local linearization to find the manifold
	orbit = withstm(orbit)
	
	# Let's propagate the orbit for one period
	trajectory = propagate(orbit, T; abstol=1e-16, saveat=0.01)

	# We'll need to convexify the initial timesteps of the 
	# manifold throughout one orbital period
	convexified_points = let
		
		# For every timestep...
		timestep(i) = solution(trajectory).t[i]
		
		# ...find the state vector on the orbit...
		getstate(i) = state(trajectory, timestep(i))
		
		# ...and perturb that state in the direction
		# of the unstable manifold
		perturbation(i) = perturb(getstate(i), direction; eps=1e-8)
		
		# Finally, let's put it all together!
		convexified_points = [
			ReachabilityAnalysis.Singleton(perturbation(i)[1:6])
			for i ∈ 1:length(trajectory)
		] |> UnionSetArray |> box_approximation
		
	end
	
	
	# This errors...
	prob = @ivp(u' = f!(u), u(0) ∈ convexified_points, dim=6)

end

# ╔═╡ 154d3832-edc1-4b95-b793-3d7e7f3abcc4
md"""
## K-Nearest Neighbors

Using `NearestNeighbors.jl`, we could quickly iterate through large amounts of discrete data, and find the two closest points between both manifolds. There's no example here, because (as shown below) the manifolds never get anywhere _close_ to eachother!

"""

# ╔═╡ 15475890-6e74-4002-957a-78e9bf93db74
md"""
## Good Ol' Nonlinear Optimization
We can use a simple nonlinear optimizer to find some Halo orbit amplitudes and manifold perturbation parameters that result in the closest possible point between both manifolds. 

But playing around with values below, we don't get anywhere close... are manifold intersections which are _that_ far away (between Earth and Jupiter) possible?

"""

# ╔═╡ 67b95b69-d41a-4938-84d6-81acaf1ccdd6
let
	
	# Departure and arrival orbits
	D = halo(SunEarth;   Az = 50e3u"km", L = 2);
	A = halo(SunJupiter; Az = 50e3u"km", L = 1);
	
	# Perturbation directions
	V₁ = unstable_eigenvector(monodromy(D...))
	V₂ = stable_eigenvector(monodromy(A...))
	
	# Halo trajectories (not yet perturbed)
	H₁ = propagate(
		withstm(D.orbit), D.period; 
		saveat    = D.period/10,
		algorithm = Vern9()
	)
	H₂ = propagate(
		withstm(A.orbit), A.period; 
		saveat    = A.period/10,
		algorithm = Vern9()
	)
	
	# Perturbed trajectories (manifolds)
	M₁ = manifold(
		H₁; direction = Val{:unstable}, eps = 1e-6, 
		duration = 10 * D.period
	)
	
	M₂ = manifold(
		H₂; direction = Val{:stable}, eps = -1e-6, 
		duration = 3 * A.period
	)
	
	Z₁ = zerovelocity_curves(Orbit(M₁[1], 0))
	Z₂ = zerovelocity_curves(Orbit(M₂[1], 0))
	
	# Plot!
	fig = plot(; dpi=200)
	
	for trajectory ∈ M₁.solution
		let orbits = map(t -> Orbit(trajectory, t), trajectory.solution.t)
			plot!(
				map(orbit -> CR3BPtoR2BP(orbit, 1, Sun), orbits), 
				vars=:XY, palette=:blues
			)
		end
	end
	
	plot!(
		map(row -> CR3BPtoR2BP(
				vcat(row..., 0), zeros(3), 
				massparameter(SunEarth), 
				lengthunit(SunEarth), 
				timeunit(SunEarth), 1, Sun
			), eachrow(Z₁[1])
		), vars=:XY, color=:blue
	)
	

	for trajectory ∈ M₂.solution
		let orbits = map(t -> Orbit(trajectory, t), trajectory.solution.t)
			plot!(
				map(orbit -> CR3BPtoR2BP(orbit, 1, Sun), orbits), 
				vars=:XY, palette=:reds
			)
		end
	end
	
	plot!(
		map(
			row -> CR3BPtoR2BP(
				vcat(row..., 0), zeros(3), 
				massparameter(SunJupiter), 
				lengthunit(SunJupiter), 
				timeunit(SunJupiter), 1, Sun
			), eachrow(Z₂[1])
		), vars=:XY, color=:red
	)
	
	fig
	
end

# ╔═╡ b7fb6868-0f5d-46b7-8987-c5e98a44b282
md"""
# 📚 Support
"""

# ╔═╡ a82a7267-4467-4613-afbf-f768fe50657b
md"""
## Dependencies
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AstrodynamicalModels = "4282b555-f590-4262-b575-3e516e1493a7"
BlackBoxOptim = "a134a8b2-14d6-55f6-9291-3336d3ab0209"
DifferentialEquations = "0c46a032-eb83-5123-abaf-570d42b7fbaa"
GalacticOptim = "a75be94c-b780-496d-a8a9-0878b188d577"
GeneralAstrodynamics = "8068df5b-8501-4530-bd82-d24d3c9619db"
Latexify = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
Lazy = "50d2b5c4-7a5e-59d5-8109-a42b560f39c0"
LazySets = "b4f0291d-fe17-52bc-9479-3d1a343d9043"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Markdown = "d6f4376e-aef5-505a-96c1-9c027394607a"
Optim = "429524aa-4258-5aef-a3af-852621145aeb"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
ReachabilityAnalysis = "1e97bd63-91d1-579d-8e8d-501d2b57c93f"
Rotations = "6038ab10-8711-5258-84ad-4b1120ba62dc"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"
UnitfulAstro = "6112ee07-acf9-5e0f-b108-d242c714bf9f"

[compat]
AstrodynamicalModels = "~0.3.1"
BlackBoxOptim = "~0.6.0"
DifferentialEquations = "~6.18.0"
GalacticOptim = "~2.0.3"
GeneralAstrodynamics = "~0.10.1"
Latexify = "~0.15.6"
Lazy = "~0.15.1"
LazySets = "~1.51.0"
Optim = "~1.4.1"
Plots = "~1.22.2"
PlutoUI = "~0.7.10"
ReachabilityAnalysis = "~0.15.1"
Rotations = "~1.0.2"
StaticArrays = "~1.2.12"
Unitful = "~1.9.0"
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
deps = ["Compat", "IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "b8d49c34c3da35f220e7295659cd0bab8e739fed"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "3.1.33"

[[ArrayLayouts]]
deps = ["FillArrays", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "623a32b87ef0b85d26320a8cc7e57ded707aef64"
uuid = "4c555306-a7a7-4459-81d9-ec55ddd5c99a"
version = "0.7.5"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[AstroTime]]
deps = ["Dates", "EarthOrientation", "ItemGraphs", "LeapSeconds", "MacroTools", "MuladdMacro", "Reexport"]
git-tree-sha1 = "b3217075a2453321b304746f64311e748f9725a7"
uuid = "c61b5328-d09d-5e37-a9a8-0eb41c39009c"
version = "0.7.0"

[[AstrodynamicalModels]]
deps = ["DocStringExtensions", "LinearAlgebra", "ModelingToolkit", "RuntimeGeneratedFunctions", "StaticArrays", "Symbolics"]
git-tree-sha1 = "fa5d4b642976309980436a5e91d4e4b11d030aab"
uuid = "4282b555-f590-4262-b575-3e516e1493a7"
version = "0.3.1"

[[BandedMatrices]]
deps = ["ArrayLayouts", "FillArrays", "LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "ce68f8c2162062733f9b4c9e3700d5efc4a8ec47"
uuid = "aae01518-5342-5314-be14-df237901396f"
version = "0.16.11"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "61adeb0823084487000600ef8b1c00cc2474cd47"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.2.0"

[[Bijections]]
git-tree-sha1 = "705e7822597b432ebe152baa844b49f8026df090"
uuid = "e2ed5e7c-b2de-5872-ae92-c73ca462fb04"
version = "0.1.3"

[[BinaryProvider]]
deps = ["Libdl", "Logging", "SHA"]
git-tree-sha1 = "ecdec412a9abc8db54c0efc5548c64dfce072058"
uuid = "b99e7846-7c00-51b0-8f62-c81ae34c0232"
version = "0.5.10"

[[BitTwiddlingConvenienceFunctions]]
deps = ["Static"]
git-tree-sha1 = "652aab0fc0d6d4db4cc726425cadf700e9f473f1"
uuid = "62783981-4cbd-42fc-bca8-16325de8dc4b"
version = "0.1.0"

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
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[CPUSummary]]
deps = ["Hwloc", "IfElse", "Static"]
git-tree-sha1 = "ed720e2622820bf584d4ad90e6fcb93d95170b44"
uuid = "2a0fbf3d-bb9c-48f3-b0a9-814d99fd7ab9"
version = "0.1.3"

[[CPUTime]]
git-tree-sha1 = "2dcc50ea6a0a1ef6440d6eecd0fe3813e5671f45"
uuid = "a9c8d775-2e2e-55fc-8582-045d282d599e"
version = "1.0.0"

[[CRlibm]]
deps = ["Libdl"]
git-tree-sha1 = "9d1c22cff9c04207f336b8e64840d0bd40d86e0e"
uuid = "96374032-68de-5a5b-8d9e-752f78720389"
version = "0.8.0"

[[CSTParser]]
deps = ["Tokenize"]
git-tree-sha1 = "b2667530e42347b10c10ba6623cfebc09ac5c7b6"
uuid = "00ebfdb7-1f24-5e51-bd34-a7502290713f"
version = "3.2.4"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f2202b55d816427cd385a9a4f3ffb226bee80f99"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+0"

[[Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "bd4afa1fdeec0c8b89dad3c6e92bc6e3b0fec9ce"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.6.0"

[[CloseOpenIntervals]]
deps = ["ArrayInterface", "Static"]
git-tree-sha1 = "ce9c0d07ed6e1a4fecd2df6ace144cbd29ba6f37"
uuid = "fb6a15b2-703c-40df-9091-08a04967cfa9"
version = "0.1.2"

[[CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "2e62a725210ce3c3c2e1a3080190e7ca491f18d7"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.7.2"

[[CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "9995eb3977fbf67b86d0a0a0508e83017ded03f2"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.14.0"

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
git-tree-sha1 = "393ac9df4eb085c2ab12005fc496dae2e1da344e"
uuid = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
version = "0.8.3"

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
git-tree-sha1 = "1a90210acd935f222ea19657f143004d2c2a1117"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.38.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[CompositeTypes]]
git-tree-sha1 = "d5b014b216dc891e81fea299638e4c10c657b582"
uuid = "b152e2b5-7a66-4b01-a709-34e65c35f657"
version = "0.1.2"

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

[[CoordinateTransformations]]
deps = ["LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "6d1c23e740a586955645500bbec662476204a52c"
uuid = "150eb455-5306-5404-9cee-2592286d6298"
version = "0.6.1"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

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
git-tree-sha1 = "9d312bb0b7c8ace440a71c64330cf1bea0ade0c8"
uuid = "2b5f629d-d688-5b77-993f-72d75c75574e"
version = "6.70.0"

[[DiffEqCallbacks]]
deps = ["DataStructures", "DiffEqBase", "ForwardDiff", "LinearAlgebra", "NLsolve", "OrdinaryDiffEq", "Parameters", "RecipesBase", "RecursiveArrayTools", "StaticArrays"]
git-tree-sha1 = "35bc7f8be9dd2155336fe999b11a8f5e44c0d602"
uuid = "459566f4-90b8-5000-8ac3-15dfb0a30def"
version = "2.17.0"

[[DiffEqFinancial]]
deps = ["DiffEqBase", "DiffEqNoiseProcess", "LinearAlgebra", "Markdown", "RandomNumbers"]
git-tree-sha1 = "db08e0def560f204167c58fd0637298e13f58f73"
uuid = "5a0ffddc-d203-54b0-88ba-2c03c0fc2e67"
version = "2.4.0"

[[DiffEqJump]]
deps = ["ArrayInterface", "Compat", "DataStructures", "DiffEqBase", "FunctionWrappers", "LightGraphs", "LinearAlgebra", "PoissonRandom", "Random", "RandomNumbers", "RecursiveArrayTools", "Reexport", "StaticArrays", "TreeViews", "UnPack"]
git-tree-sha1 = "9f47b8ae1c6f2b172579ac50397f8314b460fcd9"
uuid = "c894b116-72e5-5b58-be3c-e6d8d4ac2b12"
version = "7.3.1"

[[DiffEqNoiseProcess]]
deps = ["DiffEqBase", "Distributions", "LinearAlgebra", "Optim", "PoissonRandom", "QuadGK", "Random", "Random123", "RandomNumbers", "RecipesBase", "RecursiveArrayTools", "Requires", "ResettableStacks", "SciMLBase", "StaticArrays", "Statistics"]
git-tree-sha1 = "d6839a44a268c69ef0ed927b22a6f43c8a4c2e73"
uuid = "77a26b50-5914-5dd7-bc55-306e6241c503"
version = "5.9.0"

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
git-tree-sha1 = "7220bc21c33e990c14f4a9a319b1d242ebc5b269"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.3.1"

[[DifferentialEquations]]
deps = ["BoundaryValueDiffEq", "DelayDiffEq", "DiffEqBase", "DiffEqCallbacks", "DiffEqFinancial", "DiffEqJump", "DiffEqNoiseProcess", "DiffEqPhysics", "DimensionalPlotRecipes", "LinearAlgebra", "MultiScaleArrays", "OrdinaryDiffEq", "ParameterizedFunctions", "Random", "RecursiveArrayTools", "Reexport", "SteadyStateDiffEq", "StochasticDiffEq", "Sundials"]
git-tree-sha1 = "ececc535bd2aa55a520131d955639288704e3851"
uuid = "0c46a032-eb83-5123-abaf-570d42b7fbaa"
version = "6.18.0"

[[DimensionalPlotRecipes]]
deps = ["LinearAlgebra", "RecipesBase"]
git-tree-sha1 = "af883a26bbe6e3f5f778cb4e1b81578b534c32a6"
uuid = "c619ae07-58cd-5f6d-b883-8f17bd6a98f9"
version = "1.2.0"

[[Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "9f46deb4d4ee4494ffb5a40a27a2aced67bdd838"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.4"

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
deps = ["CompositeTypes", "IntervalSets", "LinearAlgebra", "StaticArrays", "Statistics"]
git-tree-sha1 = "627844a59d3970db8082b778e53f86741d17aaad"
uuid = "5b8099bc-c8ec-5219-889f-1d9e522a28bf"
version = "0.5.7"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[DynamicPolynomials]]
deps = ["DataStructures", "Future", "LinearAlgebra", "MultivariatePolynomials", "MutableArithmetics", "Pkg", "Reexport", "Test"]
git-tree-sha1 = "05b68e727a192783be0b34bd8fee8f678505c0bf"
uuid = "7c1d4256-1411-5781-91ec-d7bc3513ac07"
version = "0.3.20"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[EarthOrientation]]
deps = ["Dates", "DelimitedFiles", "LeapSeconds", "OptionalData", "RemoteFiles"]
git-tree-sha1 = "d1081912769ed7d6712e1757059c7f67762ff36f"
uuid = "732a3c5d-d6c0-58bc-adb1-1b51709a25e2"
version = "0.7.1"

[[EllipsisNotation]]
deps = ["ArrayInterface"]
git-tree-sha1 = "8041575f021cba5a099a456b4163c9a08b566a02"
uuid = "da5c29d0-fa7d-589e-88eb-ea29b0a81949"
version = "1.1.0"

[[ErrorfreeArithmetic]]
git-tree-sha1 = "d6863c556f1142a061532e79f611aa46be201686"
uuid = "90fa49ef-747e-5e6f-a989-263ba693cf1a"
version = "0.5.2"

[[Espresso]]
deps = ["LinearAlgebra", "Statistics", "Test"]
git-tree-sha1 = "c3f4470b5b1ae4a60598e8286e901b9604143d05"
uuid = "6912e4f1-e036-58b0-9138-08d1e6358ea9"
version = "0.6.1"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[ExponentialUtilities]]
deps = ["ArrayInterface", "LinearAlgebra", "Printf", "Requires", "SparseArrays"]
git-tree-sha1 = "54b4bd8f88278fd544a566465c943ce4f8da7b7f"
uuid = "d4d017d3-3776-5f7e-afef-a10c40355c18"
version = "1.10.0"

[[ExprTools]]
git-tree-sha1 = "b7e3d17636b348f005f11040025ae8c6f645fe92"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.6"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FastBroadcast]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "26be48918640ce002f5833e8fc537b2ba7ed0234"
uuid = "7034ab61-46d4-4ed7-9d0f-46aef9175898"
version = "0.1.8"

[[FastClosures]]
git-tree-sha1 = "acebe244d53ee1b461970f8910c235b259e772ef"
uuid = "9aa1b823-49e4-5ca5-8b0f-3971ec8bab6a"
version = "0.3.2"

[[FastRounding]]
deps = ["ErrorfreeArithmetic", "Test"]
git-tree-sha1 = "224175e213fd4fe112db3eea05d66b308dc2bf6b"
uuid = "fa42c844-2597-5d31-933b-ebd51ab2693f"
version = "0.2.0"

[[FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "3c041d2ac0a52a12a27af2782b34900d9c3ee68c"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.11.1"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "693210145367e7685d8604aee33d9bfb85db8b31"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.11.9"

[[FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "8b3c09b56acaf3c0e581c66638b85c8650ee9dca"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.8.1"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "NaNMath", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "b5e930ac60b613ef3406da6d4f42c35d8dc51419"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.19"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

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

[[GLPK]]
deps = ["BinaryProvider", "GLPK_jll", "Libdl", "MathOptInterface", "SparseArrays"]
git-tree-sha1 = "86573ecb852e303b209212046af44871f1c0e49c"
uuid = "60bf3e95-4087-53dc-ae20-288a0d20c6a6"
version = "0.13.0"

[[GLPKMathProgInterface]]
deps = ["GLPK", "LinearAlgebra", "MathProgBase", "SparseArrays"]
git-tree-sha1 = "dcca815a687d8f398c8fc701c3796a36ef6b73a5"
uuid = "3c7084bd-78ad-589a-b5bb-dbd673274bea"
version = "0.5.0"

[[GLPK_jll]]
deps = ["GMP_jll", "Libdl", "Pkg"]
git-tree-sha1 = "ccc855de74292e478d4278e3a6fdd8212f75e81e"
uuid = "e8aa6df9-e6ca-548a-97ff-1f85fc5b8b98"
version = "4.64.0+0"

[[GMP_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "781609d7-10c4-51f6-84f2-b8444358ff6d"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "c2178cfbc0a5a552e16d097fae508f2024de61a3"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.59.0"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "ef49a187604f865f4708c90e3f431890724e9012"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.59.0+0"

[[GalacticOptim]]
deps = ["ArrayInterface", "ConsoleProgressMonitor", "DiffResults", "DocStringExtensions", "Logging", "LoggingExtras", "Printf", "ProgressLogging", "Reexport", "Requires", "SciMLBase", "TerminalLoggers"]
git-tree-sha1 = "fd355a5e3657d4159fb8dbf9d04138b115ac1442"
uuid = "a75be94c-b780-496d-a8a9-0878b188d577"
version = "2.0.3"

[[GeneralAstrodynamics]]
deps = ["ArrayInterface", "AstroTime", "AstrodynamicalModels", "Contour", "CoordinateTransformations", "Dates", "DifferentialEquations", "Distributed", "DocStringExtensions", "LabelledArrays", "LinearAlgebra", "Logging", "Plots", "RecipesBase", "Reexport", "Requires", "Roots", "Rotations", "StaticArrays", "SymbolicUtils", "Unitful", "UnitfulAstro"]
git-tree-sha1 = "6e62fc6382d67f575550dc5266149686ccdd41dd"
uuid = "8068df5b-8501-4530-bd82-d24d3c9619db"
version = "0.10.3"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "7bf67e9a481712b3dbe9cb3dac852dc4b1162e02"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+0"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "60ed5f1643927479f845b0135bb369b031b541fa"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.14"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "8a954fed8ac097d5be04921d595f741115c1b2ad"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+0"

[[HostCPUFeatures]]
deps = ["BitTwiddlingConvenienceFunctions", "IfElse", "Libdl", "Static"]
git-tree-sha1 = "3169c8b31863f9a409be1d17693751314241e3eb"
uuid = "3e5b6fbb-0976-4d2c-9146-d79de83f2fb0"
version = "0.1.4"

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

[[HybridSystems]]
deps = ["FillArrays", "LightGraphs", "LinearAlgebra", "MappedArrays", "MathematicalSystems"]
git-tree-sha1 = "0ca6b105d3a8cedd5dafa0fc907c66e737748cd0"
uuid = "2207ec0c-686c-5054-b4d2-543502888820"
version = "0.3.5"

[[HypertextLiteral]]
git-tree-sha1 = "72053798e1be56026b81d4e2682dbe58922e5ec9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.0"

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

[[IntervalArithmetic]]
deps = ["CRlibm", "FastRounding", "LinearAlgebra", "Markdown", "Random", "RecipesBase", "RoundingEmulator", "SetRounding", "StaticArrays"]
git-tree-sha1 = "2d090e521d89e88fb63f139390dfd86eb3c302b4"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "0.19.2"

[[IntervalMatrices]]
deps = ["IntervalArithmetic", "LinearAlgebra", "Random", "Reexport"]
git-tree-sha1 = "09afb712d1f3fb68a07bac65bd31a30eef5a3d7a"
uuid = "5c1f47dc-42dd-5697-8aaa-4d102d140ba9"
version = "0.6.6"

[[IntervalRootFinding]]
deps = ["ForwardDiff", "IntervalArithmetic", "LinearAlgebra", "Polynomials", "Reexport", "StaticArrays"]
git-tree-sha1 = "0fbc79fa32061a9b55c6511e9e9c90f9d895e779"
uuid = "d2bf35a9-74e0-55ec-b149-d360ff49b807"
version = "0.5.9"

[[IntervalSets]]
deps = ["Dates", "EllipsisNotation", "Statistics"]
git-tree-sha1 = "3cc368af3f110a767ac786560045dceddfc16758"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.5.3"

[[Intervals]]
deps = ["Dates", "Printf", "RecipesBase", "Serialization", "TimeZones"]
git-tree-sha1 = "323a38ed1952d30586d0fe03412cde9399d3618b"
uuid = "d8418881-c3e1-53bb-8760-2df7ec849ed5"
version = "1.5.0"

[[IrrationalConstants]]
git-tree-sha1 = "f76424439413893a832026ca355fe273e93bce94"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.0"

[[ItemGraphs]]
deps = ["LightGraphs"]
git-tree-sha1 = "e363e8bbeb44dc32c711a9c3f7e7323601050727"
uuid = "d5eda45b-7e79-5788-9687-2c6ab7b96158"
version = "0.4.0"

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
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[JSONSchema]]
deps = ["HTTP", "JSON", "URIs"]
git-tree-sha1 = "2f49f7f86762a0fbbeef84912265a1ae61c4ef80"
uuid = "7d188eb4-7ad8-530c-ae41-71a32a6d4692"
version = "0.3.4"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[JuMP]]
deps = ["Calculus", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MathOptInterface", "MutableArithmetics", "NaNMath", "Printf", "Random", "SparseArrays", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "4358b7cbf2db36596bdbbe3becc6b9d87e4eb8f5"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "0.21.10"

[[JuliaFormatter]]
deps = ["CSTParser", "CommonMark", "DataStructures", "Pkg", "Tokenize"]
git-tree-sha1 = "cf0dbee6a5a30e2aef87f3b54bc3733ca2df2939"
uuid = "98e50ef6-434e-11e9-1051-2b60c6c9e899"
version = "0.16.1"

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
git-tree-sha1 = "bdde43e002847c34c206735b1cf860bc3abd35e7"
uuid = "2ee39098-c373-598a-b85f-a56591580800"
version = "1.6.4"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a4b12a1bd2ebade87891ab7e36fdbce582301a92"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.6"

[[LayoutPointers]]
deps = ["ArrayInterface", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static"]
git-tree-sha1 = "d2bda6aa0b03ce6f141a2dc73d0bcb7070131adc"
uuid = "10f19ff3-798f-405d-979b-55457f8fc047"
version = "0.1.3"

[[Lazy]]
deps = ["MacroTools"]
git-tree-sha1 = "1370f8202dac30758f3c345f9909b97f53d87d3f"
uuid = "50d2b5c4-7a5e-59d5-8109-a42b560f39c0"
version = "0.15.1"

[[LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[LazySets]]
deps = ["Distributed", "ExprTools", "GLPK", "GLPKMathProgInterface", "InteractiveUtils", "IntervalArithmetic", "JuMP", "LinearAlgebra", "MathProgBase", "Random", "RecipesBase", "Reexport", "Requires", "SharedArrays", "SparseArrays"]
git-tree-sha1 = "a6b00b43902cb978e7ca0987891bbcb42b00ac80"
uuid = "b4f0291d-fe17-52bc-9479-3d1a343d9043"
version = "1.51.0"

[[LeapSeconds]]
deps = ["Dates"]
git-tree-sha1 = "0e5be6875ee72468bc12221d32ba1021c5d224fe"
uuid = "2f5f767c-a11e-5269-a972-637d4b97c32d"
version = "1.1.0"

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
deps = ["ChainRulesCore", "DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "34dc30f868e368f8a17b728a1238f3fcda43931a"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.3"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "dfeda1c1130990428720de0024d4516b1902ce98"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "0.4.7"

[[LoopVectorization]]
deps = ["ArrayInterface", "CPUSummary", "CloseOpenIntervals", "DocStringExtensions", "HostCPUFeatures", "IfElse", "LayoutPointers", "LinearAlgebra", "OffsetArrays", "PolyesterWeave", "Requires", "SLEEFPirates", "Static", "ThreadingUtilities", "UnPack", "VectorizationBase"]
git-tree-sha1 = "4804192466f4d370ca19c9957dfb3d919e6ef77e"
uuid = "bdcacae8-1622-11e9-2a5c-532679323890"
version = "0.12.77"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "5a5bc6bf062f0f95e62d0fe0a2d99699fed82dd9"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.8"

[[ManualMemory]]
git-tree-sha1 = "9cb207b18148b2199db259adfa923b45593fe08e"
uuid = "d125e4d3-2237-4719-b19c-fa641b8a4667"
version = "0.1.6"

[[MappedArrays]]
deps = ["FixedPointNumbers"]
git-tree-sha1 = "b92bd220c95a8bbe89af28f11201fd080e0e3fe7"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.3.0"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "JSON", "JSONSchema", "LinearAlgebra", "MutableArithmetics", "OrderedCollections", "SparseArrays", "Test", "Unicode"]
git-tree-sha1 = "575644e3c05b258250bb599e57cf73bbf1062901"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "0.9.22"

[[MathProgBase]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9abbe463a1e9fc507f12a69e7f29346c2cdc472c"
uuid = "fdba3010-5040-5b88-9595-932c9decdf73"
version = "0.7.8"

[[MathematicalSystems]]
deps = ["Espresso", "InteractiveUtils", "LinearAlgebra", "MacroTools", "MultivariatePolynomials", "RecipesBase", "SparseArrays"]
git-tree-sha1 = "8f22b72a596bf68ab6c75a07dcda41128f9959f5"
uuid = "d14a8603-c872-5ed3-9ece-53e0e82e39da"
version = "0.11.9"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[Mocking]]
deps = ["ExprTools"]
git-tree-sha1 = "748f6e1e4de814b101911e64cc12d83a6af66782"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.7.2"

[[ModelingToolkit]]
deps = ["AbstractTrees", "ArrayInterface", "ConstructionBase", "DataStructures", "DiffEqBase", "DiffEqCallbacks", "DiffEqJump", "DiffRules", "Distributed", "Distributions", "DocStringExtensions", "DomainSets", "IfElse", "InteractiveUtils", "JuliaFormatter", "LabelledArrays", "Latexify", "Libdl", "LightGraphs", "LinearAlgebra", "MacroTools", "NaNMath", "NonlinearSolve", "RecursiveArrayTools", "Reexport", "Requires", "RuntimeGeneratedFunctions", "SafeTestsets", "SciMLBase", "Serialization", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArrays", "SymbolicUtils", "Symbolics", "UnPack", "Unitful"]
git-tree-sha1 = "4de3cf12736f85a63684e42fe15cb4786d93abe5"
uuid = "961ee093-0014-501f-94e3-6117800e7a78"
version = "6.5.1"

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
git-tree-sha1 = "45c9940cec79dedcdccc73cc6dd09ea8b8ab142c"
uuid = "102ac46a-7ee4-5c85-9060-abc95bfdeaa3"
version = "0.3.18"

[[MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "3927848ccebcc165952dc0d9ac9aa274a87bfe01"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "0.2.20"

[[NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "144bab5b1443545bc4e791536c9f1eacb4eed06a"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.1"

[[NLsolve]]
deps = ["Distances", "LineSearches", "LinearAlgebra", "NLSolversBase", "Printf", "Reexport"]
git-tree-sha1 = "019f12e9a1a7880459d0173c182e6a99365d7ac1"
uuid = "2774e3e8-f4cf-5e23-947b-6d7e65073b56"
version = "4.5.1"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[NonlinearSolve]]
deps = ["ArrayInterface", "FiniteDiff", "ForwardDiff", "IterativeSolvers", "LinearAlgebra", "RecursiveArrayTools", "RecursiveFactorization", "Reexport", "SciMLBase", "Setfield", "StaticArrays", "UnPack"]
git-tree-sha1 = "e9ffc92217b8709e0cf7b8808f6223a4a0936c95"
uuid = "8913a72c-1f9b-4ce2-8d82-65094dcecaec"
version = "0.3.11"

[[OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "c0e9e582987d36d5a61e650e6e543b9e44d9914b"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.10.7"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7937eda4681660b4d6aeeecc2f7e1c81c8ee4e2f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+0"

[[OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

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
git-tree-sha1 = "7863df65dbb2a0fa8f85fcaf0a41167640d2ebed"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.4.1"

[[OptionalData]]
git-tree-sha1 = "d047cc114023e12292533bb822b45c23cb51d310"
uuid = "fbd9d27c-2d1c-5c1c-99f2-7497d746985d"
version = "1.0.0"

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
deps = ["Adapt", "ArrayInterface", "DataStructures", "DiffEqBase", "DocStringExtensions", "ExponentialUtilities", "FastClosures", "FiniteDiff", "ForwardDiff", "LinearAlgebra", "Logging", "MacroTools", "MuladdMacro", "NLsolve", "RecursiveArrayTools", "Reexport", "SparseArrays", "SparseDiffTools", "StaticArrays", "UnPack"]
git-tree-sha1 = "e9f977a3119e7bfb3bfaeb3daa354f38e9baf76f"
uuid = "1dea7af3-3e70-54e6-95c3-0bf5283fa5ed"
version = "5.55.1"

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
git-tree-sha1 = "c2d9813bdcf47302a742a1f5956d7de274acec12"
uuid = "65888b18-ceab-5e60-b2b9-181511a3b968"
version = "5.12.1"

[[Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "9d8c00ef7a8d110787ff6f170579846f776133a9"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.0.4"

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
git-tree-sha1 = "2537ed3c0ed5e03896927187f5f2ee6a4ab342db"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.14"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs"]
git-tree-sha1 = "457b13497a3ea4deb33d273a6a5ea15c25c0ebd9"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.22.2"

[[PlutoUI]]
deps = ["Base64", "Dates", "HypertextLiteral", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "Suppressor"]
git-tree-sha1 = "26b4d16873562469a0a1e6ae41d90dec9e51286d"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.10"

[[PoissonRandom]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "44d018211a56626288b5d3f8c6497d28c26dc850"
uuid = "e409e4f3-bfea-5376-8464-e040bb5c01ab"
version = "0.4.0"

[[PolyesterWeave]]
deps = ["BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "Static", "ThreadingUtilities"]
git-tree-sha1 = "371a19bb801c1b420b29141750f3a34d6c6634b9"
uuid = "1d0040c9-8b98-4ee7-8388-3f51789ca0ad"
version = "0.1.0"

[[Polynomials]]
deps = ["Intervals", "LinearAlgebra", "MutableArithmetics", "RecipesBase"]
git-tree-sha1 = "0bbfdcd8cda81b8144de4be8a67f5717e959a005"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "2.0.14"

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

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

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
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

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
git-tree-sha1 = "043da614cc7e95c703498a491e2c21f58a2b8111"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.5.3"

[[ReachabilityAnalysis]]
deps = ["CommonSolve", "ExprTools", "HybridSystems", "IntervalArithmetic", "IntervalMatrices", "LazySets", "LinearAlgebra", "MathematicalSystems", "Parameters", "Printf", "ProgressMeter", "RecipesBase", "RecursiveArrayTools", "Reexport", "Requires", "SparseArrays", "StaticArrays", "TaylorIntegration", "TaylorModels", "TaylorSeries", "UnPack"]
git-tree-sha1 = "9388db4563480123dfc419e4ea1197295033ffdb"
uuid = "1e97bd63-91d1-579d-8e8d-501d2b57c93f"
version = "0.15.1"

[[RecipesBase]]
git-tree-sha1 = "44a75aa7a527910ee3d1751d1f0e4148698add9e"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.1.2"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "7ad0dfa8d03b7bcf8c597f59f5292801730c55b8"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.4.1"

[[RecursiveArrayTools]]
deps = ["ArrayInterface", "ChainRulesCore", "DocStringExtensions", "LinearAlgebra", "RecipesBase", "Requires", "StaticArrays", "Statistics", "ZygoteRules"]
git-tree-sha1 = "00bede2eb099dcc1ddc3f9ec02180c326b420ee2"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "2.17.2"

[[RecursiveFactorization]]
deps = ["LinearAlgebra", "LoopVectorization"]
git-tree-sha1 = "2e1a88c083ebe8ba69bc0b0084d4b4ba4aa35ae0"
uuid = "f2c3362d-daeb-58d1-803e-2bc74f2840b4"
version = "0.1.13"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[RemoteFiles]]
deps = ["Dates", "FileIO", "HTTP"]
git-tree-sha1 = "54527375d877a64c55190fb762d584f927d6d7c3"
uuid = "cbe49d4c-5af1-5b60-bb70-0a60aa018e1b"
version = "0.4.2"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[ResettableStacks]]
deps = ["StaticArrays"]
git-tree-sha1 = "256eeeec186fa7f26f2801732774ccf277f05db9"
uuid = "ae5879a3-cd67-5da8-be7f-38c6eb64a37b"
version = "1.1.1"

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
deps = ["CommonSolve", "Printf", "Setfield"]
git-tree-sha1 = "e8102d671f2343d2e9f12af0ecbd85fd5f86c4fa"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "1.3.4"

[[Rotations]]
deps = ["LinearAlgebra", "StaticArrays", "Statistics"]
git-tree-sha1 = "2ed8d8a16d703f900168822d83699b8c3c1a5cd8"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.0.2"

[[RoundingEmulator]]
git-tree-sha1 = "40b9edad2e5287e05bd413a38f61a8ff55b9557b"
uuid = "5eaf0fd0-dfba-4ccb-bf02-d820a40db705"
version = "0.2.1"

[[RuntimeGeneratedFunctions]]
deps = ["ExprTools", "SHA", "Serialization"]
git-tree-sha1 = "cdc1e4278e91a6ad530770ebb327f9ed83cf10c4"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.3"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[SIMDTypes]]
git-tree-sha1 = "330289636fb8107c5f32088d2741e9fd7a061a5c"
uuid = "94e857df-77ce-4151-89e5-788b33177be4"
version = "0.1.0"

[[SLEEFPirates]]
deps = ["IfElse", "Static", "VectorizationBase"]
git-tree-sha1 = "2e8150c7d2a14ac68537c7aac25faa6577aff046"
uuid = "476501e8-09a2-5ece-8869-fb82de89a1fa"
version = "0.6.27"

[[SafeTestsets]]
deps = ["Test"]
git-tree-sha1 = "36ebc5622c82eb9324005cc75e7e2cc51181d181"
uuid = "1bc83da4-3b8d-516f-aca4-4fe02f6d838f"
version = "0.0.1"

[[SciMLBase]]
deps = ["ArrayInterface", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "RecipesBase", "RecursiveArrayTools", "StaticArrays", "Statistics", "Tables", "TreeViews"]
git-tree-sha1 = "91e29a2bb257a4b992c48f35084064578b87d364"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "1.19.0"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SetRounding]]
git-tree-sha1 = "d7a25e439d07a17b7cdf97eecee504c50fedf5f6"
uuid = "3cc68bcd-71a2-5612-b932-767ffbe40ab0"
version = "0.2.1"

[[Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "Requires"]
git-tree-sha1 = "fca29e68c5062722b5b4435594c3d1ba557072a3"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "0.7.1"

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
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SparseDiffTools]]
deps = ["Adapt", "ArrayInterface", "Compat", "DataStructures", "FiniteDiff", "ForwardDiff", "LightGraphs", "LinearAlgebra", "Requires", "SparseArrays", "StaticArrays", "VertexSafeGraphs"]
git-tree-sha1 = "36a4d27a02af48a1eafd2baff58b32deeeb68926"
uuid = "47a9eef4-7e08-11e9-0b38-333d64bd3804"
version = "1.16.5"

[[SpatialIndexing]]
git-tree-sha1 = "fb7041e6bd266266fa7cdeb80427579e55275e4f"
uuid = "d4ead438-fe20-5cc5-a293-4fd39a41b74c"
version = "0.1.3"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "ad42c30a6204c74d264692e633133dcea0e8b14e"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.6.2"

[[Static]]
deps = ["IfElse"]
git-tree-sha1 = "a8f30abc7c64a39d389680b74e749cf33f872a70"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.3.3"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3240808c6d463ac46f1c1cd7638375cd22abbccb"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.12"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "1958272568dc176a1d881acb797beb909c785510"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.0.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "8cbbc098554648c84f79a463c9ff0fd277144b6c"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.10"

[[StatsFuns]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "46d7ccc7104860c38b11966dd1f72ff042f382e4"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.10"

[[SteadyStateDiffEq]]
deps = ["DiffEqBase", "DiffEqCallbacks", "LinearAlgebra", "NLsolve", "Reexport", "SciMLBase"]
git-tree-sha1 = "3df66a4a9ba477bea5cb10a3ec732bb48a2fc27d"
uuid = "9672c7b4-1e72-59bd-8a11-6ac3964bc41f"
version = "1.6.4"

[[StochasticDiffEq]]
deps = ["ArrayInterface", "DataStructures", "DiffEqBase", "DiffEqJump", "DiffEqNoiseProcess", "DocStringExtensions", "FillArrays", "FiniteDiff", "ForwardDiff", "LinearAlgebra", "Logging", "MuladdMacro", "NLsolve", "OrdinaryDiffEq", "Random", "RandomNumbers", "RecursiveArrayTools", "Reexport", "SparseArrays", "SparseDiffTools", "StaticArrays", "UnPack"]
git-tree-sha1 = "d9e996e95ad3c601c24d81245a7550cebcfedf85"
uuid = "789caeaf-c7a9-5a7d-9973-96adeb23e2a0"
version = "6.36.0"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "2ce41e0d042c60ecd131e9fb7154a3bfadbf50d3"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.3"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"

[[Sundials]]
deps = ["CEnum", "DataStructures", "DiffEqBase", "Libdl", "LinearAlgebra", "Logging", "Reexport", "SparseArrays", "Sundials_jll"]
git-tree-sha1 = "75412a0ce4cd7995d7445ba958dd11de03fd2ce5"
uuid = "c3572dad-4567-51f8-b174-8c6c989267f4"
version = "4.5.3"

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
deps = ["AbstractTrees", "Bijections", "ChainRulesCore", "Combinatorics", "ConstructionBase", "DataStructures", "DocStringExtensions", "DynamicPolynomials", "IfElse", "LabelledArrays", "LinearAlgebra", "MultivariatePolynomials", "NaNMath", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArrays", "TermInterface", "TimerOutputs"]
git-tree-sha1 = "b747ed621b12281f9bc69e7a6e5337334b1d0c7f"
uuid = "d1185830-fcd6-423d-90d6-eec64667417b"
version = "0.16.0"

[[Symbolics]]
deps = ["ConstructionBase", "DiffRules", "Distributions", "DocStringExtensions", "DomainSets", "IfElse", "Latexify", "Libdl", "LinearAlgebra", "MacroTools", "NaNMath", "RecipesBase", "Reexport", "Requires", "RuntimeGeneratedFunctions", "SciMLBase", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArrays", "SymbolicUtils", "TreeViews"]
git-tree-sha1 = "e17bd63d88ae90df2ef3c0505a687a534f86f263"
uuid = "0c5d862f-8b57-4792-8d23-62f2024744c7"
version = "3.4.1"

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
git-tree-sha1 = "1162ce4a6c4b7e31e0e6b14486a6986951c73be9"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.5.2"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[TaylorIntegration]]
deps = ["DiffEqBase", "Espresso", "InteractiveUtils", "LinearAlgebra", "Markdown", "OrdinaryDiffEq", "RecursiveArrayTools", "Reexport", "Requires", "StaticArrays", "TaylorSeries"]
git-tree-sha1 = "b7af537b6fefba170e3cc36de26d0c2da3124ffd"
uuid = "92b13dbe-c966-51a2-8445-caca9f8a7d42"
version = "0.8.9"

[[TaylorModels]]
deps = ["IntervalArithmetic", "IntervalRootFinding", "LinearAlgebra", "Markdown", "Random", "RecipesBase", "Reexport", "TaylorIntegration", "TaylorSeries"]
git-tree-sha1 = "274e1cc5ea6708596156cedef8287449485f7fcb"
uuid = "314ce334-5f6e-57ae-acf6-00b6e903104a"
version = "0.4.2"

[[TaylorSeries]]
deps = ["LinearAlgebra", "Markdown", "Requires", "SparseArrays"]
git-tree-sha1 = "59ee6d7175a204013d91ad84e55eed1e772e01bd"
uuid = "6aa5eb33-94cf-58f4-a9d0-e4b2c4fc25ea"
version = "0.11.2"

[[TermInterface]]
git-tree-sha1 = "02a620218eaaa1c1914d228d0e75da122224a502"
uuid = "8ea1fca8-c5ef-4a55-8b96-4e9afe9c9a3c"
version = "0.1.8"

[[TerminalLoggers]]
deps = ["LeftChildRightSiblingTrees", "Logging", "Markdown", "Printf", "ProgressLogging", "UUIDs"]
git-tree-sha1 = "d620a061cb2a56930b52bdf5cf908a5c4fa8e76a"
uuid = "5d786b92-1e48-4d6f-9151-6b4477ca9bed"
version = "0.1.4"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[ThreadingUtilities]]
deps = ["ManualMemory"]
git-tree-sha1 = "03013c6ae7f1824131b2ae2fc1d49793b51e8394"
uuid = "8290d209-cae3-49c0-8002-c8c24d57dab5"
version = "0.4.6"

[[TimeZones]]
deps = ["Dates", "Future", "LazyArtifacts", "Mocking", "Pkg", "Printf", "RecipesBase", "Serialization", "Unicode"]
git-tree-sha1 = "6c9040665b2da00d30143261aea22c7427aada1c"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.5.7"

[[TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "7cb456f358e8f9d102a8b25e8dfedf58fa5689bc"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.13"

[[Tokenize]]
git-tree-sha1 = "0952c9cee34988092d73a5708780b3917166a0dd"
uuid = "0796e94c-ce3b-5d07-9a54-7f471281c624"
version = "0.5.21"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

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
git-tree-sha1 = "a981a8ef8714cba2fd9780b22fd7a469e7aaf56d"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.9.0"

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
deps = ["ArrayInterface", "CPUSummary", "HostCPUFeatures", "Hwloc", "IfElse", "LayoutPointers", "Libdl", "LinearAlgebra", "SIMDTypes", "Static"]
git-tree-sha1 = "3e2385f4ec895e694c24a1d5aba58cb6d27cf8b6"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.21.10"

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
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

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
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─243ac0ae-0e77-11ec-3472-a75caee1ed6d
# ╟─ae686dd1-983d-44dd-87cf-2c508f24f35c
# ╟─31126436-f264-499f-904f-ff63a5507cfc
# ╠═abd7be96-0340-4ec4-a277-eb05cadbbb8a
# ╟─6a41abea-df8e-4d81-bbe0-219dbf7c3156
# ╟─8662f0e5-8c74-4d96-ab45-73099ba3609f
# ╠═cdab4e44-ec01-49ad-b30b-32f6f7ed3d72
# ╟─3f953f28-b48c-4342-ace8-9156f7489ddc
# ╟─270303d8-fbfa-493e-82da-4f6adcf7f9bb
# ╠═c9fff891-3101-4aec-bbc1-ce8ff4f110c9
# ╟─d5f69f3a-5113-4110-90e6-51f0d6d0ff4f
# ╠═4cd20c37-97ec-4a1f-aa60-b138605c7c95
# ╟─d6bea59b-d8d3-49c5-9296-b77969b984c9
# ╟─4d71c69d-95b4-40ca-ac39-1cbd61ba491a
# ╟─c293ea93-4b76-47b3-8a06-656d2d8ad85c
# ╠═60b13469-ef77-4df5-9080-d75d768f1195
# ╟─a9776dd4-a461-402f-a6cb-9a92c27122fc
# ╠═2aff66ca-1504-465b-bf40-93c777432800
# ╟─c5239fb2-c92e-422f-a32b-1ea604b21cc2
# ╠═ca0e7686-df99-4e74-8d77-de9fdee68ba7
# ╠═e20e3843-8a32-4d44-95af-3f5a5135d7c8
# ╟─234fbfdb-4f87-4a6d-b887-c603b112e82e
# ╟─7ff01084-f500-46ba-ae75-68a5a20199c6
# ╟─50982260-3e11-489d-8659-92f9f16dc8b4
# ╠═db3addaf-89ab-44a8-865d-a9c6b96ef529
# ╟─7b4c0e2a-1b2c-4da1-93a2-0a6d0d72b2bf
# ╠═5b4187f1-6a3f-46f5-93c1-603cfd670cd3
# ╟─836e4188-851a-4a7c-be7b-39ceaf45954c
# ╟─b3d059b7-a1a4-4023-83bb-d2ace7f1d399
# ╠═91e3b0ec-ad90-4acf-b622-1e6b8450054f
# ╟─85da49f7-fddf-4b8e-98f2-1cddea80c340
# ╠═4b06ade4-11e5-4e84-a954-e7a78275bd3b
# ╟─ae4e6317-793d-4f14-8e33-f7880948bb12
# ╟─4c66e648-174a-47a2-a77c-f67d7173eaaa
# ╠═65d5c1a8-d268-44b3-a611-7d79723ad9ab
# ╟─4c243d99-17e8-45cf-b887-f89f8b221107
# ╠═9be51126-bd53-4112-8f59-5bd023a8f522
# ╟─4aba4714-4bce-46f9-9e51-81397042c2ec
# ╟─467b8efe-6009-4f8e-bcaf-3f795ac98694
# ╟─8101681a-771f-44e7-ae20-4fc77cb92bf5
# ╟─6481c3f5-30e7-44bb-8764-061b618e1460
# ╠═fba1fba4-8e88-4064-9c9a-48b2c055b035
# ╟─fce654cd-0db7-42b2-8988-b29d7ba79029
# ╠═721766a4-d140-47f1-9a4e-5890a815c67c
# ╟─154d3832-edc1-4b95-b793-3d7e7f3abcc4
# ╟─15475890-6e74-4002-957a-78e9bf93db74
# ╟─67b95b69-d41a-4938-84d6-81acaf1ccdd6
# ╟─b7fb6868-0f5d-46b7-8987-c5e98a44b282
# ╟─a82a7267-4467-4613-afbf-f768fe50657b
# ╠═f4e67586-4fdd-4fa3-9b55-5174345cb5eb
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
