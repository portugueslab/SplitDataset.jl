module SplitDataset

using DiskArrays
using Glob
using HDF5
using JSON3
using Printf
using PaddedBlocks

struct H5SplitDataset{T,N} <: AbstractDiskArray{T, N}
    files::Array{String,1}
    blocks::Blocks{N}
    stackname::String
end

haschunks(a::H5SplitDataset) = DiskArrays.Chunked()
eachchunk(a::H5SplitDataset) = DiskArrays.GridChunks(a, a.blocks.block_size)
Base.size(a::H5SplitDataset) = a.blocks.full_size

"Collects filenames and block dimensions for a HDF5 dataset"
function file_blocks_names(path)
    return h5open(path, "r") do file
        return Blocks(
            Int64.(tuple(collect_attributes(file["stack_metadata"]["full_size"])...)[end:-1:1]),
            Int64.(tuple(collect_attributes(file["stack_metadata"]["block_size"])...)[end:-1:1]),
        ),
        collect_attributes(file["stack_metadata"]["files"])
    end
end

function stack_metadata_from_json(path)
    mddict = open(path, "r") do f
        return JSON3.read(f)
    end
    return Blocks(
        Int64.(Tuple(mddict["shape_full"]))[end:-1:1],
        Int64.(Tuple(mddict["shape_block"]))[end:-1:1],
    )
end

function H5SplitDataset(folder::String, prefix::String = "")
    jsonpath = joinpath(folder, "stack_metadata.json")
    files = sort(glob(prefix * "*.h5", folder))
    if isfile(jsonpath)
        blocks = stack_metadata_from_json(jsonpath)
        filenames = files
    else
        blocks, filenames = file_blocks_names(files[end])
    end
    n_dim = length(blocks.full_size)

    stack_name = h5open(files[1]) do f
        if "stack" in names(f)
            return "stack"
        else
            return "stack_$(n_dim)D"
        end
    end

    el1 = h5read(files[1], stack_name, tuple((1:1 for _ in 1:n_dim)...))
    return H5SplitDataset{eltype(el1),n_dim}(files, blocks, stack_name)
end

function H5SplitDataset(T, path, full_size::NTuple{N, Int}, block_size::NTuple{N, Int}) where {N}
    blocks = Blocks(Int64.(full_size), Int64.(block_size))
    files = [joinpath(path, @sprintf("%04d.h5", i)) for i in 0:(length(blocks)-1)]
    if !isdir(path)
        mkpath(path)
    end
    open(joinpath(path, "stack_metadata.json"), "w") do f
        return JSON3.write(
            f,
            Dict(
                "shape_full" => blocks.full_size[end:-1:1],
                "shape_block" => blocks.block_size[end:-1:1],
            ),
        )
    end    
    return H5SplitDataset{T, length(full_size)}(files, blocks, "stack")
end

function H5SplitDataset(
    folder,
    a::AbstractArray{T,N},
    block_size::NTuple{N,Int},
) where {N,T}
    blocks = Blocks(size(a), block_size)
    mkpath(folder)
    files = String[]
    for (i_block, sl) in enumerate(slices(blocks))
        filename = @sprintf("%04d.h5", i_block)
        push!(files, filename)
        savepath = joinpath(folder, filename)
        el1 = h5write(savepath, "stack_$(N)D", a[sl...])
    end
    open(joinpath(folder, "stack_metadata.json"), "w") do f
        return JSON3.write(
            f,
            Dict(
                "shape_full" => blocks.full_size[end:-1:1],
                "shape_block" => blocks.block_size[end:-1:1],
            ),
        )
    end
    return H5SplitDataset(folder)
end


"Collects attributes form a group in a deepdish-saved HDF5 file"
function collect_attributes(hgroup)
    atrnms = names(attrs(hgroup))
    nums = sort([
        begin
            mtch = match(r"i(\d+)", nam)
            parse(mtch.captures[1])
        end for nam in filter(n -> ismatch(r"i(\d+)", n), atrnms)
    ])
    return [read(attrs(hgroup)["i$i"]) for i in nums]
end


function get_matching_slices(f_idx, file_limits, block_limits, block_size)
    source_slices = tuple((
        (ci == s ? si : 1):(ci == e ? ei : bs)
        for
        (ci, s, e, si, ei, bs) in zip(
            f_idx,
            file_limits[1, :],
            file_limits[2, :],
            block_limits[1, :],
            block_limits[2, :], 
            block_size  
        ))...)

    read_size = tuple((sl.stop - sl.start + 1 for sl in source_slices)...)

    rel_idx = f_idx .- tuple(file_limits[1, :]...) .+ 1
    target_slices = tuple((
        begin
            st = (st_idx == 1 ? 1 : (st_idx - 2) * bs + bs - first_idx + 2)
            st:(st+sz-1)
        end for
        (st_idx, bs, first_idx, sz) in
        zip(rel_idx, block_size, block_limits[1, :], read_size)
    )...)
    return source_slices, target_slices
end

function DiskArrays.readblock!(dset::H5SplitDataset{T, N}, target, i::AbstractUnitRange...) where {T,N}
    idx = i
    file_limits, block_limits = PaddedBlocks.blocks_to_take(dset.blocks, idx)
    s2i = LinearIndices(dset.blocks.blocks_per_dim)
    for f_idx in
        Iterators.product((s:e for (s, e) in zip(file_limits[1, :], file_limits[2, :]))...)
        i_file = s2i[f_idx...]
        source_slices, target_slices = get_matching_slices(f_idx, file_limits, block_limits, dset.blocks.block_size)
        ar = h5read(dset.files[i_file], dset.stackname, source_slices)
        target[target_slices...] .= ar
       
    end
end

function DiskArrays.writeblock!(dset::H5SplitDataset{T, N}, target, i::AbstractUnitRange...) where {T,N}
    idx = i
    file_limits, block_limits = PaddedBlocks.blocks_to_take(dset.blocks, idx)
    s2i = LinearIndices(dset.blocks.blocks_per_dim)
    for f_idx in
        Iterators.product((s:e for (s, e) in zip(file_limits[1, :], file_limits[2, :]))...)
        i_file = s2i[f_idx...]

        source_slices, target_slices = get_matching_slices(f_idx, file_limits, block_limits, dset.blocks.block_size)
        
        # TODO handle wrong existing datasets
        h5open(dset.files[i_file], "cw") do fid
            if !exists(fid, dset.stackname)
                h5dset = d_create(fid, dset.stackname, datatype(T),
                dataspace(dset.blocks.block_size...),
                "chunk", HDF5.heuristic_chunk(T, (dset.blocks.block_size)), "blosc", 3)
            else
                h5dset = fid[dset.stackname]
            end

            h5dset[source_slices...] = target[target_slices...]
        end
       
    end
end

export H5SplitDataset

end
