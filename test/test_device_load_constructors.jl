@testset "Load data misspecification" begin
    model = DeviceModel(InterruptibleLoad, DispatchablePowerLoad)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    warn_message = "The data doesn't include devices of type InterruptibleLoad, consider changing the device models"
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        op_problem,
        model,
    )
    model = DeviceModel(PowerLoad, DispatchablePowerLoad)
    warn_message = "The Formulation DispatchablePowerLoad only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad"
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        op_problem,
        model,
    )
end

@testset "StaticPowerLoad" begin
    models = [StaticPowerLoad, DispatchablePowerLoad, InterruptiblePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [DCPPowerModel, ACPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PowerLoad, m)
        op_problem =
            OperationsProblem(MockOperationProblem, n, c_sys5_il; use_parameters = p)
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 0, 0, 0, 0, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "DispatchablePowerLoad DC- PF" begin
    models = [DispatchablePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [DCPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(InterruptibleLoad, m)
        op_problem =
            OperationsProblem(MockOperationProblem, n, c_sys5_il; use_parameters = p)
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 24, 0, 24, 0, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "DispatchablePowerLoad AC- PF" begin
    models = [DispatchablePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [ACPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(InterruptibleLoad, m)
        op_problem =
            OperationsProblem(MockOperationProblem, n, c_sys5_il; use_parameters = p)
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 48, 0, 24, 0, 24, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "InterruptiblePowerLoad DC- PF" begin
    models = [InterruptiblePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [DCPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(InterruptibleLoad, m)
        op_problem =
            OperationsProblem(MockOperationProblem, n, c_sys5_il; use_parameters = p)
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 48, 0, p * 48 + !p * 24, 0, 0, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "InterruptiblePowerLoad AC- PF" begin
    models = [InterruptiblePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [ACPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(InterruptibleLoad, m)
        op_problem =
            OperationsProblem(MockOperationProblem, n, c_sys5_il; use_parameters = p)
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 72, 0, p * 48 + !p * 24, 0, 24, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end
