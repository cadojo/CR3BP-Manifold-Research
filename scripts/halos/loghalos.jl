#
# This finds Normalized, Synodic, Cartesian states 
# for Halo Orbits near L1 & L2 for a variety of 
# normalized CR3BP systems. 
#
# Currently, nondimensional mass parameters are
# used which are close to those in the Sun-Earth,
# Earth-Moon, Sun-Mars, and Sun-Jupiter systems.
#

using DrWatson; @quickactivate "Halo-Explorations"

using CSV
using DataFrames
using UnitfulAstrodynamics

massparameters = let 
    planets = (Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune)
    planet_params = map(planet->nondimensionalize(mass_parameter(Sun), mass_parameter(planet)), planets)
    earth_moon    = nondimensionalize(mass_parameter(Earth), mass_parameter(Moon))
    vcat(planet_params[1:2]..., earth_moon, planet_params[3:end]...)
end

names = [
    "Sun-Venus", "Sun-Earth", 
    "Earth-Moon", "Sun-Mars", 
    "Sun-Jupiter", "Sun-Saturn", 
    "Sun-Uranus", "Sun-Neptune"
]

amplitudes = 0.0:1e-6:0.01
 
@assert length(names) == length(massparameters) "Invalid configuration!"

Threads.@threads for i = 1:length(names)
    μ = massparameters[i]
    name = names[i]
    orbits = DataFrame(
        MassParameter=Float64[], LagrangePoint=Int[], ZAmplitude=Float64[], JacobiConstant=Float64[], Period=Float64[], 
        Rx=Float64[], Ry=Float64[], Rz=Float64[], Vx=Float64[], Vy=Float64[], Vz=Float64[])
    for L ∈ (1,2)
        fail_count = 0
        for Az ∈ amplitudes
            fail_count < 10 || break
            r, v, T = halo(μ; Az = Az, L = L, max_iter=20, nan_on_fail=true, disable_warnings=true);
            if T ≥ one(T) && all(el->!isnan(el), r) && all(el->!isnan(el), v) && isperiodic(CircularRestrictedThreeBodyOrbit(r,v,μ), T)
                push!(orbits, (μ, L, Az, jacobi_constant(r, v, μ), T, r..., v...))
            else
                fail_count += 1
            end
        end
    end
    @info "Finished processing $name Halos!"
    CSV.write(datadir("exp_pro", "halos", lowercase(string(name,"-Halos.csv"))), orbits)
end

open(datadir("exp_pro", "halos", "README.md"), "w") do io
    write(io, 
    """
    # How are the Halo CSV files formatted?
    * The columns from left to right are: 
      1. Nondimensional mass parameter
      2. Lagrange point (1 or 2)
      3. Nondimensional Z amplitude
      4. Jacobi Constant
      5. Nondimensional orbital period
      6. Nondimensional X
      7. Nondimensional Y
      8. Nondimensional Z
      9. Nondimensional Ẋ
      10. Nondimensional Ẏ
      11. Nondimensional Ż
    """)
end




