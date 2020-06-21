# SplitDataset [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://portugueslab.github.io/SplitDataset.jl/stable) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://portugueslab.github.io/SplitDataset.jl/dev) [![Build Status](https://github.com/portugueslab/SplitDataset.jl/workflows/CI/badge.svg)](https://github.com/portugueslab/SplitDataset.jl/actions) [![Coverage](https://codecov.io/gh/portugueslab/SplitDataset.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/portugueslab/SplitDataset.jl)

Julia package for reading datasets split blockwise into multiple HDF5 files. It is the Julia analogue of [SplitDataset](https://github.com/portugueslab/split_dataset) in Python. 

Provides a `H5SplitDataset` that can be treated as a [`DiskArray`](https://github.com/meggart/DiskArrays.jl)

To load files, use the folder-argument constructor.

```julia
H5SplitDataset(folder::String) # opens a SplitDataset from a folder containing h5 and json files
```

To write whole arrays, use the following constructor.

```julia
H5SplitDataset(
    folder,
    a::AbstractArray{T,N},
    block_size::NTuple{N,Int},
)
```

Writing parts of arrays is currently not supported. This package is an intermediate solution until Zarr supports all the features we need.