using ITensors
using ITensorMPS
using Plots

println("1. Intelligent Index Contraction")

# unique index objects with specific dimensions
i = Index(2, "index_i")
j = Index(3, "index_j")
k = Index(4, "index_k")

# random ITensors with the specified indices (order of indices does not matter)
A = randomITensor(i, j)
B = randomITensor(j, k)

C = A * B 
@show C

println("\n2. BENCHMARK 1: Time & Energy vs. System Size")

function run_dmrg_simulation(N)
    sites = siteinds("S=1/2", N) # S=1/2 electrons

    # making Hamiltonian operator
    # represents interacting spins and exchange interactions
    os = OpSum()
    for j in 1:(N-1)
        os += 1.0, "Sz", j, "Sz", j+1
        os += 0.5, "S+", j, "S-", j+1
        os += 0.5, "S-", j, "S+", j+1
    end
    H = MPO(os, sites)

    psi0 = randomMPS(sites; linkdims=10) # random initial state

    # setting up DMRG parameters (sweeps)
    # as sweeps progress, tracking matrix size (maxdim) increases
    nsweeps = 5
    maxdim = [10, 20, 100, 100]
    cutoff = [1E-10]

    time_taken = @elapsed begin
        energy, psi = dmrg(H, psi0; nsweeps, maxdim, cutoff, outputlevel=0)
    end

    return energy, time_taken
end

energies = Float64[]
times = Float64[]

# electron chain sizes
system_sizes = [10, 20, 30, 40, 50]

println("Starting benchmark across different system sizes...\n")
println("-------------------------------------------------------")
println("N spins    | Ground State Energy    | Time Taken (s)")
println("-------------------------------------------------------")

# warm-up simulation so physics is compiled before tracking time
run_dmrg_simulation(4)

for N in system_sizes
    energy, time_taken = run_dmrg_simulation(N)

    push!(energies, energy)
    push!(times, time_taken)
    
    spacing = " " ^ (10 - length(string(N)))
    println(N, spacing, " | ", energy, " | ", round(time_taken, digits=4))
end
println("-------------------------------------------------------")

println("\n3. BENCHMARK 2: Energy Error vs. Bond Dimension")

# modified function for testing bond dimensions
function run_dmrg_with_maxdim(N, bond_dim)
    sites = siteinds("S=1/2", N)

    os = OpSum()
    for j in 1:(N-1)
        os += 1.0, "Sz", j, "Sz", j+1
        os += 0.5, "S+", j, "S-", j+1
        os += 0.5, "S-", j, "S+", j+1
    end
    H = MPO(os, sites)

    psi0 = randomMPS(sites; linkdims=2)

    nsweeps = 8
    maxdim_sequence = fill(bond_dim, nsweeps)
    cutoff = [1E-12]

    energy, psi = dmrg(H, psi0; nsweeps, maxdim=maxdim_sequence, cutoff, outputlevel=0)
    return energy
end

fixed_N = 20

println("Calculating highly converged refernce energy (maxdim = 100) for N = $fixed_N...")
reference_energy = run_dmrg_with_maxdim(fixed_N, 100)
println("Reference Energy: ", reference_energy, "\n")

test_maxdims = [4, 6, 8, 10, 14, 18, 22, 30, 40]
energy_errors = Float64[]

println("-------------------------------------------------------")
println("maxdim     | Calculated Energy    | Energy Error (ΔE)")
println("-------------------------------------------------------")

for m in test_maxdims
    energy = run_dmrg_with_maxdim(fixed_N, m)

    error = energy - reference_energy
    error = max(error, 1E-14) # avoid log(0) issues

    push!(energy_errors, error)

    spacing = " " ^ (10 - length(string(m)))
    println(m, spacing, " | ", energy, " | ", error)
end
println("-------------------------------------------------------")

println("\nGenerating plots...")

# Plot 1: Time vs. System Size
p1 = plot(system_sizes, times,
    title="DMRG Time vs. System Size",
    xlabel="Number of Spins (N)",
    ylabel="Time Taken (s)",
    marker=:circle,
    linewidth=2,
    legend=false,
    color=:blue
)
savefig(p1, "dmrg_time_vs_system_size.png")

# Plot 2: Energy vs. System Size
p2 = plot(system_sizes, energies,
    title="Ground State Energy vs. System Size",
    xlabel="Number of Spins (N)",
    ylabel="Ground State Energy",
    marker=:circle,
    linewidth=2,
    legend=false,
    color=:red
)
savefig(p2, "dmrg_energy_vs_system_size.png")

# Plot 3: Energy Error vs. Bond Dimension
p3 = plot(test_maxdims, energy_errors,
    title="Energy Error vs. Bond Dimension",
    xlabel="Maximum Allowed Bond Dimension (maxdim)",
    ylabel="Ground-State Energy Error (ΔE)",
    yscale=:log10,
    marker=:circle,
    markersize=5,
    linewidth=2,
    color=:purple,
    legend=false
)
savefig(p3, "dmrg_energy_error_vs_maxdim.png")

println("Done!")