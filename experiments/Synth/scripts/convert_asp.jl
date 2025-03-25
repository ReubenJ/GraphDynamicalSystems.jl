"entity($(join(only(unique(df.vertex_names)), ";")))."

eas = only(df[df.index_of_vertex.==1, :exprs_and_scores])

# get state space that solutions create
Set(getindex.(eas, 3))

# get states
Dict([i => x for (i, x) in enumerate(Set(hcat(collect.(df.selected_trajectories[1])...)))])

states = df.selected_trajectories |> Iterators.flatten |> Iterators.flatten |> collect
ids = eachindex(states)
"state(1..$(ids.stop))."

# Get the

for row in eachrow(df)
    for (expr, score, topology, idx) in row.exprs_and_scores
        @show expr, topology

    end
    break
end
