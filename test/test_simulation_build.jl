path = joinpath(pwd(), "test_sequence_build")
!isdir(path) && mkdir(path)

function test_sequence_build(file_path::String)
    stages_definition = Dict(
        "UC" => Stage(GenericOpProblem, template_basic_uc, c_sys5_uc, GLPK_optimizer),
        "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer),
    )

    sequence = SimulationSequence(
        step_resolution = Hour(24),
        order = Dict(1 => "UC", 2 => "ED"),
        feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
        horizons = Dict("UC" => 24, "ED" => 12),
        intervals = Dict(
            "UC" => (Hour(24), Consecutive()),
            "ED" => (Hour(1), Consecutive()),
        ),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_from_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        ini_cond_chronology = InterStageChronology(),
    )

    @testset "Test Simulation Simulation Sequence Validation" begin
        @test length(findall(x -> x == 2, sequence.execution_order)) == 24
        @test length(findall(x -> x == 1, sequence.execution_order)) == 1
    end

    @testset "Simulation with provided initial time" begin
        second_day = DayAhead[24] + Hour(1)
        sim = Simulation(
            name = "test",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
            initial_time = second_day,
        )
        build!(sim)

        for stage in values(sim.stages)
            @test stage.internal.psi_container.initial_time == second_day
        end
    end

    sim = Simulation(
        name = "test",
        steps = 1,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
    )
    build!(sim)

    @testset "Simulation Build Tests" begin
        build!(sim)
        @test isempty(values(sim.internal.simulation_cache))
        for field in fieldnames(SimulationSequence)
            if fieldtype(SimulationSequence, field) == Union{Dates.DateTime, Nothing}
                @test !isnothing(getfield(sim.sequence, field))
            end
        end
        @test isa(sim.sequence, SimulationSequence)
    end

    ###################### Negative Tests ########################################
    @testset "Testing when a simulation has incorrect arguments" begin
        sim = Simulation(name = "test", steps = 1, simulation_folder = file_path)
        @test_throws ArgumentError build!(sim)
    end

    @testset "Testing if a wrong initial time is provided" begin

        sim = Simulation(
            name = "test",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
            initial_time = Dates.now(),
        )
        @test_throws IS.ConflictingInputsError build!(sim)
    end

    @testset "Testing if file path is not writeable" begin
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "fake_path",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = "fake_path",
        )
        @test_throws IS.ConflictingInputsError PSI._check_folder(sim.simulation_folder)
    end

    @testset "chronology look ahead length is too long for horizon" begin
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 30)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "look_ahead",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        @test_throws IS.ConflictingInputsError PSI._check_feedforward_chronologies(sim)
    end

    @testset "too long of a horizon for forecast" begin
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 72, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "long_horizon",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        sim.internal = PSI.SimulationInternal(sim.steps, keys(sim.sequence.order))
        @test_throws IS.ConflictingInputsError PSI._get_simulation_initial_times!(sim)
    end

    @testset "too many steps for forecast" begin
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "steps",
            steps = 5,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        sim.internal = PSI.SimulationInternal(sim.steps, keys(sim.sequence.order))
        stage_initial_times = PSI._get_simulation_initial_times!(sim)
        @test_throws IS.ConflictingInputsError PSI._check_steps(sim, stage_initial_times)
    end

    @testset "Creation of Simulations with Cache" begin

        stages_definition_standard_uc = Dict(
            "UC" => Stage(
                GenericOpProblem,
                template_standard_uc,
                c_sys5_uc,
                GLPK_optimizer,
            ),
            "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer),
        )

        # Cache is not defined all together
        sequence_no_cache = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "cache",
            steps = 1,
            stages = stages_definition_standard_uc,
            stages_sequence = sequence_no_cache,
            simulation_folder = file_path,
        )
        @test_throws ArgumentError build!(sim)

        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict(("UC",) => TimeStatusChange(PSY.ThermalStandard, PSI.ON)),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "caches",
            steps = 2,
            stages = stages_definition_standard_uc,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )

        build!(sim)

        @test !isempty(sim.internal.simulation_cache)

        # Uses IntraStage but the cache is defined in the wrong stage
        sequence_bad_cache = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict(("ED",) => TimeStatusChange(PSY.ThermalStandard, PSI.ON)),
            ini_cond_chronology = IntraStageChronology(),
        )

        sim = Simulation(
            name = "test",
            steps = 1,
            stages = stages_definition_standard_uc,
            stages_sequence = sequence_bad_cache,
            simulation_folder = file_path,
        )
        @test_throws IS.InvalidValue build!(sim)

    end

end

try
    test_sequence_build(path)
finally
    @info("removing test files")
    rm(path, recursive = true)
end
