@testset "Storage data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type GenericBattery, consider changing the device models"
    model = DeviceModel(GenericBattery, BookKeeping)
    c_sys5 = build_system("c_sys5")
    c_sys14 = build_system("c_sys14")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Storage, model)
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Storage, model)
end

@testset "Storage Basic Storage With DC - PF" begin
    model = DeviceModel(GenericBattery, BookKeeping)
    c_sys5_bat = build_system("c_sys5_bat")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 72, 0, 72, 72, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Storage Basic Storage With AC - PF" begin
    model = DeviceModel(GenericBattery, BookKeeping)
    c_sys5_bat = build_system("c_sys5_bat")
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 96, 0, 96, 96, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Storage with Reservation DC - PF" begin
    model = DeviceModel(GenericBattery, BookKeepingwReservation)
    c_sys5_bat = build_system("c_sys5_bat")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 96, 0, 72, 72, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Storage with Reservation With AC - PF" begin
    model = DeviceModel(GenericBattery, BookKeepingwReservation)
    c_sys5_bat = build_system("c_sys5_bat")
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 120, 0, 96, 96, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodStaticEnergyTarget with DC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodStaticEnergyTarget)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 72, 0, 72, 73, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodStaticEnergyTarget With AC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodStaticEnergyTarget)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 96, 0, 96, 97, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodEnergyTarget with DC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodEnergyTarget)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 72, 0, 72, 73, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodEnergyTarget With AC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodEnergyTarget)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 96, 0, 96, 97, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodStaticEnergySoftTarget with DC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodStaticEnergySoftTarget)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 96, 0, 72, 73, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodStaticEnergySoftTarget With AC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodStaticEnergySoftTarget)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 120, 0, 96, 97, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodEnergySoftTarget with DC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodEnergySoftTarget)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 96, 0, 72, 73, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodEnergySoftTarget With AC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodEnergySoftTarget)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 120, 0, 96, 97, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodEnergyValue with DC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodEnergyValue)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 72, 0, 72, 72, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "BatteryEMS with EndOfPeriodEnergyValue With AC - PF" begin
    model = DeviceModel(BatteryEMS, EndOfPeriodEnergyValue)
    c_sys5_bat = build_system("c_sys5_bat_ems")
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 96, 0, 96, 96, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end
