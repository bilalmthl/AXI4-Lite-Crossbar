module rr_arbiter #(
    parameter int N_REQ = 4
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [N_REQ-1:0] req_i,   
    input  logic             ack_i,   // Acknowledgment that the granted Master is done
    output logic [N_REQ-1:0] grant_o  

    logic [N_REQ-1:0] mask_q;
    logic [N_REQ-1:0] masked_req;
    logic [N_REQ-1:0] grant_masked;
    logic [N_REQ-1:0] grant_unmasked;

    // Mask out the masters that have equal or higher priority than the last granted
    assign masked_req = req_i & mask_q;

    // Find the lowest bit set in the MASKED requests
    assign grant_masked = masked_req & ~(masked_req - 1); 

    // Find the lowest bit set in the UNMASKED requests
    assign grant_unmasked = req_i & ~(req_i - 1);

    // If there's a valid masked request, grant it. Otherwise, wrap around
    assign grant_o = (masked_req == 0) ? grant_unmasked : grant_masked;

    // Update mask pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // On reset all masters are unmasked (mask is all 1s)
            mask_q <= {N_REQ{1'b1}};
        end else if (|req_i && ack_i) begin 
            // When a master is granted and finishes, update the mask. Sets priority to mask above grant
            mask_q <= ~((grant_o - 1) | grant_o);
        end
    end

endmodule