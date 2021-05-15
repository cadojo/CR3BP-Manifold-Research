### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# ╔═╡ 9739e5dc-369e-11eb-2c56-f36ccd348299
begin
	
	using Plots
	using Roots
	using PlutoUI
	using Latexify
	using StaticArrays
	using LinearAlgebra
	using ModelingToolkit
	using UnitfulAstrodynamics
	using DifferentialEquations
	
	μ = nondimensionalize(Earth.μ, Moon.μ)

end;

# ╔═╡ 860ea13a-369e-11eb-34b2-3fc6557a68d6
md"""

# 🎢 Halo Orbits & Invariant Manifolds

_Invariant manifolds about Halo orbits and their applications in the Circular Restricted Three-body Problem._

- Joe Carpinelli
- December, $2020$
- ENAE$601$ Final Project

###### Presentation Mode: $(html"<button onclick=present()>Toggle Presentation</button>")

"""

# ╔═╡ 2f3bcf58-3758-11eb-352c-a1181281eba0
md"""

## 📋 Project Overview

In the context of astrodynamics,  __manifolds are groups of trajectories that move toward or away from Lagrange points__. To use invariant manifolds for interplanetary travel, several concepts must be developed and built on: lagrange points, periodic and quasi-periodic orbits within the Circular Restricted Three-body Problem, and manifolds about periodic orbits $\verb|[1]|$.

### Outline

- Brief review of Lagrange points
- Periodic orbits (specifically, the subsection known as Halo orbits)
- Finding Halo orbits (both analytically, and numerically)
- Invariant manifolds about Halo orbits

### Primary Reference

- Megan Rund's Masters Thesis at California Polytechnic State University $\verb|[1]|$

"""

# ╔═╡ fc4106f6-399e-11eb-1f9f-e7c4d5539f20
md"""

## Stability at Lagrange Points

* Like equilibrium points for all nonlinear systems, Lagrange points can be __stable or unstable__
* We can find the stability of an equilibrium point by analysing __eigenvalues__ of the Jacobian of the state vector

In the $2$D case:

$\begin{bmatrix}\dot{\zeta} \\ \dot{\beta} \\ \ddot{\zeta} \\ \ddot{\eta} \end{bmatrix} = \begin{bmatrix} 0 & 0 & 1 & 0 \\ 0 & 0 & 0 & 1 \\ U_{xx} & U_{xy} & 0 & 2 \\ U_{yx} & U_{yy} & -2 & 0\end{bmatrix} \begin{bmatrix} \zeta \\ \eta \\ \dot{\zeta} \\ \dot{\eta} \end{bmatrix}$

$\lambda^4 + (4-U_{xx}-U_{yy})\lambda^2 + U_{xx} U_{yy} - U_{xy}^2 = 0$

"""

# ╔═╡ 8c0a0a9c-39a1-11eb-1fe6-c7177fa4b5a8
md"""

## Periodic Orbits

#### Libration Orbit Families
* Orbits about Lagrange points are known as __Libration orbits__
* __Lyapunov__ orbits are two-dimensional Libration orbits
* __Lissajous__ orbits are three-dimensional, semi-periodic Libration orbits
* __Halo__ orbits are three-dimensional, theoretically periodic Libration orbits 


#### Finding Halo Orbits
* The calculations required to solve for Halo orbits are numerically sensitive
* We covered the procedure for iteratively solving for Halo orbits __numerically__ in __Lecture 16__; this requires an initial guess


* __How do we find an initial guess for a Halo orbit?__

"""

# ╔═╡ 95a851d0-39a1-11eb-05b1-81fbb6c0bd54
md"""

## 😇 Analytical Halo Solution

* The Circular Restricted Three-body Dynamics can be derived using "Legendre poly- nomials", and there exists a third-order approximation (shown below) $\verb|[5]|$
* We can choose parameters to remove __unstable__ (secular) terms from the expansion

#### Third Order CR3BP Expansion

   $(LocalResource("./media/poly.png", :width=>400))


#### Algorithm Inputs

* Nondimensional mass parameter $\mu$
* Nondimensional $Z-axis$ amplitude for the desired Halo orbit
* Lagrange point to orbit (L1 or L2)

#### Algorithm Outputs

* Position vector $\overrightarrow{r}_0$
* Velocity vector $\overrightarrow{v}_0$
* Estimated orbital period $T$


"""

