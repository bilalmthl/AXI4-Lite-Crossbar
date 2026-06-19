module axi_skid_buffer #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                   aclk,
    input  logic                   aresetn,
    input  logic [DATA_WIDTH-1:0]  s_data_i,
    input  logic                   s_valid_i,
    output logic                   s_ready_o,
    output logic [DATA_WIDTH-1:0]  m_data_o,
    output logic                   m_valid_o,
    input  logic                   m_ready_i
);

    // Primary data register and a secondary shadow skid register
    logic [DATA_WIDTH-1:0] data_q, shadow_q;
    logic                  valid_q, shadow_valid_q;

    // Apply backpressure only if the shadow register is occupied
    assign s_ready_o = !shadow_valid_q;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            data_q         <= '0;
            shadow_q       <= '0;
            valid_q        <= 1'b0;
            shadow_valid_q <= 1'b0;
        end else begin
            // Handshake logic: Accepting new data
            if (s_valid_i && s_ready_o) begin
                // The skid scenario: New data arriving, but downstream module is not ready.
                // Safely catch the existing data in the shadow register to prevent overwriting.
                if (m_valid_o && !m_ready_i) begin
                    shadow_q       <= data_q;
                    shadow_valid_q <= 1'b1;
                    data_q         <= s_data_i;
                end else begin
                    // Standard pipelining logic
                    data_q         <= s_data_i;
                    valid_q        <= 1'b1;
                end
            end
            
            // Handshake logic: Downstream module successfully reads data
            if (m_valid_o && m_ready_i) begin
                // If data was skidded, recover it back into the primary output register
                if (shadow_valid_q) begin
                    data_q         <= shadow_q;
                    shadow_valid_q <= 1'b0;
                end else begin
                    // Otherwise, the buffer is now empty
                    valid_q        <= 1'b0;
                end
            end
        end
    end

    // Direct physical assignments from the primary register
    assign m_data_o  = data_q;
    assign m_valid_o = valid_q;
endmodule