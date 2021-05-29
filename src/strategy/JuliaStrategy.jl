function _build_ic_array_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::String

    # build the text fragments -
    ic_buffer=Array{String,1}()
    default_dictionary = ir_dictionary["default_dictionary"]

    # go ...
    +(ic_buffer,"initial_condition_array = [";suffix="\n")
    
    # iterate through species, build ic records -
    df_species = ir_dictionary["model_species_table"]
    (number_of_species,_) = size(df_species)
    for species_index = 1:number_of_species
        
        species_symbol = df_species[species_index,:symbol]
        species_type = df_species[species_index, :type]

        # what is the value?
        value = 0.0
        if (species_type == :DNA)
            value = default_dictionary["problem_dictionary"]["DNA_initial_condition"]
        elseif (species_type == :RNA)
            value = default_dictionary["problem_dictionary"]["RNA_initial_condition"]
        elseif (species_type == :PROTEIN)
            value = default_dictionary["problem_dictionary"]["PROTEIN_initial_condition"]
        end

        +(ic_buffer,"$(value)\t;\t#\t$(species_index)\t$(species_symbol)\tunits: nM\n"; prefix="\t\t\t")
    end

    +(ic_buffer,"]"; prefix="\t\t")
    
    # flatten and return -
    flat_ic_buffer = ""
    [flat_ic_buffer *= line for line in ic_buffer]
    return flat_ic_buffer
end

function _build_system_species_concentration_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::String

    # initialize -
    system_buffer = Array{String,1}()

    # get the system block -
    system_dictionary_array = ir_dictionary["system_dictionary"]["list_of_system_species"]

    # here we go - open
    +(system_buffer, "system_concentration_array = ["; suffix="\n")
    for (index,system_species_dictionary) in enumerate(system_dictionary_array)
        
        # ok, block will be a dictionary with a value, and units keys - 
        value = system_species_dictionary["concentration"]
        units = system_species_dictionary["units"]
        symbol = system_species_dictionary["symbol"]

        # build the line -
        +(system_buffer, "$(value)\t;\t#\t$(symbol)\tunits: $(units)"; suffix="\n", prefix="\t\t\t")

    end

    # close -
    +(system_buffer,"]"; prefix="\t\t")


    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in system_buffer]
    return flat_buffer
end

function _build_sequence_length_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::String

    # initialize - 

end

function _build_model_species_alias_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::String

    # initialize -
    buffer = Array{String,1}()

    # get the list of model species -
    df_species = ir_dictionary["model_species_table"]
    (number_of_species,_) = size(df_species)
    for species_index = 1:number_of_species
        
        # grab the symbol -
        species_symbol = df_species[species_index,:symbol]
        
        # this weird setup is because to the Mustache layout -
        if (species_index == 1)
            
            # build the record -
            +(buffer, "$(species_symbol) = x[$(species_index)]"; suffix="\n")
        elseif (species_index > 1 && species_index < number_of_species)
            
            # build the record -
            +(buffer, "$(species_symbol) = x[$(species_index)]"; prefix="\t", suffix="\n")
        else
            
            # build the record -
            +(buffer, "$(species_symbol) = x[$(species_index)]"; prefix="\t")
        end
    end

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

function _build_system_type_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::String

    # initialize -
    buffer = Array{String,1}()

    # get the system block -
    system_type = ir_dictionary["system_dictionary"]["system_type"]

    # close -
    +(buffer,":$(system_type)"; prefix="\t")

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

function _build_system_species_alias_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::String

    # initialize -
    buffer = Array{String,1}()

    # get the system_dictionary -
    system_dictionary = ir_dictionary["system_dictionary"]    
    list_of_system_species = system_dictionary["list_of_system_species"]
    for (index,species_dictionary) in enumerate(list_of_system_species)
        
        # get data -
        symbol = species_dictionary["symbol"]

        # formulate system species line -
        line = "$(symbol) = system_array[$(index)]"

        prefix="\t"
        if (index==1)
            prefix=""
        end

        # add to buffer -
        +(buffer, line; prefix=prefix, suffix="\n")
    end

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