# ╔═╡ bf3ee972-39ac-11eb-2bdb-fd28bebd418e
md"""

## 🧮 Numerical Halo Solution

* As discussed in __Lecture 16__, we can append the __state transition matrix__ $\Phi(t_0 + t_i, t_0)$ to our state vector, and iteratively change initial conditions to __numerically find a periodic orbit__ $\verb|[1]|$

1.  $\Phi = I,\ \overrightarrow{x}_0 = \begin{bmatrix} x_0 & 0 & z_0 & 0 & \dot{y}_0 & 0 & \Phi_1 & \Phi_2 & \Phi_3 & \Phi_4 & \Phi_5 & \Phi_6 \end{bmatrix}$
2. Propagate until $y=0$ again; $\dot{\Phi} = F \Phi$ where $F = \begin{bmatrix} 0 & I_3 \\ U_{XX} & 2\Omega \end{bmatrix}$, $U_{XX}$ is the matrix of second partial derivatives of potential $U$
3. Calculate $\begin{bmatrix} \delta x_0 \\ \delta \dot{y}_0 \end{bmatrix} = \left( \begin{bmatrix} \Phi_{4 1} & \Phi_{4 5} \\ \Phi_{6 1} & \Phi_{6 5} \end{bmatrix}    \frac{1}{\dot{y}} \begin{bmatrix} \ddot{x} \\ \ddot{z} \end{bmatrix} \right)^{-1} \begin{bmatrix}  -\dot{x} \\ -\dot{z} \end{bmatrix}$
4. Set $x_0 \leftarrow x_0 + \delta x_0$, $\dot{y}_0 \leftarrow \dot{y}_0 + \delta \dot{y}$ and jump back to __Step 1__ (until $\dot{x}$, $\dot{z}$ are both within some tolerance of zero)


"""

# ╔═╡ b123e506-39af-11eb-06b3-cfb02d9d50fc
md"""

## 🎢 Dynamics along Halo Orbits

### Manifolds Exist
* Each point along a Halo orbit is connected with an __unstable__ manifold, and a __stable__ manifold
* The unstable manifold __departs__ the Halo orbit, and the stable manifold __arrives__ at the Halo orbit


* __How can we calculate the perturbation required to shift the spacecraft onto the manifold?__

### Finding Manifolds
* We can use __Eigenvectors__ of the Jacobian to calculate a state perturbation which will place the spacecraft onto a manifold at each point along the Halo orbit

1. Propagate the Halo orbit for one period $T$, including the state transition matrix $\Phi(t_0 + t_i, t_0)$
2. Let the final state transition matrix be $M$; $M = \Phi(t_0 + T, t_0)$
3. Calculate eigenvectors $V^{S} \leftrightarrow \text{minreal}(\text{eig}(M))$, and $V^{U} \leftrightarrow \text{maxreal}(\text{eig}(M))$
4. For each point $i$ along the Halo orbit...
   *  $V_i^S = \Phi(t_0 + t_i, t_0) V^S$, and $V_i^U = \Phi(t_0 + t_i, t_0) V^U$
   *  $X_i^S = X_i \pm \epsilon \frac{V_i^S}{|V_i^S|}$, and $X_i^U = X_i \pm \epsilon \frac{V_i^U}{|V_i^U|}$


"""

# ╔═╡ 542fc7e8-3a27-11eb-0284-07c4a6f626f5
md"""

## Invariant Manifold Example

* Pulled from Rund's Thesis $\verb|[1]|$
* Note that stable manifolds need to be propagated _backward_ in time from the perturbation along the Halo orbit, becuase they converge on the Halo orbit $\verb|[1]|$

$(LocalResource("media/fig3.6.png"))

"""

