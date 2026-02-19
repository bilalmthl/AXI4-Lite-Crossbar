module axi_crossbar #(
    parameter int N_MASTERS = 2,
    parameter int M_SLAVES = 2,
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input logic aclk,
    input logic aresetn,
    
    axi_lite_if.slave  s_cpu_if [N_MASTERS], 
    axi_lite_if.master m_peri_if [M_SLAVES] 
);

    // Decoder wires and instantiation
    logic [M_SLAVES-1:0] master_match [N_MASTERS];
    logic [N_MASTERS-1:0] decerr;

    generate
        for (genvar i = 0; i < N_MASTERS; i++) begin : gen_decoders
            axi_decoder #(
                .M_SLAVES(M_SLAVES)
            ) u_dec (
                .addr_i  (s_cpu_if[i].awaddr),
                .valid_i (s_cpu_if[i].awvalid),
                .match_o (master_match[i]),
                .decerr_o(decerr[i])
            );
        end
    endgenerate

    // Routing matrix
    logic [N_MASTERS-1:0] slave_req [M_SLAVES];
    logic [N_MASTERS-1:0] slave_grant [M_SLAVES];
    logic                 slave_ack [M_SLAVES];

    always_comb begin
        for (int j = 0; j < M_SLAVES; j++) begin
            for (int i = 0; i < N_MASTERS; i++) begin
                slave_req[j][i] = master_match[i][j];
            end
        end
    end

    // Arbiter and handshake FSM per slave
    typedef enum logic [1:0] {W_IDLE, W_ADDR_DATA, W_RESP} w_state_t;

    generate
        for (genvar j = 0; j < M_SLAVES; j++) begin : gen_slave_logic
            
            rr_arbiter #(
                .N_REQ(N_MASTERS)
            ) u_arbiter (
                .clk    (aclk),
                .rst_n  (aresetn),
                .req_i  (slave_req[j]),
                .ack_i  (slave_ack[j]),
                .grant_o(slave_grant[j])
            );

            // FSM
            w_state_t state_q, state_d;
            logic aw_done_q, aw_done_d;
            logic w_done_q,  w_done_d;
            
            always_ff @(posedge aclk or negedge aresetn) begin
                if (!aresetn) begin
                    state_q   <= W_IDLE;
                    aw_done_q <= 1'b0;
                    w_done_q  <= 1'b0;
                end else begin
                    state_q   <= state_d;
                    aw_done_q <= aw_done_d;
                    w_done_q  <= w_done_d;
                end
            end

            always_comb begin
                state_d   = state_q;
                aw_done_d = aw_done_q;
                w_done_d  = w_done_q;
                slave_ack[j] = 1'b0;

                case (state_q)
                    W_IDLE: begin
                        aw_done_d = 1'b0;
                        w_done_d  = 1'b0;
                        if (|slave_grant[j]) begin
                            state_d = W_ADDR_DATA;
                        end
                    end

                    W_ADDR_DATA: begin
                        // Track independent AW and W handshakes
                        if (m_peri_if[j].awvalid && m_peri_if[j].awready) aw_done_d = 1'b1;
                        if (m_peri_if[j].wvalid  && m_peri_if[j].wready)  w_done_d  = 1'b1;

                        if ((aw_done_q || (m_peri_if[j].awvalid && m_peri_if[j].awready)) && 
                            (w_done_q  || (m_peri_if[j].wvalid  && m_peri_if[j].wready))) begin
                            state_d = W_RESP;
                        end
                    end

                    W_RESP: begin
                        if (m_peri_if[j].bvalid && m_peri_if[j].bready) begin
                            slave_ack[j] = 1'b1;
                            state_d = W_IDLE;
                        end
                    end
                    
                    default: state_d = W_IDLE;
                endcase
            end

            // Datapath multiplexing
            always_comb begin
                if (slave_grant[j][1]) begin
                    m_peri_if[j].awaddr  = s_cpu_if[1].awaddr;
                    m_peri_if[j].awvalid = s_cpu_if[1].awvalid && (state_q == W_ADDR_DATA) && !aw_done_q;
                    m_peri_if[j].wdata   = s_cpu_if[1].wdata;
                    m_peri_if[j].wvalid  = s_cpu_if[1].wvalid && (state_q == W_ADDR_DATA) && !w_done_q;
                    m_peri_if[j].bready  = s_cpu_if[1].bready && (state_q == W_RESP);
                    
                    s_cpu_if[1].awready  = m_peri_if[j].awready && (state_q == W_ADDR_DATA) && !aw_done_q;
                    s_cpu_if[1].wready   = m_peri_if[j].wready  && (state_q == W_ADDR_DATA) && !w_done_q;
                    s_cpu_if[1].bvalid   = m_peri_if[j].bvalid  && (state_q == W_RESP);
                    s_cpu_if[1].bresp    = m_peri_if[j].bresp;
                end else begin
                    m_peri_if[j].awaddr  = s_cpu_if[0].awaddr;
                    m_peri_if[j].awvalid = s_cpu_if[0].awvalid && (state_q == W_ADDR_DATA) && !aw_done_q;
                    m_peri_if[j].wdata   = s_cpu_if[0].wdata;
                    m_peri_if[j].wvalid  = s_cpu_if[0].wvalid && (state_q == W_ADDR_DATA) && !w_done_q;
                    m_peri_if[j].bready  = s_cpu_if[0].bready && (state_q == W_RESP);
                    
                    s_cpu_if[0].awready  = m_peri_if[j].awready && (state_q == W_ADDR_DATA) && !aw_done_q;
                    s_cpu_if[0].wready   = m_peri_if[j].wready  && (state_q == W_ADDR_DATA) && !w_done_q;
                    s_cpu_if[0].bvalid   = m_peri_if[j].bvalid  && (state_q == W_RESP);
                    s_cpu_if[0].bresp    = m_peri_if[j].bresp;
                end
            end
            
            // Temporarily tie off read channels
            assign m_peri_if[j].araddr  = '0;
            assign m_peri_if[j].arvalid = 1'b0;
            assign m_peri_if[j].arprot  = '0;
            assign m_peri_if[j].rready  = 1'b0;
            assign m_peri_if[j].awprot  = '0;
            assign m_peri_if[j].wstrb   = '0;
        end
    endgenerate

    // Temporarily tie off master read channels
    generate
        for (genvar i = 0; i < N_MASTERS; i++) begin : gen_master_read_tie
            assign s_cpu_if[i].arready = 1'b0;
            assign s_cpu_if[i].rvalid  = 1'b0;
            assign s_cpu_if[i].rdata   = '0;
            assign s_cpu_if[i].rresp   = 2'b00;
        end
    endgenerate

endmodule