function _build_u_variable_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::String

    # initialize -
    buffer = Array{String,1}()

    # internal helper functions: handle activators -
    function _process_list_of_activators(target::String, output::String, polymerase_symbol::String,
        list_of_actor_dictionaries)::String

        # initialize -
        local_buffer = Array{String,1}()

        # generate list of W's -
        +(local_buffer,"W = ["; suffix="\n")
        +(local_buffer,"W_$(target)\t;"; prefix="\t\t\t", suffix="\n")
        for (index, actor_dictionary) in enumerate(list_of_actor_dictionaries)
            
            # get actor symbol -
            actor_symbol = actor_dictionary["symbol"]

            # build the entry -
            +(local_buffer, "W_$(target)_$(output)\t;"; prefix="\t\t\t", suffix="\n")
        end
        +(local_buffer,"]"; suffix="\n",prefix="\t")


        +(local_buffer, "$(target)_activator_array = Array{Float64,1}()"; suffix="\n", prefix="\t")
        +(local_buffer, "push!($(target)_activator_array, 1.0)"; suffix="\n", prefix="\t")
        for (_, actor_dictionary) in enumerate(list_of_actor_dictionaries)

            # get activator symbol -
            actor_symbol = actor_dictionary["symbol"]
            actor_type = actor_dictionary["type"]

            if (actor_type == "positive_sigma_factor")
                +(local_buffer, "$(actor_symbol)_$(polymerase_symbol) = $(polymerase_symbol)*f($(actor_symbol),K_$(target)_$(actor_symbol),n_$(target)_$(actor_symbol))"; suffix="\n", prefix="\t")
                +(local_buffer, "push!($(target)_activator_array, $(actor_symbol)_$(polymerase_symbol))"; suffix="\n", prefix="\t")
            end
        end

        # build the A term -
        +(local_buffer, "A = sum(W.*$(target)_activator_array)"; suffix="\n", prefix="\t")

        # flatten and return -
        flat_buffer = ""
        [flat_buffer *= line for line in local_buffer]
        return flat_buffer
    end

    function _process_list_of_repressors(target::String, output::String, polymerase_symbol::String,
        list_of_actor_dictionaries)::String

        # initialize -
        local_buffer = Array{String,1}()

        # do we have any repressors -
        if (isempty(list_of_actor_dictionaries) == true)
            +(local_buffer,"R = 0.0"; suffix="\n")
        else
            # generate list of W's -
            +(local_buffer,"W = ["; suffix="\n")
            +(local_buffer,"W_$(target)\t;"; prefix="\t\t\t", suffix="\n")
            for (index, actor_dictionary) in enumerate(list_of_actor_dictionaries)
            
                # get actor symbol -
                actor_symbol = actor_dictionary["symbol"]

                # build the entry -
                +(local_buffer, "W_$(target)_$(output)\t;"; prefix="\t\t\t", suffix="\n")
            end
            +(local_buffer,"]"; suffix="\n",prefix="\t")

            # repressor -
            +(local_buffer, "$(target)_repressor_array = Array{Float64,1}()"; suffix="\n", prefix="\t")
            for (_, actor_dictionary) in enumerate(list_of_actor_dictionaries)

                # get activator symbol -
                actor_symbol = actor_dictionary["symbol"]
                actor_type = actor_dictionary["type"]

                +(local_buffer, "push!($(target)_repressor_array, f($(actor_symbol),K_$(target)_$(actor_symbol),n_$(target)_$(actor_symbol))"; suffix="\n", prefix="\t")
            end
    
            # build the A term -
            +(local_buffer, "R = sum(W.*$(target)_repressor_array)"; suffix="\n", prefix="\t")
        end

        # flatten and return -
        flat_buffer = ""
        [flat_buffer *= line for line in local_buffer]
        return flat_buffer
    end

    # get the list of transcription models -
    list_of_transcription_models = ir_dictionary["list_of_transcription_models"]
    for (index, model_dictionary) in enumerate(list_of_transcription_models)
        
        # get data from the model dictionary -
        title = model_dictionary["title"]
        input = model_dictionary["input"]
        output = model_dictionary["output"]
        polymerase_symbol = model_dictionary["polymerase_symbol"]

        # process: list of activators -
        list_of_activators = model_dictionary["list_of_activators"]
        activator_clause = _process_list_of_activators(input, output, polymerase_symbol,list_of_activators)
        +(buffer, "# $(input) activation - "; suffix="\n", prefix="\t")
        +(buffer, "$(activator_clause)"; suffix="\n")

        # process: list of repressors -
        list_of_repressors = model_dictionary["list_of_repressors"]
        repressor_clause = _process_list_of_repressors(input, output, polymerase_symbol, list_of_repressors)
        +(buffer, "# $(input) repression - "; suffix="\n", prefix="\t")
        +(buffer, "$(repressor_clause)")
        +(buffer, "push!(u_array, u(A,R))"; suffix="\n", prefix="\t")
        +(buffer,"\n")

        # compute -
        # +(buffer, "push!(u_array, u(A,R))"; suffix="\n", prefix="\t")

        # # comment string -
        # +(buffer, "# $(title): $(input) -[$(polymerase_symbol)]- $(output)"; suffix="\n", prefix="\t")
        # +(buffer, "$(title)_activator_set = Array{Float64,1}()"; suffix="\n", prefix="\t")
        # +(buffer, "push!($(title)_activator_set, 1.0)"; suffix="\n", prefix="\t")

        # local_actor_buffer = Array{String,1}()
        # for (index, activator_dictionary) in enumerate(list_of_activators)
            
        #     # get activator symbol -
        #     activator_symbol = activator_dictionary["symbol"]
        #     activator_type = activator_dictionary["type"]

        #     # cache -
        #     push!(local_actor_buffer, activator_symbol)

        #     # check: if sigma factor, then actor is bound to RNAP
        #     if (activator_type == "positive_sigma_factor")
        #         +(buffer, "$(activator_symbol)_$(polymerase_symbol) = $(polymerase_symbol)*f($(activator_symbol),K_$(input)_$(activator_symbol),n_$(input)_$(activator_symbol))"; suffix="\n", prefix="\t")
        #         +(buffer, "push!($(title)_activator_set, $(activator_symbol)_$(polymerase_symbol))"; suffix="\n", prefix="\t")
        #     else
        #         # nothibng for now ...
        #     end
        # end
        # +(buffer, "A = sum(W.*$(title)_activator_set)"; suffix="\n", prefix="\t")
    
        # # add a space -
        # +(buffer, "\n")

        # # for this promoter - process the list of repressors 
        
        # for (index, repressor_dictionary) in enumerate(list_of_repressors)
        
        #     # get repressor symbol -
        #     repressor_symbol = repressor_dictionary["symbol"]
        #     repressor_type = repressor_dictionary["type"]

        #     # check the type -
        #     if (repressor_type == "negative_protein_repressor")
                
        #         # if we get here, then we have a counter agent -
        #         counter_agent = repressor_dictionary["counter_agent"]
                
        #         # build the activate component -
        #         +(buffer, "$(repressor_symbol)_active = $(repressor_symbol)*(1.0 - f($(counter_agent), K_$(input)_$(repressor_symbol), n_$(input)_$(repressor_symbol)))"; suffix="\n", prefix="\t")
        #         +(buffer, "push!($(title)_repressor_set, $(repressor_symbol)_active)"; suffix="\n", prefix="\t")
        #     else
        #         # nothing for now -
        #     end
        # end

        # if (isempty(list_of_repressors) == false)
        #     +(buffer, "R = sum(W.*$(title)_repressor_set)"; suffix="\n", prefix="\t")
        # end

        # +(buffer, "push!(u_array, u(A,R))"; suffix="\n", prefix="\t")
    end

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