# ╔═╡ a68f4086-3a27-11eb-24d4-692815414617
md"""

## 🪐 Manifold-based Transfer Designs

* __Design Overview__ summarized from $\verb|[1]|$

### Design Overview

1. Find a desired Sun-Earth Halo orbit
2. Place the spacecraft within the __stable manifold__ of this Halo orbit
3. Perturb the spacecraft from the Halo onto the __unstable manifold__ to return towards Earth, and apply a maneuver to place the spacecraft on a Hyperbolic escape trajectory toward your destination planet
4. At destination planet, apply a maneuver to place spacecraft onto __stable manifold__ of destination Halo orbit

"""

# ╔═╡ 4b4fca98-3a2b-11eb-09d1-b358440b75fc
md"""

## 🚀 Conclusions

### Manifold Transfers
* Lagrange points, and periodic orbits about Lagrange points are surrounded by collections of trajectories called __manifolds__
* Manifolds can depart, or arrive at the Lagrange point / Libration orbit
* Stable manifolds can bring us to Halo orbits for free$^*$ (plus the cost to place the spacecraft onto the manifold)

### Lessons Learned

* Linear (Eigenvector) analysis works in Astrodynamics too
* Calculations for iterating on Halo orbits are __extremely__ numerically sensitive
* Even with more complicated models (CR3BP), we need a patch-conic-like approach for interplanetary mission design

"""

# ╔═╡ ddf8378a-3757-11eb-039b-254488a45127
md"""

## 📚 References

 $\verb|[1]|$ Rund, M. S., “Interplanetary Transfer Trajectories Using the Invariant Manifolds of Halo Orbits,” , 2018.

 $\verb|[2]|$ Howell, K. C., “Three-dimensional, periodic,‘halo’orbits,” Celestial mechanics, Vol. 32, No. 1, 1984, pp. 53–71.

 $\verb|[3]|$ Vallado, D. A., Fundamentals of astrodynamics and applications, Vol. 12, Springer Science & Business Media, 2001.

 $\verb|[4]|$ Richardson, D., “Analytical construction of periodic orbits about the collinear points of the Sun-Earth system.” asdy, 1980, p. 127.

 $\verb|[5]|$ Lara, M., Russell, R., and Villac, B., “Classification of the distant stability regions at Europa,” Journal of Guidance, Control, and Dynamics, Vol. 30, No. 2, 2007, pp. 409–418.

 $\verb|[6]|$ Koon, W. S., Lo, M. W., Marsden, J. E., and Ross, S. D., “Dynamical systems, the three-body problem and space mission design,” Free online Copy: Marsden Books, 2008.

 $\verb|[7]|$ Williams, J., Lee, D. E., Whitley, R. J., Bokelmann, K. A., Davis, D. C., and Berry, C. F., “Targeting cislunar near rectilinear halo orbits for human space exploration,” 2017.

 $\verb|[8]|$ Zimovan-Spreen, E. M., Howell, K. C., and Davis, D. C., “Near rectilinear halo orbits and nearby higher-period dynamical structures: orbital stability and resonance properties,” Celestial Mechanics and Dynamical Astronomy, Vol. 132, No. 5, 2020, pp. 1–25.

 $\verb|[9]|$ NASA, NASA’s Lunar Exploration Program Overview, 2020.

 $\verb|[10]|$ Carpinelli, J., “UnitfulAstrodynamics.jl,” https://juliahub.com/ui/Packages/UnitfulAstrodynamics/uJGLZ/, 2020.


"""

# ╔═╡ 1f0ebb78-3707-11eb-00da-2f08e79fd676
md"# ⌨️ Source Code"

# ╔═╡ d74f9638-369e-11eb-067c-05720a8f4d94
md"""

## Package Dependencies

* The following packages were used -- all are available in Julia's [General](https://juliahub.com) package registry

"""

# ╔═╡ 38842964-36a1-11eb-3b0c-bf5bb8000341
md"""

## Finding Lagrange Points

"""

# ╔═╡ f4c7e16e-36a7-11eb-17f3-2f62591cebe8
f₁ = let
	
	f₁ = lagrangeplot(nondimensionalize(Earth.μ, Moon.μ); labels=["Earth" "Moon"])
	savefig(f₁, "media/fig1.png")
	
	f₁
	
