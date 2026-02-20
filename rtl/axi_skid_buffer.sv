module axi_skid_buffer #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                   aclk,
    input  logic                   aresetn,

    // Upstream (Slave-like)
    input  logic [DATA_WIDTH-1:0]  s_data_i,
    input  logic                   s_valid_i,
    output logic                   s_ready_o,

    // Downstream (Master-like)
    output logic [DATA_WIDTH-1:0]  m_data_o,
    output logic                   m_valid_o,
    input  logic                   m_ready_i
);

    // Main and shadow registers
    logic [DATA_WIDTH-1:0] data_q, shadow_q;
    logic                  valid_q, shadow_valid_q;

    // Upstream ready if shadow register is empty
    assign s_ready_o = !shadow_valid_q;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            data_q         <= '0;
            shadow_q       <= '0;
            valid_q        <= 1'b0;
            shadow_valid_q <= 1'b0;
        end else begin
            // Input handshake: s_valid_i && s_ready_o
            if (s_valid_i && s_ready_o) begin
                if (m_valid_o && !m_ready_i) begin
                    // Backpressure: move current data to shadow, new to main
                    shadow_q       <= data_q;
                    shadow_valid_q <= 1'b1;
                    data_q         <= s_data_i;
                end else begin
                    // Normal flow
                    data_q         <= s_data_i;
                    valid_q        <= 1'b1;
                end
            end

            // Output handshake: m_valid_o && m_ready_i
            if (m_valid_o && m_ready_i) begin
                if (shadow_valid_q) begin
                    // Drain shadow register
                    data_q         <= shadow_q;
                    shadow_valid_q <= 1'b0;
                end else begin
                    // Nothing left to drain
                    valid_q        <= 1'b0;
                end
            end
        end
    end

    assign m_data_o  = data_q;
    assign m_valid_o = valid_q;

endmodule