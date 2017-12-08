module Util
export get_variable, timesliced_variable, build_constraint

using AxisArrays; using NCDatasets; using JuMP; using CalliopeBackend;

function get_variable(dataset, var::String)
    """
    returns an AxisArray of the given variable, indexed over its relevant
    dimensions

    Parameters
    ----------
    var : string
        From the variables available in the loaded Dataset
    Returns
    -------
    AxisArray
    """
    var_dimnames = NCDatasets.dimnames(dataset[var])
    var_out = AxisArray(dataset[var][:],
        Tuple([AxisArrays.Axis{Symbol(i)}(dataset[i][:])
            for i in var_dimnames]))

    return var_out
end


function get_param(model_dict, var, dimensions)
    """
    returns an AxisArray of the given variable, indexed over all dimensions
    except timesteps, in order to remove timesteps from a possible timeseries
    variable (which may also be a static variable, we just don't know!)

    Parameters
    ----------
    var : string
        From the variables available in the loaded Dataset
    timestep : DateTime
        one value from from sets["timesteps"]
    Returns
    -------
    AxisArray without the time axis
    """

    if var not in dataset
        return model_dict["defaults"][var]
    else
        var_dimnames = NCDatasets.dimnames(dataset[var])
        if "timesteps" in var_dimnames
            dimensions["timesteps"] = DateTime(dimensions["timesteps"])
            loc = CartesianIndex(Tuple(find(sets[i] .== dimensions[i]) for i in var_dimnames))
            return dataset[var][loc]
        else
            delete!(dimensions, "timesteps")
            loc = CartesianIndex(Tuple(find(sets[i] .== dimensions[i]) for i in var_dimnames))
            return dataset[var][loc]
        end
end


function build_constraint(backend_model, constraint_sets, constraint_name, sets, parameters)
    """
    create a constraint object, indexed over the given sets.

    Parameters
    ----------
    constraint_sets : array of strings
        names of the sets over which the constraint will be indexed
    constraint_name : string
        Name of constraint obect to build. Will also be used to refer to the
        correct constraint rule, which will be constraint_name + "_constraint_rule"

    Return
    ------
    No direct return, the constraint Dictionary constraint_dict will contain an
    additional entry with the key `constraint_name`
    """

    # create a tuple of integer lists
    indexed_sets = [1:length(sets[i]) for i in constraint_sets]

    # Use the Julia @constraintref macro to build an empty constraint object
    temporary_constraint = Array{ConstraintRef}((length(i) for i in indexed_sets)...)
    # get the relevant function from this module
    temporary_constraint_rule = getfield(
        CalliopeBackend.load_constraints,
        Symbol(string(constraint_name, "_constraint_rule"))
    )

    # Loop through to populate the previously built empty constraint object
    for i in CartesianRange(size(temporary_constraint))
        idx = [item for item in i.I]
        print((sets[constraint_sets[constr]][idx[constr]]
        for constr in 1:length(constraint_sets))[0])
        temporary_constraint[i] = temporary_constraint_rule(backend_model,
            (sets[constraint_sets[constr]][idx[constr]]
             for constr in 1:length(constraint_sets)),
            sets, parameters
        )

    end
    return temporary_constraint
end

end