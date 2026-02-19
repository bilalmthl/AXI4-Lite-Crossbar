module axi_decoder #(
    parameter int M_SLAVES = 2,
    // Slave 0
    // Slave 1
    parameter logic [31:0] BASE_ADDR [M_SLAVES] = '{32'h4000_0000, 32'h4400_0000},
    parameter logic [31:0] ADDR_MASK [M_SLAVES] = '{32'hFFFF_0000, 32'hFFFF_0000}
) (
    input  logic [31:0]         addr_i,    
    input  logic                valid_i,  
    output logic [M_SLAVES-1:0] match_o,  
    output logic                decerr_o   // High if address doesn't match any slave
);

    logic [M_SLAVES-1:0] match_int;

    always_comb begin
        match_int = '0; // Default to no matches
        
        if (valid_i) begin
            for (int i = 0; i < M_SLAVES; i++) begin
                // Bitwise mask comparison
                if ((addr_i & ADDR_MASK[i]) == (BASE_ADDR[i] & ADDR_MASK[i])) begin
                    match_int[i] = 1'b1;
                end
            end
        end
    end

    assign match_o = match_int;
    
    // If a valid request comes in but no bits in match_int are high
    assign decerr_o = valid_i & ~(|match_int); 

endmodule