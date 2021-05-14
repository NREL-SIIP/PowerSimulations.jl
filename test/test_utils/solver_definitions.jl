ipopt_optimizer =
    JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-6, "print_level" => 0)
fast_ipopt_optimizer = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer,
    "print_level" => 0,
    "max_cpu_time" => 5.0,
)
# use default print_level = 5 # set to 0 to disable
GLPK_optimizer = JuMP.optimizer_with_attributes(GLPK.Optimizer)
Cbc_optimizer = JuMP.optimizer_with_attributes(Cbc.Optimizer)
OSQP_optimizer =
    JuMP.optimizer_with_attributes(OSQP.Optimizer, "verbose" => false, "max_iter" => 50000)
fast_lp_optimizer = JuMP.optimizer_with_attributes(Cbc.Optimizer, "seconds" => 3.0)
scs_solver = JuMP.optimizer_with_attributes(
    SCS.Optimizer,
    "max_iters" => 100000,
    "eps" => 1e-4,
    "verbose" => 0,
)
