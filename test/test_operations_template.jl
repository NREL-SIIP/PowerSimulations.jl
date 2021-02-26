# This file is WIP while the interface for templates is finalized
@testset "Manual Operations Template" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template, Line, StaticBranchUnbounded)
    @test !isempty(template.devices)
    @test !isempty(template.branches)
    @test isempty(template.services)
end

@testset "Operations Template Overwrite" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    @test_logs (:info, "Overwriting ThermalStandard existing model") set_device_model!(
        template,
        DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
    )
    @test template.devices[:ThermalStandard].formulation == ThermalBasicUnitCommitment
end

@testset "Provided Templates Tests" begin
    uc_template = template_unit_commitment()
    @test !isempty(uc_template.devices)
    @test uc_template.devices[:ThermalStandard].formulation == ThermalBasicUnitCommitment
    uc_template = template_unit_commitment(network = DCPPowerModel)
    @test get_transmission_model(uc_template) == DCPPowerModel
    @test !isempty(uc_template.branches)
    @test !isempty(uc_template.services)

    ed_template = template_economic_dispatch()
    @test !isempty(ed_template.devices)
    @test ed_template.devices[:ThermalStandard].formulation == ThermalDispatch
    ed_template = template_economic_dispatch(network = ACPPowerModel)
    @test get_transmission_model(ed_template) == ACPPowerModel
    @test !isempty(ed_template.branches)
    @test !isempty(ed_template.services)
end
