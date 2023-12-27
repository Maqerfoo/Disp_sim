using Mimi 
using MimiGIVE
using CSV, DataFrames

SSPs = ["SSP119", "SSP126", "SSP245", "SSP370", "SSP585"]
# Create the a model using the SSPs socioeconomics and FAIR's SSP245 emissions scenario
mapping_ciamcountry = CSV.read("data/xsc_ciam_countries.csv", DataFrame)

# Define a function to forward-fill the missing values
function forward_fill!(group)
    # Get the index of the first non-missing 'TotalOptimalCost' value
    first_valid_index = findfirst(isequal(2020), group.time)
    if isnothing(first_valid_index)
        return group  # If there is no such year, return the group unchanged
    end
    
    # Forward-fill the 'TotalOptimalCost' column
    valid_value = group[first_valid_index, :TotalOptimalCost]
    for i in first_valid_index+1:size(group, 1)
        if group[i, :time] % 10 != 0  # Check if the year is not divisible by 10
            group[i, :TotalOptimalCost] = valid_value
        else
            valid_value = group[i, :TotalOptimalCost]  # Update the valid_value if the year is divisible by 10
        end
    end
    return group
end


for SSP in SSPs
    m = MimiGIVE.get_model(socioeconomics_source = :SSP,
                        SSP_scenario = SSP)

    # Run the model
    run(m)
    #GDP

    # Country environment parameters
    Socioeconomic_gdp = :Socioeconomic => :gdp
    Socioeconomic_pop = :Socioeconomic => :population
    Cromar_dr = :CromarMortality => :excess_death_rate
    Cromar_vsl = :CromarMortality => :vsl
    Energy = :energy_damages => :energy_costs_share 
    country_env = getdataframe(m, Socioeconomic_gdp, Socioeconomic_pop, Cromar_dr, Cromar_vsl)
    country_env[!,:energy_costs_share] = getdataframe(m, Energy)[!,:energy_costs_share]
    country_env = dropmissing(country_env)

    # Get the default CIAM model
    m_ciam, segment_fingerprints = MimiGIVE.get_ciam(m)

    # Update the CIAM model with MimiGIVE specific parameters
    MimiGIVE.update_ciam!(m_ciam, m, segment_fingerprints)

    # Run the CIAM model
    run(m_ciam)
    
    dfciam = getdataframe(m_ciam, :slrcost, :OptimalCost)
    dfciam = leftjoin(dfciam,  select(mapping_ciamcountry, :seg, :rgn), on = :segments => :seg)

    # Group and sum all segments to countries
    gdf = groupby(dfciam, [:rgn, :time])
    summed_df = combine(gdf, :OptimalCost => sum => :TotalOptimalCost)
    summed_df[!,:time] = summed_df[!,:time] .*10 .+ 2010
    rename!(summed_df, :rgn => :country)

    # Join the dataframes
    country_env =  leftjoin(country_env, summed_df, on=[:country, :time])
    # Fill missing entries
    sort!(country_env, [:country, :time])
    country_env = combine(groupby(country_env, :country), forward_fill!)
    country_env .= coalesce.(country_env, 0)

    # Environment Parameters
    temperature = :temperature => :T
    Socioeconomic_co2 = :Socioeconomic => :co2_emissions
    global_env = getdataframe(m, Socioeconomic_co2, temperature)

    path = "data/env_params/$(SSP)"
    mkpath(path)
    CSV.write(path*"/country_params.csv", country_env)
    CSV.write(path*"/global_params.csv", global_env)
end




