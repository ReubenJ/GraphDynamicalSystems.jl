using DrWatson

@quickactivate :SynthBN


@info "Cloning the biodivine benchmark repository"
raw_src_dir = datadir("src_raw", "biodivine-boolean-models")
if !isdir(raw_src_dir)
    get_biodivine_repo(raw_src_dir)
end

@info "Bundling the benchmark to .aeon format"
aeon_bundle_dir = joinpath(raw_src_dir, "bbm-aeon-format")
if !isdir(aeon_bundle_dir)
    bundle_biodivine_benchmark(raw_src_dir, aeon_bundle_dir)
end

@info "Parsing .aeon model files"
load_aeon_biodivine()

@info "Converting to MetaGraph-based models"
convert_aeon_models_to_metagraphs()