end;

# ╔═╡ deb34994-399e-11eb-28a7-7d63db867a11
md"""

## Lagrange Points

* Lagrange points are __equilibrium points__ within the Circular Restricted Three-body Problem

$(f₁)

"""

# ╔═╡ d54ed67a-39a0-11eb-2d9b-a7800fd0163a
md"## Unstable Lagrange Point (L2)"

# ╔═╡ 9fc039b8-38c4-11eb-305d-7bff22a6d965
f₂ = let
	
	μ = nondimensionalize(Earth.μ, Moon.μ)
	r = lagrange(μ, 2)[:]
	v = [0.0, 0.0, 0.0]
	
	sys = NondimensionalThreeBodyState(r, v, μ, NaN * u"km", NaN * u"s")
	sols = propagate(sys, 30; save_everystep=true, reltol=1e-16, abstol=1e-16)
	
	x = [sols.step[i].rₛ[1] for i ∈ 1:length(sols.step)]
	y = [sols.step[i].rₛ[2] for i ∈ 1:length(sols.step)]
	z = [sols.step[i].rₛ[3] for i ∈ 1:length(sols.step)]
	
	f₂ = plot(x,y; label="Spacecraft Position")
	scatter!(f₂, [[i] for i ∈ lagrange(μ, 2)[1:2]]...; label="L2", markershape=:x)
	scatter!(f₂, [[i] for i ∈ sys.r₁][1:2]...; label="Earth", markersize=7)
	scatter!(f₂, [[i] for i ∈ sys.r₂][1:2]...; label="Moon")
	plot!(f₂; title="Spacecraft Propagated from Earth-Moon L2", 
			  xlabel="X (AU)",
			  ylabel="Y (AU)")
	
	savefig(f₂, "media/fig2.png")
	
	f₂
	
end;

# ╔═╡ e3cf8532-39a0-11eb-0244-e509c5e55b75
md"## Stable Lagrange Point (L4)"

# ╔═╡ 37a8538c-3997-11eb-2649-2daacb98b8c8
f₇ = let
	
	μ = nondimensionalize(Earth.μ, Moon.μ)
	r = lagrange(μ, 4)[:] * (1 + 1e-3)
	v = [0.0, 0.0, 0.0]
	
	sys = NondimensionalThreeBodyState(r, v, μ, NaN * u"km", NaN * u"s")
	sols = propagate(sys, 1000; save_everystep=true, reltol=1e-16, abstol=1e-16)
	
	x = [sols.step[i].rₛ[1] for i ∈ 1:length(sols.step)]
	y = [sols.step[i].rₛ[2] for i ∈ 1:length(sols.step)]
	z = [sols.step[i].rₛ[3] for i ∈ 1:length(sols.step)]
	
	f₇ = plot(x,y; label="Spacecraft Position")
	scatter!(f₇, [[i] for i ∈ lagrange(μ, 4)[1:2]]...; label="L4", markershape=:x)
	scatter!(f₇, [[i] for i ∈ sys.r₁][1:2]...; label="Earth", markersize=7)
	scatter!(f₇, [[i] for i ∈ sys.r₂][1:2]...; label="Moon")
	plot!(f₇; title="Spacecraft Perturbed from Earth-Moon L4", 
			  xlabel="X (AU)",
			  ylabel="Y (AU)")
	
	savefig(f₂, "media/fig2.png")
	
	f₇
	
end;

# ╔═╡ 7d9da4e8-399f-11eb-35b2-11b9f4c1371f
md"""

## Stability at Lagrange Points: Examples

* Earth-Moon L4 is __stable__, and Earth-Moon L2 is __unstable__

$(plot(plot(f₂; title="Earth-Moon L2", labels=["" "" "" ""]), plot(f₇; title="Earth-Moon L4", legend=:right, labels=["Spacecraft Position" "L2 & L4" "Earth" "Moon"]))))

"""

