module TestSetup

using Intan

include("board_test.jl")
include("gui_test.jl")
include("registers_test.jl")
include("tasks_test.jl")
include("filter_test.jl")
include("save_load_test.jl")

end
