using CommonHighlight
using Test

@testset "CommonHighlight" begin
	setting=CommonHighlightSetting()
	@testset "Plain" begin
		t_pl=(str::String, res::Vector) -> begin
			highlight_lines(str, :plain, setting).lines == res
		end
		@test t_pl("1\n2", [("plain" => "1",), ("plain" => "2",)])
		@test t_pl("1\n2\n", [("plain" => "1",), ("plain" => "2",), ("plain" => "",)])
		@test t_pl("1\n\n2", [("plain" => "1",), ("plain" => "",), ("plain" => "2",)])
	end
	@testset "Shell" begin
		s_pl=(str::String, res::Vector) -> begin
			highlight_lines(str, :shell, setting).lines == res
		end
		@test s_pl("\$ login\n\$ ls\n1.txt", [
			("shell" => "\$", "plain" => " login"),
			("shell" => "\$", "plain" => " ls"),
			("plain" => "1.txt",)
		])
		@test s_pl("vir#> cat 文字\nvir#>", [
			("shell" => "vir#>", "plain" => "cat 文字"),
			("shell" => "vir#>",)
		])
		@test s_pl("vir#> \$ 文字\nvir#> ", [
			("shell" => "vir#>", "plain" => "\$ 文字"),
			("shell" => "vir#>", "plain" => " ")
		])
	end
end