# ╔═╡ e9e0717a-39a0-11eb-28bc-1bb42537ff43
md"## Plot Analytical Halo Orbit"

# ╔═╡ d251ce38-38dc-11eb-0fa6-653456709b32
function haloplot(μ, L, Z, H, str1="Mass 1", str2="Mass 2"; kwargs...)
	
	if L==:L1
		l = 1
	else
		l = 2
	end
	
	defaults = (; title="Analytical Halo Solutions", 
				  xlabel="X (DU)", ylabel="Y (DU)", zlabel="Z (DU)")
	options  = merge(defaults, kwargs)
	
	fig = plot(; options...)
	for z ∈ Z
		r,v,Τ = halo_analytic(μ; L=L, Zₐ=z, hemisphere=H, steps=1000)
		x = r[:,1]
		y = r[:,2]
		z = r[:,3]
		plot!(fig, x, y, z; label=:none)
		
	end
	
	scatter!(fig, [[v] for v ∈ lagrange(μ, l)]...; 
			 label=string("L",L), markershape=:x)
	scatter!(fig, [-μ], [0], [0]; label=str1)
	scatter!(fig, [1-μ], [0], [0]; label=str2)
	
	return fig
	
end;

# ╔═╡ f24c96cc-39a0-11eb-12ba-d33ac3e6a77d
md"## Northern Sun-Jupiter Halos"

# ╔═╡ cd021b9a-38dc-11eb-1f5b-1b3a2294ef56
f₃ = let
	
	μ = nondimensionalize(Sun.μ, Jupiter.μ)
	Z = [x / 10 for x ∈ 1:10]
	f₃ = haloplot(μ, 1, Z, :northern, "Sun", "Jupiter"; 
				  title="Northern Analytical Halo Solutions")
	
	savefig(f₃, "media/fig3.png")
	
	f₃
	
	
end;

# ╔═╡ fc4671ac-39a0-11eb-2867-f99155906347
md"## Southern Sun-Jupiter Halos"

# ╔═╡ c544f248-38ea-11eb-1a76-f763700e5e66
f₄ = let
	
	μ = nondimensionalize(Sun.μ, Jupiter.μ)
	Z = [x / 10 for x ∈ 1:10]
	f₄ = haloplot(μ, 1, Z, :southern, "Sun", "Jupiter"; 
				  title="Southern Analytical Halo Solutions")
	
	savefig(f₄, "media/fig4.png")
	
	f₄
	
	
end;

# ╔═╡ 41c340f0-39a8-11eb-375a-c311f97cb062
md"""

## Analytical Halo Examples: Sun-Jupiter L1

__NOT numerically propagated!__

$(plot(f₄; title=" Sun-Jupiter Halo Examples"))

"""

# ╔═╡ 032912e0-39a1-11eb-23d7-a1be4cc91e98
md"## Northern Earth-Moon Halos"

# ╔═╡ 2b968ad4-38eb-11eb-106a-7fc6c7b60bc0
f₅ = let
	
	μ = nondimensionalize(Earth.μ, Moon.μ)
	Z = [x / 10 for x ∈ 1:10]
	f₅ = haloplot(μ, 2, Z, :northern, "Earth", "Moon"; 
				  title="Northern Analytical Halo Solutions")
	
	savefig(f₅, "media/fig5.png")
	
	f₅
	
	
end;

# ╔═╡ 868a7c00-39a6-11eb-23d8-43efa8cea0a2
md"""

## Analytical Halo Examples: Earth-Moon L2

__NOT numerically propagated!__

$(plot(f₅; title="Earth-Moon Halo Examples"))

"""

# ╔═╡ 0c26f664-39a1-11eb-2d2c-75cc99d2a193
md"## Southern Earth-Moon Halos"

# ╔═╡ 4e5b126a-38eb-11eb-30d4-03206b35fd53
f₆ = let
	
	μ = nondimensionalize(Earth.μ, Moon.μ)
	Z = [x / 10 for x ∈ 1:10]
	f₆ = haloplot(μ, 2, Z, :southern, "Earth", "Moon"; 
				  title="Southern Analytical Halo Solutions")
	
	savefig(f₆, "media/fig6.png")
	
	f₆
	
	
