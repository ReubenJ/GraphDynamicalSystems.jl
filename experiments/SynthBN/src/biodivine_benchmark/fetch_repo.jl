using CondaPkg
using PythonCall
using Git

function fetch_biodivine_benchmark()
    raw_src_dir = datadir("src_raw", "biodivine-boolean-models")
    remote = "git@github.com:ReubenJ/biodivine-boolean-models.git"
    commit_hash = "d89c97f7ba233999acbb2e8b1442631d685b5b22"
    checkout_cmd = `$(git()) checkout $commit_hash`

    if ispath(raw_src_dir)
        cd(raw_src_dir)
        try
            run(`$(git()) pull`)
            run(checkout_cmd)
        catch
            @error "Error pulling from git remote, see git output above."
        end
    else
        run(`$(git()) clone $remote $raw_src_dir`)
        cd(raw_src_dir)
        run(checkout_cmd)
    end
end

function bundle_biodivine_benchmark()
    run(
        `python bundle.py --format aeon --inputs free --filter "" --output-dir bbm-aeon-format`,
    )
end
