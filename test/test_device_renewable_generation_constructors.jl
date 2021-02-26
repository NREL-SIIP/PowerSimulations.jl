@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type RenewableDispatch, consider changing the device models"
    model = DeviceModel(RenewableDispatch, RenewableFullDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")

    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        op_problem,
        model,
    )
end

@testset "Renewable DCPLossLess FullDispatch" begin
    model = DeviceModel(RenewableDispatch, RenewableFullDispatch)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")

    #5 Bus testing case
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_re)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 72, 0, 72, 0, 0, false)

    psi_checkobjfun_test(op_problem, GAEVF)

    # Using Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_re;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 72, 0, 72, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_re;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 3, 0, 3, 3, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Renewable ACPPower Full Dispatch" begin
    model = DeviceModel(RenewableDispatch, RenewableFullDispatch)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_re;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        if p
            moi_tests(op_problem, p, 144, 0, 144, 72, 0, false)
            psi_checkobjfun_test(op_problem, GAEVF)
        else
            moi_tests(op_problem, p, 144, 0, 144, 72, 0, false)

            psi_checkobjfun_test(op_problem, GAEVF)
        end
    end
    # No Forecast Test
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_re;
        use_forecast_data = false,
        use_parameters = false,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 6, 0, 6, 6, 0, false)

    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Renewable DCPLossLess Constantpower_factor" begin
    model = DeviceModel(RenewableDispatch, RenewableConstantPowerFactor)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")

    #5 Bus testing case
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_re)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 72, 0, 72, 0, 0, false)

    psi_checkobjfun_test(op_problem, GAEVF)

    # Using Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_re;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 72, 0, 72, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_re;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 3, 0, 3, 3, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Renewable ACPPower Constantpower_factor" begin
    model = DeviceModel(RenewableDispatch, RenewableConstantPowerFactor)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_re;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        if p
            moi_tests(op_problem, p, 144, 0, 72, 0, 72, false)
            psi_checkobjfun_test(op_problem, GAEVF)
        else
            moi_tests(op_problem, p, 144, 0, 72, 0, 72, false)

            psi_checkobjfun_test(op_problem, GAEVF)
        end
    end
    # No Forecast Test
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_re;
        use_forecast_data = false,
        use_parameters = false,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 6, 0, 3, 3, 3, false)

    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Renewable DCPLossLess FixedOutput" begin
    model = DeviceModel(RenewableDispatch, FixedOutput)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5_re;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        if p
            moi_tests(op_problem, p, 0, 0, 0, 0, 0, false)
            psi_checkobjfun_test(op_problem, GAEVF)
        else
            moi_tests(op_problem, p, 0, 0, 0, 0, 0, false)
            psi_checkobjfun_test(op_problem, GAEVF)
        end
    end
end

@testset "Renewable ACPPowerModel FixedOutput" begin
    model = DeviceModel(RenewableDispatch, FixedOutput)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_re;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        if p
            moi_tests(op_problem, p, 0, 0, 0, 0, 0, false)
            psi_checkobjfun_test(op_problem, GAEVF)
        else
            moi_tests(op_problem, p, 0, 0, 0, 0, 0, false)
            psi_checkobjfun_test(op_problem, GAEVF)
        end
    end
end
