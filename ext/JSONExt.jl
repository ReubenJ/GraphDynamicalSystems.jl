module JSONExt
import GraphDynamicalSystems.QualitativeNetwork
import JSON

using AbstractTrees: PostOrderDFS
using GraphDynamicalSystems: QualitativeNetwork, bma_dict_to_qn, qn_to_bma_dict

function QualitativeNetwork(bma_file_path::AbstractString)
    json_def = JSON.parse(read(bma_file_path, String))

    return bma_dict_to_qn(json_def)
end

function JSON.json(qn::QualitativeNetwork)
    return JSON.json(qn_to_bma_dict(qn))
end

end