function _build_transcription_kinetic_limit_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::String

    # initialize -
    buffer = Array{String,1}()

    # get the species table -
    model_species_table = ir_dictionary["model_species_table"]

    # get the list of transcription models -
    list_of_transcription_models = ir_dictionary["list_of_transcription_models"]
    for (index,transcription_model_dictionary) in enumerate(list_of_transcription_models)
        
        # get the input et al -
        input_string = transcription_model_dictionary["input"]
        polymerase_symbol = transcription_model_dictionary["polymerase_symbol"]

        # compute the length -
        idx_symbol = findfirst(x->x==input_string,model_species_table[!,:symbol])
        sequence = model_species_table[idx_symbol,:sequence]
        L = FASTX.FASTA.seqlen(sequence)

        # tmp_line = 
        push_line = "push!(kinetic_limit_array, r(k_cat_characteristic,LX,$(L),$(polymerase_symbol),𝛕_$(input_string),K_$(input_string),$(input_string)))"

        if (index == 1)
            +(buffer,push_line; suffix="\n")
        elseif (index==length(list_of_transcription_models))
            +(buffer,push_line; prefix="\t")
        else
            +(buffer, push_line, prefix="\t",suffix="\n")
        end
    end

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

function _build_translation_kinetic_limit_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::String

    # initialize -
    buffer = Array{String,1}()

    # get the species table -
    model_species_table = ir_dictionary["model_species_table"]

    # get the list of transcription models -
    list_of_models = ir_dictionary["list_of_translation_models"]
    for (index, model_dictionary) in enumerate(list_of_models)
        
        # get the input et al -
        output_string = model_dictionary["output"]
        polymerase_symbol = model_dictionary["ribosome_symbol"]

        # compute the length -
        idx_symbol = findfirst(x->x==output_string,model_species_table[!,:symbol])
        sequence = model_species_table[idx_symbol,:sequence]
        L = FASTX.FASTA.seqlen(sequence)

        # tmp_line = 
        push_line = "push!(kinetic_limit_array, r(k_cat_characteristic,LL,$(L),$(polymerase_symbol),𝛕_$(output_string),K_$(output_string),$(output_string)))"

        if (index == 1)
            +(buffer,push_line; suffix="\n")
        elseif (index==length(list_of_models))
            +(buffer,push_line; prefix="\t")
        else
            +(buffer, push_line, prefix="\t",suffix="\n")
        end
    end

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

