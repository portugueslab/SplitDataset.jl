using SplitDataset
using Test

@testset "SplitDataset.jl" begin
    a = reshape(1:81, 9, 9)
    mktempdir() do tdir
        ds = H5SplitDataset(tdir, a, (3, 3))
        @test all(a[1:4, 1:4] == ds[1:4, 1:4])
    end
end
