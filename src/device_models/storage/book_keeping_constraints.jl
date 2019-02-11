
function powerconstraints(m::JuMP.AbstractModel, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.Storage

    pstin = m[:pstin]
    pstout = m[:pstout]
    name_index = m[:pstin].axes[1]
    time_index = m[:pstin].axes[2]

    (length(pstin.axes[2]) != time_periods) ? @error("Length of time dimension inconsistent") : true
    (length(pstout.axes[2]) != time_periods) ? @error("Length of time dimension inconsistent") : true

    pmax_in = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(length.(JuMP.axes(pstin))), name_index, time_index)
    pmax_out= JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(length.(JuMP.axes(pstout))), name_index, time_index)
    pmin_in = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(length.(JuMP.axes(pstin))), name_index, time_index)
    pmin_out= JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(length.(JuMP.axes(pstout))), name_index, time_index)

    (pstin.axes[1] !== pstout.axes[1]) ? @warn("Input/Output variables indexes are inconsistent") : true

    for t in pstin.axes[2], (ix, name) in enumerate(pstin.axes[1])
        if name == devices[ix].name
            pmin_in[name, t] = @constraint(m, pstin[name, t] <= devices[ix].inputactivepowerlimits.min)
            pmin_out[name, t] = @constraint(m, pstout[name, t] <= devices[ix].outputactivepowerlimits.min)
            pmax_in[name, t] = @constraint(m, pstin[name, t] <= devices[ix].inputactivepowerlimits.max)
            pmax_out[name, t] = @constraint(m, pstout[name, t] <= devices[ix].outputactivepowerlimits.max)
        else
            @error "Bus name in Array and variable do not match"
        end
    end

    JuMP.register_object(m, :pmax_in, pmax_in)
    JuMP.register_object(m, :pmax_out, pmax_out)
    JuMP.register_object(m, :pmin_in, pmin_in)
    JuMP.register_object(m, :pmin_out, pmin_out)

    return m
end

function energybookkeeping(m::JuMP.AbstractModel, devices::Array{T,1}, time_periods::Int64; ini_cond = 0.0) where T <: PowerSystems.GenericBattery

    pstin = m[:pstin]
    pstout = m[:pstout]
    ebt = m[:ebt]
    name_index = m[:ebt].axes[1]
    time_index = m[:ebt].axes[2]

    (length(time_index) != time_periods) ? @error("Length of time dimension inconsistent in E_bt") : true
    (pstin.axes[1] !== time_index) ? @warn("Input/Output and Battery Energy variables indexes are inconsistent") : true

    bookkeep_bt = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(length.(JuMP.axes(ebt))), name_index, time_index)

    # TODO: Add Initial SOC for storage for sequential simulation
    for t1 = time_index[1], (ix,name) in enumerate(name_index)
        if name == devices[ix].name
            bookkeep_bt[name,t1] = @constraint(m,ebt[name,t1] == devices[ix].energy -  pstout[name,t1]/devices[ix].efficiency.out + pstin[name,t1]*devices[ix].efficiency.in)
        else
            @error "Bus name in Array and variable do not match"
        end
    end

    for t in time_index[2:end], (ix,name) in enumerate(name_index)
        if name == devices[ix].name
            bookkeep_bt[name,t] = @constraint(m,ebt[name,t] == ebt[name,t-1] -  pstout[name,t]/devices[ix].efficiency.out + pstin[name,t]*devices[ix].efficiency.in)
        else
            @error "Bus name in Array and variable do not match" 
        end
    end

    JuMP.register_object(m, :book_keep, bookkeep_bt)

    return m

end

function energyconstraints(m::JuMP.AbstractModel, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.GenericBattery

    ebt = m[:ebt]
    name_index = m[:ebt].axes[1]
    time_index = m[:ebt].axes[2]

    (length(ebt.axes[2]) != time_periods) ? @error("Length of time dimension inconsistent") : true

    energylimit_bt = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(length.(JuMP.axes(ebt))), name_index, time_index)

    for t in time_index, (ix,name) in enumerate(name_index)
        if name == devices[ix].name
            energylimit_bt[name,t] = @constraint(m,ebt[name,t] <= devices[ix].capacity.max)
        else
            @error "Bus name in Array and variable do not match"
        end
    end

    JuMP.register_object(m, :energystoragelimit, energylimit_bt)

    return m
end