struct ModelConfig: Decodable {
    let tokenizerFiles: [String]
    var modelLib: String?
    var modelID: String?
    var estimatedVRAMReq: Int?
    var displayName: String?  // 添加新属性

    enum CodingKeys: String, CodingKey {
        case tokenizerFiles = "tokenizer_files"
        case modelLib = "model_lib"
        case modelID = "model_id"
        case estimatedVRAMReq = "estimated_vram_req"
        case displayName = "display_name"  // 添加对应的编码键
    }
}
