using DrWatson

@quickactivate

using PythonCall
using Git

raw_src_dir = datadir("src_raw", "biodivine-boolean-models")

if ispath(raw_src_dir)
    cd(() -> run(`$(git()) pull`), raw_src_dir)
else
    run(
        `$(git()) clone https://github.com/sybila/biodivine-boolean-models.git $raw_src_dir`,
    )
end


# biodivine_aeon = pyimport("biodivine_aeon")
