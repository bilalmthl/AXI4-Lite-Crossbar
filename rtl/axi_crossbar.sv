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

    // Write path decoders
    logic [M_SLAVES-1:0] aw_master_match [N_MASTERS];
    logic [N_MASTERS-1:0] aw_decerr;

    // Read path decoders
    logic [M_SLAVES-1:0] ar_master_match [N_MASTERS];
    logic [N_MASTERS-1:0] ar_decerr;

    generate
        for (genvar i = 0; i < N_MASTERS; i++) begin : gen_decoders
            axi_decoder #(
                .M_SLAVES(M_SLAVES)
            ) u_aw_dec (
                .addr_i  (s_cpu_if[i].awaddr),
                .valid_i (s_cpu_if[i].awvalid),
                .match_o (aw_master_match[i]),
                .decerr_o(aw_decerr[i])
            );

            axi_decoder #(
                .M_SLAVES(M_SLAVES)
            ) u_ar_dec (
                .addr_i  (s_cpu_if[i].araddr),
                .valid_i (s_cpu_if[i].arvalid),
                .match_o (ar_master_match[i]),
                .decerr_o(ar_decerr[i])
            );
        end
    endgenerate

    // Routing matrices
    logic [N_MASTERS-1:0] w_slave_req [M_SLAVES];
    logic [N_MASTERS-1:0] w_slave_grant [M_SLAVES];
    logic                 w_slave_ack [M_SLAVES];

    logic [N_MASTERS-1:0] r_slave_req [M_SLAVES];
    logic [N_MASTERS-1:0] r_slave_grant [M_SLAVES];
    logic                 r_slave_ack [M_SLAVES];

    always_comb begin
        for (int j = 0; j < M_SLAVES; j++) begin
            for (int i = 0; i < N_MASTERS; i++) begin
                w_slave_req[j][i] = aw_master_match[i][j];
                r_slave_req[j][i] = ar_master_match[i][j];
            end
        end
    end

    typedef enum logic [1:0] {W_IDLE, W_ADDR_DATA, W_RESP} w_state_t;
    typedef enum logic [1:0] {R_IDLE, R_ADDR, R_DATA} r_state_t;

    generate
        for (genvar j = 0; j < M_SLAVES; j++) begin : gen_slave_logic
            
            // Write arbiter
            rr_arbiter #(.N_REQ(N_MASTERS)) u_w_arbiter (
                .clk    (aclk),
                .rst_n  (aresetn),
                .req_i  (w_slave_req[j]),
                .ack_i  (w_slave_ack[j]),
                .grant_o(w_slave_grant[j])
            );

            // Read arbiter
            rr_arbiter #(.N_REQ(N_MASTERS)) u_r_arbiter (
                .clk    (aclk),
                .rst_n  (aresetn),
                .req_i  (r_slave_req[j]),
                .ack_i  (r_slave_ack[j]),
                .grant_o(r_slave_grant[j])
            );

            // Write FSM
            w_state_t w_state_q, w_state_d;
            logic aw_done_q, aw_done_d;
            logic w_done_q,  w_done_d;
            
            // Read FSM
            r_state_t r_state_q, r_state_d;

            always_ff @(posedge aclk or negedge aresetn) begin
                if (!aresetn) begin
                    w_state_q <= W_IDLE;
                    aw_done_q <= 1'b0;
                    w_done_q  <= 1'b0;
                    
                    r_state_q <= R_IDLE;
                end else begin
                    w_state_q <= w_state_d;
                    aw_done_q <= aw_done_d;
                    w_done_q  <= w_done_d;
                    
                    r_state_q <= r_state_d;
                end
            end

            // Write FSM logic
            always_comb begin
                w_state_d   = w_state_q;
                aw_done_d   = aw_done_q;
                w_done_d    = w_done_q;
                w_slave_ack[j] = 1'b0;

                case (w_state_q)
                    W_IDLE: begin
                        aw_done_d = 1'b0;
                        w_done_d  = 1'b0;
                        if (|w_slave_grant[j]) w_state_d = W_ADDR_DATA;
                    end
                    W_ADDR_DATA: begin
                        if (m_peri_if[j].awvalid && m_peri_if[j].awready) aw_done_d = 1'b1;
                        if (m_peri_if[j].wvalid  && m_peri_if[j].wready)  w_done_d  = 1'b1;

                        if ((aw_done_q || (m_peri_if[j].awvalid && m_peri_if[j].awready)) && 
                            (w_done_q  || (m_peri_if[j].wvalid  && m_peri_if[j].wready))) begin
                            w_state_d = W_RESP;
                        end
                    end
                    W_RESP: begin
                        if (m_peri_if[j].bvalid && m_peri_if[j].bready) begin
                            w_slave_ack[j] = 1'b1;
                            w_state_d = W_IDLE;
                        end
                    end
                    default: w_state_d = W_IDLE;
                endcase
            end

            // Read FSM logic
            always_comb begin
                r_state_d = r_state_q;
                r_slave_ack[j] = 1'b0;

                case (r_state_q)
                    R_IDLE: begin
                        if (|r_slave_grant[j]) r_state_d = R_ADDR;
                    end
                    R_ADDR: begin
                        if (m_peri_if[j].arvalid && m_peri_if[j].arready) r_state_d = R_DATA;
                    end
                    R_DATA: begin
                        if (m_peri_if[j].rvalid && m_peri_if[j].rready) begin
                            r_slave_ack[j] = 1'b1;
                            r_state_d = R_IDLE;
                        end
                    end
                    default: r_state_d = R_IDLE;
                endcase
            end

            // Write datapath multiplexing
            always_comb begin
                if (w_slave_grant[j][1]) begin
                    m_peri_if[j].awaddr  = s_cpu_if[1].awaddr;
                    m_peri_if[j].awvalid = s_cpu_if[1].awvalid && (w_state_q == W_ADDR_DATA) && !aw_done_q;
                    m_peri_if[j].wdata   = s_cpu_if[1].wdata;
                    m_peri_if[j].wvalid  = s_cpu_if[1].wvalid && (w_state_q == W_ADDR_DATA) && !w_done_q;
                    m_peri_if[j].bready  = s_cpu_if[1].bready && (w_state_q == W_RESP);
                    
                    s_cpu_if[1].awready  = m_peri_if[j].awready && (w_state_q == W_ADDR_DATA) && !aw_done_q;
                    s_cpu_if[1].wready   = m_peri_if[j].wready  && (w_state_q == W_ADDR_DATA) && !w_done_q;
                    s_cpu_if[1].bvalid   = m_peri_if[j].bvalid  && (w_state_q == W_RESP);
                    s_cpu_if[1].bresp    = m_peri_if[j].bresp;
                end else begin
                    m_peri_if[j].awaddr  = s_cpu_if[0].awaddr;
                    m_peri_if[j].awvalid = s_cpu_if[0].awvalid && (w_state_q == W_ADDR_DATA) && !aw_done_q;
                    m_peri_if[j].wdata   = s_cpu_if[0].wdata;
                    m_peri_if[j].wvalid  = s_cpu_if[0].wvalid && (w_state_q == W_ADDR_DATA) && !w_done_q;
                    m_peri_if[j].bready  = s_cpu_if[0].bready && (w_state_q == W_RESP);
                    
                    s_cpu_if[0].awready  = m_peri_if[j].awready && (w_state_q == W_ADDR_DATA) && !aw_done_q;
                    s_cpu_if[0].wready   = m_peri_if[j].wready  && (w_state_q == W_ADDR_DATA) && !w_done_q;
                    s_cpu_if[0].bvalid   = m_peri_if[j].bvalid  && (w_state_q == W_RESP);
                    s_cpu_if[0].bresp    = m_peri_if[j].bresp;
                end
            end

            // Read datapath multiplexing
            always_comb begin
                if (r_slave_grant[j][1]) begin
                    m_peri_if[j].araddr  = s_cpu_if[1].araddr;
                    m_peri_if[j].arvalid = s_cpu_if[1].arvalid && (r_state_q == R_ADDR);
                    m_peri_if[j].rready  = s_cpu_if[1].rready  && (r_state_q == R_DATA);
                    
                    s_cpu_if[1].arready  = m_peri_if[j].arready && (r_state_q == R_ADDR);
                    s_cpu_if[1].rvalid   = m_peri_if[j].rvalid  && (r_state_q == R_DATA);
                    s_cpu_if[1].rdata    = m_peri_if[j].rdata;
                    s_cpu_if[1].rresp    = m_peri_if[j].rresp;
                end else begin
                    m_peri_if[j].araddr  = s_cpu_if[0].araddr;
                    m_peri_if[j].arvalid = s_cpu_if[0].arvalid && (r_state_q == R_ADDR);
                    m_peri_if[j].rready  = s_cpu_if[0].rready  && (r_state_q == R_DATA);
                    
                    s_cpu_if[0].arready  = m_peri_if[j].arready && (r_state_q == R_ADDR);
                    s_cpu_if[0].rvalid   = m_peri_if[j].rvalid  && (r_state_q == R_DATA);
                    s_cpu_if[0].rdata    = m_peri_if[j].rdata;
                    s_cpu_if[0].rresp    = m_peri_if[j].rresp;
                end
            end
            
            assign m_peri_if[j].awprot = '0;
            assign m_peri_if[j].wstrb  = '0;
            assign m_peri_if[j].arprot = '0;
        end
    endgenerate

endmodule