end;

# ╔═╡ bbc1be44-3a44-11eb-3da2-19023d2871d1
md"## Numerically Produced Halo"

# ╔═╡ 5c42be9c-39be-11eb-1fb0-05e460b4bd2f
f₈ = let
	
	r,v,T = halo(μ, L=2, Zₐ=0.05, ϕ=0.05, max_iter=20)
	sys = NondimensionalThreeBodyState(r,v,μ, NaN*u"km", NaN*u"s")
	sols = propagate(sys, T)
	x = [x.rₛ[1] for x ∈ sols.step]
	y = [x.rₛ[2] for x ∈ sols.step]
	z = [x.rₛ[3] for x ∈ sols.step]
	
	f₈ = plot(x,y,z; label="Spacecraft Position")
	plot!(f₈; title="Numerically Produced Earth-Moon L2 Halo", 
			xlabel="X (DU)", ylabel="Y (DU)", zlabel="Z (DU)")
	
	savefig(f₈, "media/fig8.png")
	
	f₈
	
end;

# ╔═╡ Cell order:
# ╟─860ea13a-369e-11eb-34b2-3fc6557a68d6
# ╟─2f3bcf58-3758-11eb-352c-a1181281eba0
# ╟─deb34994-399e-11eb-28a7-7d63db867a11
# ╟─fc4106f6-399e-11eb-1f9f-e7c4d5539f20
# ╟─7d9da4e8-399f-11eb-35b2-11b9f4c1371f
# ╟─8c0a0a9c-39a1-11eb-1fe6-c7177fa4b5a8
# ╟─95a851d0-39a1-11eb-05b1-81fbb6c0bd54
# ╟─868a7c00-39a6-11eb-23d8-43efa8cea0a2
# ╟─41c340f0-39a8-11eb-375a-c311f97cb062
# ╟─bf3ee972-39ac-11eb-2bdb-fd28bebd418e
# ╟─b123e506-39af-11eb-06b3-cfb02d9d50fc
# ╟─542fc7e8-3a27-11eb-0284-07c4a6f626f5
# ╟─a68f4086-3a27-11eb-24d4-692815414617
# ╟─4b4fca98-3a2b-11eb-09d1-b358440b75fc
# ╟─ddf8378a-3757-11eb-039b-254488a45127
# ╟─1f0ebb78-3707-11eb-00da-2f08e79fd676
# ╟─d74f9638-369e-11eb-067c-05720a8f4d94
# ╠═9739e5dc-369e-11eb-2c56-f36ccd348299
# ╟─38842964-36a1-11eb-3b0c-bf5bb8000341
# ╠═f4c7e16e-36a7-11eb-17f3-2f62591cebe8
# ╟─d54ed67a-39a0-11eb-2d9b-a7800fd0163a
# ╠═9fc039b8-38c4-11eb-305d-7bff22a6d965
# ╟─e3cf8532-39a0-11eb-0244-e509c5e55b75
# ╠═37a8538c-3997-11eb-2649-2daacb98b8c8
# ╟─e9e0717a-39a0-11eb-28bc-1bb42537ff43
# ╠═d251ce38-38dc-11eb-0fa6-653456709b32
# ╟─f24c96cc-39a0-11eb-12ba-d33ac3e6a77d
# ╠═cd021b9a-38dc-11eb-1f5b-1b3a2294ef56
# ╟─fc4671ac-39a0-11eb-2867-f99155906347
# ╠═c544f248-38ea-11eb-1a76-f763700e5e66
# ╟─032912e0-39a1-11eb-23d7-a1be4cc91e98
# ╠═2b968ad4-38eb-11eb-106a-7fc6c7b60bc0
# ╟─0c26f664-39a1-11eb-2d2c-75cc99d2a193
# ╠═4e5b126a-38eb-11eb-30d4-03206b35fd53
# ╟─bbc1be44-3a44-11eb-3da2-19023d2871d1
# ╠═5c42be9c-39be-11eb-1fb0-05e460b4bd2f
