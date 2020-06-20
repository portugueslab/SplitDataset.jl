using SplitDataset
using Documenter

makedocs(;
    modules=[SplitDataset],
    authors="vilim <vilim@neuro.mpg.de> and contributors",
    repo="https://github.com/portugueslab/SplitDataset.jl/blob/{commit}{path}#L{line}",
    sitename="SplitDataset.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://portugueslab.github.io/SplitDataset.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/portugueslab/SplitDataset.jl",
)
