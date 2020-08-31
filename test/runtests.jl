using SplitDataset
using PaddedBlocks
using Test

@testset "reading" begin
    a = reshape(1:81, 9, 9)
    mktempdir() do tdir
        ds = H5SplitDataset(tdir, a, (3, 3))
        @test all(a[1:4, 1:4] == ds[1:4, 1:4])
    end
end

@testset "incremental writing" begin
    T = UInt16
    a = T.(reshape(1:9*9*9, 9, 9, 9))
    bs = (1, 3, 3)
    mktempdir() do tdir
        ds = H5SplitDataset(T, tdir, size(a), bs)
        bl = Blocks(size(a),bs)
        for sls in PaddedBlocks.slices(bl)
            ds[sls...] .= a[sls...]
        end
        @test all(a .== ds[:, :, :])
    end
end
