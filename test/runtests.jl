using Logging
using PowerSimulations
using PowerSystems
using PowerModels
using InfrastructureSystems
using DataFrames
using Dates
using Feather
using JuMP
using Test
using Ipopt
using GLPK
using Cbc
using OSQP
using TimeSeries
using ParameterJuMP
using TestSetExtensions

import PowerSystems.UtilsData: TestData
download(TestData; branch = "master")

const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const PJ = ParameterJuMP
const IS = InfrastructureSystems
abstract type TestOpProblem<:PSI.AbstractOperationsProblem end

ipopt_optimizer = JuMP.with_optimizer(Ipopt.Optimizer, print_level=0)  # use default print_level = 5
                                                        # set to 0 to disable
ipopt_ws_solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, mu_init=1e-4)
GLPK_optimizer = JuMP.with_optimizer(GLPK.Optimizer, msg_lev = GLPK.MSG_OFF)
Cbc_optimizer = JuMP.with_optimizer(Cbc.Optimizer, logLevel=0)
OSQP_optimizer = JuMP.with_optimizer(OSQP.Optimizer, verbose = false)

const LOG_FILE = "power-simulations-test.log"

LOG_LEVELS = Dict(
    "Debug" => Logging.Debug,
    "Info" => Logging.Info,
    "Warn" => Logging.Warn,
    "Error" => Logging.Error,
)

function get_logging_level(env_name::String, default)
    level = get(ENV, env_name, default)
    log_level = get(LOG_LEVELS, level, nothing)
    if isnothing(log_level)
        error("Invalid log level $level: Supported levels: $(values(LOG_LEVELS))")
    end

    return log_level
end

function run_tests()
    console_level = get_logging_level("SYS_CONSOLE_LOG_LEVEL", "Error")
    console_logger = ConsoleLogger(stderr, console_level)
    file_level = get_logging_level("SYS_LOG_LEVEL", "Info")

    IS.open_file_logger(LOG_FILE, file_level) do file_logger
        multi_logger = IS.MultiLogger(
            [console_logger, file_logger],
            IS.LogEventTracker((Logging.Info, Logging.Warn, Logging.Error)),
        )
        global_logger(multi_logger)

        include("test_utils/get_test_data.jl")
        include("test_utils/model_checks.jl")
        include("test_utils/operations_problem_templates.jl")

        @time @testset "Begin PowerSimulations tests" begin
            @includetests ARGS
        end

        # TODO: Enable this once all expected errors are not logged.
        #@test length(IS.get_log_events(multi_logger.tracker, Logging.Error)) == 0

        @info IS.report_log_summary(multi_logger)
    end
end

logger = global_logger()

try
    run_tests()
finally
    # Guarantee that the global logger is reset.
    global_logger(logger)
    nothing
end
