@test try 
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                                  Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                             "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                                  Dict());
    PSI.constructdevice!(ps_model, PSY.RenewableGen, PSI.RenewableFullDispatch, PM.DCPlosslessForm, sys5b);
    true finally end
    
    @test_skip try 
    ps_model = PSI.CanonicalModel(Model(),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                                  Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                             "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                                  Dict());
    PSI.constructdevice!(ps_model, PSY.RenewableGen, PSI.RenewableFullDispatch, PM.StandardACPForm, sys5b); 
    true finally end
    
@test try 
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                                "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                                    Dict());
    PSI.constructdevice!(ps_model, PSY.RenewableGen, PSI.RenewableConstantPowerFactor, PM.DCPlosslessForm, sys5b);
    true finally end
    
    @test try 
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                                "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                                    Dict());
    PSI.constructdevice!(ps_model, PSY.RenewableGen, PSI.RenewableConstantPowerFactor, PM.StandardACPForm, sys5b); 
    true finally end

@test try 
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                                "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                                    Dict());
    PSI.constructdevice!(ps_model, PSY.RenewableGen, PSI.RenewableFixed, PM.DCPlosslessForm, sys5b);
    true finally end
    
    @test try 
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                                "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                                    Dict());
    PSI.constructdevice!(ps_model, PSY.RenewableGen, PSI.RenewableFixed, PM.StandardACPForm, sys5b); 
    true finally end