function _build_model_parameter_array_snippet(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::NamedTuple

     # initialize -
    buffer = Array{String,1}()
    list_of_translation_models = ir_dictionary["list_of_translation_models"]
    list_of_transcription_models = ir_dictionary["list_of_transcription_models"]
    model_species_table = ir_dictionary["model_species_table"]
    parameter_symbol_array = Array{String,1}()

    # start -
    +(buffer,"model_parameter_array = ["; suffix="\n\n")

    # process the list of transcription models -
    pcounter = 1
    for (_, model_dictionary) in enumerate(list_of_transcription_models)
        
        # go through and formulate the W's -
        input_string = model_dictionary["input"]

        # grab the symbol -
        push!(parameter_symbol_array, "W_$(input_string)")

        # put a comment line -
        +(buffer,"# control parameters: $(input_string)\n";prefix="\t\t\t")
        +(buffer,"0.001\t;\t#\t$(pcounter)\tW_$(input_string)\n";prefix="\t\t\t")
        
        # update -
        pcounter = pcounter + 1

        # process the list of activators -
        list_of_activators = model_dictionary["list_of_activators"]
        for (activator_index, activator_dictionary) in enumerate(list_of_activators)
        
            activator_symbol = activator_dictionary["symbol"]

            # grab the parameter symbol -
            push!(parameter_symbol_array, "W_$(input_string)_$(activator_symbol)")

            +(buffer,"1.0\t\t;\t#\t$(pcounter)\tW_$(input_string)_$(activator_symbol)\n"; prefix="\t\t\t")
            pcounter = pcounter + 1
        end

        # process the list of repressors -
        list_of_repressors = model_dictionary["list_of_repressors"]
        for (repressor_index, repressor_dictionary) in enumerate(list_of_repressors)
            
            repressor_symbol = repressor_dictionary["symbol"]

            # grab the parameter symbol -
            push!(parameter_symbol_array, "W_$(input_string)_$(repressor_symbol)")

            +(buffer,"1.0\t\t;\t#\t$(pcounter)\tW_$(input_string)_$(repressor_symbol)\n"; prefix="\t\t\t")
            pcounter = pcounter + 1
        end

        # binding constant, and binding order for activators -
        for (activator_index, activator_dictionary) in enumerate(list_of_activators)
        
            activator_symbol = activator_dictionary["symbol"]
            
            # grab the parameter symbol -
            push!(parameter_symbol_array, "K_$(input_string)_$(activator_symbol)")
            push!(parameter_symbol_array, "n_$(input_string)_$(activator_symbol)")
            
            +(buffer,"1.0\t\t;\t#\t$(pcounter)\tK_$(input_string)_$(activator_symbol)\n"; prefix="\t\t\t")
            pcounter = pcounter + 1

            +(buffer,"1.0\t\t;\t#\t$(pcounter)\tn_$(input_string)_$(activator_symbol)\n"; prefix="\t\t\t")
            pcounter = pcounter + 1            
        end

        # binding constant, and binding order for repressors -
        for (repressor_index, repressor_dictionary) in enumerate(list_of_repressors)
        
            repressor_symbol = repressor_dictionary["symbol"]
            +(buffer,"1.0\t\t;\t#\t$(pcounter)\tK_$(input_string)_$(repressor_symbol)\n"; prefix="\t\t\t")
            pcounter = pcounter + 1

            +(buffer,"1.0\t\t;\t#\t$(pcounter)\tn_$(input_string)_$(repressor_symbol)\n"; prefix="\t\t\t")
            pcounter = pcounter + 1   

            # grab the parameter symbol -
            push!(parameter_symbol_array, "K_$(input_string)_$(repressor_symbol)")
            push!(parameter_symbol_array, "n_$(input_string)_$(repressor_symbol)")
        end

        # add extra row -
        +(buffer,"\n")
    end

    for (tx_index, model_dictionary) in enumerate(list_of_transcription_models)
        
        # what is the species -
        input_string = model_dictionary["input"]

        if (tx_index>1)
            +(buffer,"\n")
        end

        # K -
        +(buffer,"# transcription kinetic limit parameters: $(input_string)\n";prefix="\t\t\t")
        +(buffer, "1.0\t\t;\t#\t$(pcounter)\tK_$(input_string)\n"; prefix="\t\t\t")
        pcounter = pcounter + 1

        +(buffer, "1.0\t\t;\t#\t$(pcounter)\t𝛕_$(input_string)\n"; prefix="\t\t\t")
        pcounter = pcounter + 1

        # grab the parameter symbol -
        push!(parameter_symbol_array, "K_$(input_string)")
        push!(parameter_symbol_array, "𝛕_$(input_string)")
    end

    +(buffer,"\n")

    # process the list of translation models -
    for (tl_index, model_dictionary) in enumerate(list_of_translation_models)
        
        # go through and formulate the W's -
        output_string = model_dictionary["output"]

        if (tl_index>1)
            +(buffer,"\n")
        end

        # K -
        +(buffer,"# translation kinetic limit parameters: $(output_string)\n";prefix="\t\t\t")
        +(buffer, "1.0\t\t;\t#\t$(pcounter)\tK_$(output_string)\n"; prefix="\t\t\t")
        pcounter = pcounter + 1

        +(buffer, "1.0\t\t;\t#\t$(pcounter)\t𝛕_$(output_string)\n"; prefix="\t\t\t")
        pcounter = pcounter + 1

        # grab the parameter symbol -
        push!(parameter_symbol_array, "K_$(output_string)")
        push!(parameter_symbol_array, "𝛕_$(output_string)")
    end

    +(buffer,"\n")
    +(buffer,"# species degradation constants - \n"; prefix="\t\t\t")

    # ok, lastly we need degrdation constants for system species -
    (number_of_species, _) = size(model_species_table)
    for species_index = 1:number_of_species
        species_type = model_species_table[species_index, :type]
        species_symbol = model_species_table[species_index, :symbol]
        if (species_type != :DNA)
            +(buffer, "1.0\t\t;\t#\t$(pcounter)\t𝛳_$(species_symbol)\n"; prefix="\t\t\t")
            pcounter = pcounter + 1

            # grab the parameter symbol -
            push!(parameter_symbol_array, "𝛳_$(species_symbol)")
        end
    end

    # end -
    +(buffer, "]"; suffix="\n", prefix="\t\t")

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    
    results_tuple = (flat_buffer=flat_buffer, parameter_symbol_array=parameter_symbol_array)
    return results_tuple
end

function _build_model_parameter_symbol_index_map(parameter_symbol_array::Array{String,1})::String

    # initialize -
    buffer = Array{String,1}()

    # build the map -
    +(buffer,"model_parameter_symbol_index_map = Dict{Symbol,Int}()";suffix="\n")
    for (index, parameter_symbol) in enumerate(parameter_symbol_array)
        +(buffer,"model_parameter_symbol_index_map[:$(parameter_symbol)] = $(index)";prefix="\t\t",suffix="\n")
    end

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

function _build_inverse_model_parameter_symbol_index_map(parameter_symbol_array::Array{String,1})::String

    # initialize -
    buffer = Array{String,1}()

    # build the map -
    +(buffer,"inverse_model_parameter_symbol_index_map = Dict{Int, Symbol}()";suffix="\n")
    for (index, parameter_symbol) in enumerate(parameter_symbol_array)
        +(buffer,"inverse_model_parameter_symbol_index_map[$(index)] = :$(parameter_symbol)";prefix="\t\t",suffix="\n")
    end

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

function _build_parameter_alias_snippet(parameter_symbol_array::Array{String,1})::String

    # initialize -
    buffer = Array{String,1}()

    # build the alias -
    for (index, parameter_symbol) in enumerate(parameter_symbol_array)
        if (index == 1)
            +(buffer,"$(parameter_symbol) = model_parameter_array[model_parameter_index_map[:$(parameter_symbol)]]"; suffix="\n")
        else
            +(buffer,"$(parameter_symbol) = model_parameter_array[model_parameter_index_map[:$(parameter_symbol)]]"; prefix="\t", suffix="\n")
        end
    end

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

function _build_degradation_dilution_snippet(model::VLJuliaModelObject, 
    ir_dictionary::Dict{String,Any})::String

    # initialize -
    buffer = Array{String,1}()
    model_species_table = ir_dictionary["model_species_table"]

    # iterate -
    (number_of_species, _) = size(model_species_table)
    for species_index = 1:number_of_species
        
        # get type and species -
        species_type = model_species_table[species_index, :type]
        species_symbol = model_species_table[species_index, :symbol]

        # if not DNA
        if (species_type != :DNA)

            prefix_string=""
            if (species_index>1)
                prefix_string="\t"
            end
            
            +(buffer, "push!(degradation_dilution_array, (μ + 𝛳_$(species_symbol))*$(species_symbol))"; prefix=prefix_string, suffix="\n")
        end
    end

    # flatten and return -
    flat_buffer = ""
    [flat_buffer *= line for line in buffer]
    return flat_buffer
end

# == MAIN METHODS BELOW HERE ======================================================================= #
function generate_data_dictionary_program_component(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::NamedTuple

    # initialize -
    filename = "Problem.jl"
    buffer = Array{String,1}()
    template_dictionary = Dict{String,Any}()

    try 

        # build the snippets required by the 
        template_dictionary["copyright_header_text"] = build_julia_copyright_header_buffer(ir_dictionary)
        template_dictionary["initial_condition_array_block"] = _build_ic_array_snippet(model, ir_dictionary)
        template_dictionary["system_species_array_block"] = _build_system_species_concentration_snippet(model, ir_dictionary)
        template_dictionary["system_type_flag"] = _build_system_type_snippet(model, ir_dictionary)
        
        # we get the parameter array back in addition 2 the flat buffer for this method -
        results_tuple = _build_model_parameter_array_snippet(model, ir_dictionary)
        template_dictionary["model_parameter_array_block"] = results_tuple.flat_buffer

        # symbol index map -
        template_dictionary["model_parameter_symbol_index_map_block"] = _build_model_parameter_symbol_index_map(results_tuple.parameter_symbol_array)
        template_dictionary["inverse_model_parameter_symbol_index_map_block"] = _build_inverse_model_parameter_symbol_index_map(results_tuple.parameter_symbol_array)

        # write the template -
        template = mt"""
        {{copyright_header_text}}
        function generate_problem_dictionary()::Dict{String,Any}
            
            # initialize -
            problem_dictionary = Dict{String,Any}()
            system_type_flag = {{system_type_flag}}

            try

                # load the stoichiometric_matrix (SM) and degradation_dilution_matrix (DM) -
                SM = readdlm(joinpath(_PATH_TO_NETWORK,"Network.dat"))
                DM = readdlm(joinpath(_PATH_TO_NETWORK,"Degradation.dat"))

                # build the species initial condition array -
                {{initial_condition_array_block}}

                # build the system species concentration array -
                {{system_species_array_block}}

                # get the biophysical parameters for this system type -
                biophysical_parameters_dictionary = get_biophysical_parameters_dictionary_for_system(system_type_flag)

                # setup the model parameter array -
                {{model_parameter_array_block}}

                # setup the parameter symbol index map -
                {{model_parameter_symbol_index_map_block}}

                # setup the inverse parameter symbol index map -
                {{inverse_model_parameter_symbol_index_map_block}}

                # growth rate (default: h^-1)
                μ = 0.0 # default units: h^-1

                # == DO NOT EDIT BELOW THIS LINE ========================================================== #
                problem_dictionary["initial_condition_array"] = initial_condition_array
                problem_dictionary["system_concentration_array"] = system_concentration_array
                problem_dictionary["biophysical_parameters_dictionary"] = biophysical_parameters_dictionary
                problem_dictionary["model_parameter_array"] = model_parameter_array
                problem_dictionary["model_parameter_symbol_index_map"] = model_parameter_symbol_index_map
                problem_dictionary["inverse_model_parameter_symbol_index_map"] = inverse_model_parameter_symbol_index_map
                problem_dictionary["stoichiometric_matrix"] = SM
                problem_dictionary["dilution_degradation_matrix"] = DM
                problem_dictionary["specific_growth_rate"] = μ

                # return -
                return problem_dictionary
                # ========================================================================================= #
            catch error
                throw(error)
            end
        end
        """

        # render step -
        flat_buffer = render(template, template_dictionary)
        
        # package up into a NamedTuple -
        program_component = (buffer=flat_buffer, filename=filename, component_type=:buffer)

        # return -
        return program_component
    catch error
        rethrow(error)
    end
end

function generate_kinetics_program_component(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::NamedTuple

    # initialize -
    filename = "Kinetics.jl"
    template_dictionary = Dict{String,Any}()

    try

        # we get the parameter array back in addition 2 the flat buffer for this method -
        results_tuple = _build_model_parameter_array_snippet(model, ir_dictionary)
        parameter_symbol_array = results_tuple.parameter_symbol_array

        # build snippets -
        template_dictionary["copyright_header_text"] = build_julia_copyright_header_buffer(ir_dictionary)
        template_dictionary["model_species_alias_block"] = _build_model_species_alias_snippet(model, ir_dictionary)
        template_dictionary["system_species_alias_block"] = _build_system_species_alias_snippet(model, ir_dictionary)
        template_dictionary["transcription_kinetic_limit_block"] = _build_transcription_kinetic_limit_snippet(model, ir_dictionary)
        template_dictionary["translation_kinetic_limit_block"] = _build_translation_kinetic_limit_snippet(model, ir_dictionary)
        template_dictionary["system_parameter_alias_block"] = _build_parameter_alias_snippet(parameter_symbol_array)
        template_dictionary["degradation_dilution_terms_block"] = _build_degradation_dilution_snippet(model, ir_dictionary)

        # setup the template -
        template = mt"""
        {{copyright_header_text}}

        function calculate_transcription_kinetic_limit_array(t::Float64, x::Array{Float64,1}, 
            problem_dictionary::Dict{String,Any})::Array{Float64,1}
            
            # initialize -
            kinetic_limit_array = Array{Float64,1}()
            system_array = problem_dictionary["system_concentration_array"]
            eX = problem_dictionary["biophysical_parameters_dictionary"]["transcription_elongation_rate"]       # default units: nt/s
            LX = problem_dictionary["biophysical_parameters_dictionary"]["characteristic_transcript_length"]    # default units: nt
            k_cat_characteristic = (eX/LX)

            # helper function -
            r(kcat, L_char, L, polymerase, 𝛕, K, species) = kcat*(L_char/L)*polymerase*(species/(𝛕*K+(1+𝛕)*species))

            # alias the model species -
            {{model_species_alias_block}}

            # alias the system species -
            {{system_species_alias_block}}

            # alias the system parameters -
            {{system_parameter_alias_block}}

            # compute the transcription kinetic limit array -
            {{transcription_kinetic_limit_block}}

            # return -
            return kinetic_limit_array
        end

        function calculate_translation_kinetic_limit_array(t::Float64, x::Array{Float64,1}, 
            problem_dictionary::Dict{String,Any})::Array{Float64,1}
        
            # initialize -
            kinetic_limit_array = Array{Float64,1}()
            system_array = problem_dictionary["system_concentration_array"]
            eL = problem_dictionary["biophysical_parameters_dictionary"]["translation_elongation_rate"]         # default units: aa/s
            LL = problem_dictionary["biophysical_parameters_dictionary"]["characteristic_protein_length"]       # default units: aa
            k_cat_characteristic = (eL/LL)

            # helper function -
            r(kcat, L_char, L, ribosome, 𝛕, K, species) = kcat*(L_char/L)*ribosome*(species/(𝛕*K+(1+𝛕)*species))
            
            # alias the model species -
            {{model_species_alias_block}}

            # alias the system species -
            {{system_species_alias_block}}

            # alias the system parameters -
            {{system_parameter_alias_block}}
            
            # compute the translation kinetic limit array -
            {{translation_kinetic_limit_block}}
        
            # return -
            return kinetic_limit_array
        end

        function calculate_dilution_degradation_array(t::Float64, x::Array{Float64,1}, 
            problem_dictionary::Dict{String,Any})::Array{Float64,1}
            
            # initialize -
            μ = problem_dictionary["specific_growth_rate"]
            degradation_dilution_array = Array{Float64,1}()
            
            # alias the model species -
            {{model_species_alias_block}}

            # alias the system parameters -
            {{system_parameter_alias_block}}

            # formulate the degradation and dilution terms -
            {{degradation_dilution_terms_block}}
        
            # return -
            return degradation_dilution_array
        end
        """

        # render step -
        flat_buffer = render(template, template_dictionary)
        
        # package up into a NamedTuple -
        program_component = (buffer=flat_buffer, filename=filename, component_type=:buffer)

        # return -
        return program_component
    catch error
        rethrow(error)
    end
end

function generate_balances_program_component(model::VLJuliaModelObject, 
    ir_dictionary::Dict{String,Any})::NamedTuple

    # initialize -
    filename = "Balances.jl"
    template_dictionary = Dict{String,Any}()

    try

        # build snippets -
        template_dictionary["copyright_header_text"] = build_julia_copyright_header_buffer(ir_dictionary)

        # setup the template -
        template = mt"""
        {{copyright_header_text}}
        function Balances(dx,x, problem_dictionary,t)

            # system dimensions and structural matricies -
            number_of_states = problem_dictionary["number_of_states"]
            DM = problem_dictionary["dilution_degradation_matrix"]
            SM = problem_dictionary["stoichiometric_matrix"]
             
            # calculate the TX and TL kinetic limit array -
            transcription_kinetic_limit_array = calculate_transcription_kinetic_limit_array(t,x,problem_dictionary)
            translation_kinetic_limit_array = calculate_translation_kinetic_limit_array(t,x,problem_dictionary)
            
            # calculate the TX and TL control array -
            u = calculate_transcription_control_array(t,x,problem_dictionary)
            w = calculate_translation_control_array(t,x,problem_dictionary)

            # calculate the rate of transcription and translation -
            rX = transcription_kinetic_limit_array.*u
            rL = translation_kinetic_limit_array.*w
            rV = [rX ; rL]

            # calculate the degradation and dilution rates -
            rd = calculate_dilution_degradation_array(t,x,problem_dictionary)

            # compute the model equations -
            dxdt = SM*rV + DM*rd

            # package -
            for index = 1:number_of_states
                dx[index] = dxdt[index]
            end
        end
        """

        # render step -
        flat_buffer = render(template, template_dictionary)
        
        # package up into a NamedTuple -
        program_component = (buffer=flat_buffer, filename=filename, component_type=:buffer)

        # return -
        return program_component
    catch error
        rethrow(error)
    end
end

function generate_control_program_component(model::VLJuliaModelObject, 
    ir_dictionary::Dict{String,Any})::NamedTuple

    # initialize -
    filename = "Control.jl"
    template_dictionary = Dict{String,Any}()

    try

        # we get the parameter array back in addition 2 the flat buffer for this method -
        results_tuple = _build_model_parameter_array_snippet(model, ir_dictionary)
        parameter_symbol_array = results_tuple.parameter_symbol_array

        # build snippets -
        template_dictionary["copyright_header_text"] = build_julia_copyright_header_buffer(ir_dictionary)
        template_dictionary["u_variable_snippet"] = _build_u_variable_snippet(model,ir_dictionary)
        template_dictionary["model_species_alias_block"] = _build_model_species_alias_snippet(model, ir_dictionary)
        template_dictionary["system_species_alias_block"] = _build_system_species_alias_snippet(model, ir_dictionary)
        template_dictionary["system_parameter_alias_block"] = _build_parameter_alias_snippet(parameter_symbol_array)

        # build template -
        template=mt"""
        {{copyright_header_text}}
        
        # calculate the u-variables -
        function calculate_transcription_control_array(t::Float64, x::Array{Float64,1}, 
            problem_dictionary::Dict{String,Any})::Array{Float64,1}

            # initialize -
            number_of_transcription_processes = problem_dictionary["number_of_transcription_processes"]
            model_parameter_array = problem_dictionary["model_parameter_array"]
            model_parameter_index_map = problem_dictionary["model_parameter_symbol_index_map"]
            u_array = Array{Float64,1}(undef,number_of_transcription_processes)

            # local helper functions -
            f(x,K,n) = (x^n)/(K^n+x^n)
            u(A,R) = A/(1+A+R)

            # alias the state vector -
            {{model_species_alias_block}}

            # alias the system species -
            system_array = problem_dictionary["system_concentration_array"]
            {{system_species_alias_block}}

            # alias the system parameters -
            {{system_parameter_alias_block}}

            # == CONTROL LOGIC BELOW ================================================================= #
            {{u_variable_snippet}}
            # == CONTROL LOGIC ABOVE ================================================================= #

            # return -
            return u_array
        end

        # calculate the w-variables -
        function calculate_translation_control_array(t::Float64, x::Array{Float64,1}, 
            problem_dictionary::Dict{String,Any})::Array{Float64,1}
            
            # defualt: w = 1 for all translation processes -
            number_of_translation_processes = problem_dictionary["number_of_translation_processes"]
            w = ones(number_of_translation_processes)
            
            # return -
            return w
        end
        """

        # render step -
        flat_buffer = render(template, template_dictionary)
        
        # package up into a NamedTuple -
        program_component = (buffer=flat_buffer, filename=filename, component_type=:buffer)

        # return -
        return program_component
    catch error
        rethrow(error)
    end
end

function generate_init_program_component(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::NamedTuple

    # initialize -
    filename = "Initialize.jl"
    template_dictionary = Dict{String,Any}()

    try

        # build snippets -
        template_dictionary["copyright_header_text"] = build_julia_copyright_header_buffer(ir_dictionary)

        # build template -
        template=mt"""
        {{copyright_header_text}}

        # stuff we need -
        import Pkg

        # initialization function -
        function __init__()
            
            # setup paths -
            _PATH_TO_ROOT = pwd()

            # get packages -
            Pkg.activate(_PATH_TO_ROOT)
            Pkg.add(name="DifferentialEquations")
            Pkg.add(name="VLModelParametersDB")
            Pkg.add(name="DelimitedFiles")
        end

        # init me -
        __init__()
        """

        # render step -
        flat_buffer = render(template, template_dictionary)
        
        # package up into a NamedTuple -
        program_component = (buffer=flat_buffer, filename=filename, component_type=:buffer)

        # return -
        return program_component
    catch error
        rethrow(error)
    end
end

function generate_include_program_component(model::VLJuliaModelObject, ir_dictionary::Dict{String,Any})::NamedTuple

    # initialize -
    filename = "Include.jl"
    template_dictionary = Dict{String,Any}()

    try

        # build snippets -
        template_dictionary["copyright_header_text"] = build_julia_copyright_header_buffer(ir_dictionary)

        # build template -
        template=mt"""
        {{copyright_header_text}}

        # setup paths -
        const _PATH_TO_ROOT = pwd()
        const _PATH_TO_SRC = joinpath(_PATH_TO_ROOT, "src")
        const _PATH_TO_NETWORK = joinpath(_PATH_TO_SRC, "network")

        # use packages -
        using DifferentialEquations
        using VLModelParametersDB
        using DelimitedFiles

        # include my codes -
        include("./src/Problem.jl")
        include("./src/Balances.jl")
        include("./src/Kinetics.jl")
        include("./src/Control.jl")
        """

        # render step -
        flat_buffer = render(template, template_dictionary)
        
        # package up into a NamedTuple -
        program_component = (buffer=flat_buffer, filename=filename, component_type=:buffer)

        # return -
        return program_component
    catch error
        rethrow(error)
    end
end
# ================================================================================================= #"kinetic_limit_array