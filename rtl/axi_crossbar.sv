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

    axi_lite_if s_core_if [N_MASTERS] (aclk, aresetn);
    axi_lite_if m_core_if [M_SLAVES] (aclk, aresetn);

    generate
        for (genvar i = 0; i < N_MASTERS; i++) begin : gen_master_skids
            axi_skid_buffer #(.DATA_WIDTH(32)) u_skid_aw (
                .aclk(aclk), .aresetn(aresetn),
                .s_data_i(s_cpu_if[i].awaddr), .s_valid_i(s_cpu_if[i].awvalid), .s_ready_o(s_cpu_if[i].awready),
                .m_data_o(s_core_if[i].awaddr), .m_valid_o(s_core_if[i].awvalid), .m_ready_i(s_core_if[i].awready)
            );
            axi_skid_buffer #(.DATA_WIDTH(32)) u_skid_w (
                .aclk(aclk), .aresetn(aresetn),
                .s_data_i(s_cpu_if[i].wdata), .s_valid_i(s_cpu_if[i].wvalid), .s_ready_o(s_cpu_if[i].wready),
                .m_data_o(s_core_if[i].wdata), .m_valid_o(s_core_if[i].wvalid), .m_ready_i(s_core_if[i].wready)
            );
            axi_skid_buffer #(.DATA_WIDTH(32)) u_skid_ar (
                .aclk(aclk), .aresetn(aresetn),
                .s_data_i(s_cpu_if[i].araddr), .s_valid_i(s_cpu_if[i].arvalid), .s_ready_o(s_cpu_if[i].arready),
                .m_data_o(s_core_if[i].araddr), .m_valid_o(s_core_if[i].arvalid), .m_ready_i(s_core_if[i].arready)
            );
            
            assign s_cpu_if[i].bvalid = s_core_if[i].bvalid;
            assign s_cpu_if[i].bresp  = s_core_if[i].bresp;
            assign s_core_if[i].bready = s_cpu_if[i].bready;
            assign s_cpu_if[i].rvalid = s_core_if[i].rvalid;
            assign s_cpu_if[i].rdata  = s_core_if[i].rdata;
            assign s_cpu_if[i].rresp  = s_core_if[i].rresp;
            assign s_core_if[i].rready = s_cpu_if[i].rready;
        end
    endgenerate

    generate
        for (genvar j = 0; j < M_SLAVES; j++) begin : gen_slave_skids
            axi_skid_buffer #(.DATA_WIDTH(2)) u_skid_b (
                .aclk(aclk), .aresetn(aresetn),
                .s_data_i(m_peri_if[j].bresp), .s_valid_i(m_peri_if[j].bvalid), .s_ready_o(m_peri_if[j].bready),
                .m_data_o(m_core_if[j].bresp), .m_valid_o(m_core_if[j].bvalid), .m_ready_i(m_core_if[j].bready)
            );
            axi_skid_buffer #(.DATA_WIDTH(34)) u_skid_r (
                .aclk(aclk), .aresetn(aresetn),
                .s_data_i({m_peri_if[j].rresp, m_peri_if[j].rdata}), .s_valid_i(m_peri_if[j].rvalid), .s_ready_o(m_peri_if[j].rready),
                .m_data_o({m_core_if[j].rresp, m_core_if[j].rdata}), .m_valid_o(m_core_if[j].rvalid), .m_ready_i(m_core_if[j].rready)
            );

            assign m_peri_if[j].awaddr = m_core_if[j].awaddr;
            assign m_peri_if[j].awvalid = m_core_if[j].awvalid;
            assign m_core_if[j].awready = m_peri_if[j].awready;
            assign m_peri_if[j].wdata = m_core_if[j].wdata;
            assign m_peri_if[j].wvalid = m_core_if[j].wvalid;
            assign m_core_if[j].wready = m_peri_if[j].wready;
            assign m_peri_if[j].araddr = m_core_if[j].araddr;
            assign m_peri_if[j].arvalid = m_core_if[j].arvalid;
            assign m_core_if[j].arready = m_peri_if[j].arready;
            
            assign m_peri_if[j].awprot = '0;
            assign m_peri_if[j].arprot = '0;
            assign m_peri_if[j].wstrb  = 4'hF;
        end
    endgenerate

    logic [M_SLAVES-1:0] aw_master_match [N_MASTERS];
    logic [N_MASTERS-1:0] aw_decerr;
    logic [M_SLAVES-1:0] ar_master_match [N_MASTERS];
    logic [N_MASTERS-1:0] ar_decerr;

    generate
        for (genvar i = 0; i < N_MASTERS; i++) begin : gen_decoders
            axi_decoder #(.M_SLAVES(M_SLAVES)) u_aw_dec (
                .addr_i(s_core_if[i].awaddr), .valid_i(s_core_if[i].awvalid), .match_o(aw_master_match[i]), .decerr_o(aw_decerr[i])
            );
            axi_decoder #(.M_SLAVES(M_SLAVES)) u_ar_dec (
                .addr_i(s_core_if[i].araddr), .valid_i(s_core_if[i].arvalid), .match_o(ar_master_match[i]), .decerr_o(ar_decerr[i])
            );
        end
    endgenerate

    logic [N_MASTERS-1:0] w_req [M_SLAVES];
    logic [N_MASTERS-1:0] w_grant [M_SLAVES];
    logic                 w_ack [M_SLAVES];
    logic [N_MASTERS-1:0] r_req [M_SLAVES];
    logic [N_MASTERS-1:0] r_grant [M_SLAVES];
    logic                 r_ack [M_SLAVES];

    always_comb begin
        for (int j = 0; j < M_SLAVES; j++) begin
            for (int i = 0; i < N_MASTERS; i++) begin
                w_req[j][i] = aw_master_match[i][j];
                r_req[j][i] = ar_master_match[i][j];
            end
        end
    end

    typedef enum logic [1:0] {W_IDLE, W_ADDR_DATA, W_RESP} w_state_t;
    typedef enum logic [1:0] {R_IDLE, R_ADDR, R_DATA} r_state_t;

    logic [M_SLAVES-1:0] master_awready [N_MASTERS];
    logic [M_SLAVES-1:0] master_wready  [N_MASTERS];
    logic [M_SLAVES-1:0] master_bvalid  [N_MASTERS];
    logic [1:0]          master_bresp   [N_MASTERS][M_SLAVES];
    logic [M_SLAVES-1:0] master_arready [N_MASTERS];
    logic [M_SLAVES-1:0] master_rvalid  [N_MASTERS];
    logic [31:0]         master_rdata   [N_MASTERS][M_SLAVES];
    logic [1:0]          master_rresp   [N_MASTERS][M_SLAVES];

    generate
        for (genvar j = 0; j < M_SLAVES; j++) begin : gen_slave_logic
            rr_arbiter #(.N_REQ(N_MASTERS)) u_w_arbiter (
                .clk(aclk), .rst_n(aresetn), .req_i(w_req[j]), .ack_i(w_ack[j]), .grant_o(w_grant[j])
            );
            rr_arbiter #(.N_REQ(N_MASTERS)) u_r_arbiter (
                .clk(aclk), .rst_n(aresetn), .req_i(r_req[j]), .ack_i(r_ack[j]), .grant_o(r_grant[j])
            );

            w_state_t w_state_q, w_state_d;
            logic aw_done_q, aw_done_d, w_done_q, w_done_d;
            logic [N_MASTERS-1:0] w_grant_q, w_grant_d; 
            r_state_t r_state_q, r_state_d;
            logic [N_MASTERS-1:0] r_grant_q, r_grant_d; 

            always_ff @(posedge aclk or negedge aresetn) begin
                if (!aresetn) begin
                    w_state_q <= W_IDLE; aw_done_q <= 1'b0; w_done_q <= 1'b0; w_grant_q <= '0;
                    r_state_q <= R_IDLE; r_grant_q <= '0;
                end else begin
                    w_state_q <= w_state_d; aw_done_q <= aw_done_d; w_done_q <= w_done_d; w_grant_q <= w_grant_d;
                    r_state_q <= r_state_d; r_grant_q <= r_grant_d;
                end
            end

            always_comb begin
                w_state_d = w_state_q; aw_done_d = aw_done_q; w_done_d = w_done_q; w_grant_d = w_grant_q; w_ack[j] = 1'b0;
                case (w_state_q)
                    W_IDLE: begin
                        aw_done_d = 1'b0; w_done_d = 1'b0;
                        if (|w_grant[j]) begin w_state_d = W_ADDR_DATA; w_grant_d = w_grant[j]; end
                    end
                    W_ADDR_DATA: begin
                        if (m_core_if[j].awvalid && m_core_if[j].awready) aw_done_d = 1'b1;
                        if (m_core_if[j].wvalid  && m_core_if[j].wready)  w_done_d  = 1'b1;
                        if ((aw_done_q || (m_core_if[j].awvalid && m_core_if[j].awready)) && 
                            (w_done_q  || (m_core_if[j].wvalid  && m_core_if[j].wready))) w_state_d = W_RESP;
                    end
                    W_RESP: if (m_core_if[j].bvalid && m_core_if[j].bready) begin w_ack[j] = 1'b1; w_state_d = W_IDLE; w_grant_d = '0; end
                    default: w_state_d = W_IDLE;
                endcase
            end

            always_comb begin
                r_state_d = r_state_q; r_grant_d = r_grant_q; r_ack[j] = 1'b0;
                case (r_state_q)
                    R_IDLE: if (|r_grant[j]) begin r_state_d = R_ADDR; r_grant_d = r_grant[j]; end
                    R_ADDR: if (m_core_if[j].arvalid && m_core_if[j].arready) r_state_d = R_DATA;
                    R_DATA: if (m_core_if[j].rvalid && m_core_if[j].rready) begin r_ack[j] = 1'b1; r_state_d = R_IDLE; r_grant_d = '0; end
                    default: r_state_d = R_IDLE;
                endcase
            end

            logic [N_MASTERS-1:0] active_w_grant;
            logic [N_MASTERS-1:0] active_r_grant;
            
            assign active_w_grant = (w_state_q == W_IDLE) ? w_grant[j] : w_grant_q;
            assign active_r_grant = (r_state_q == R_IDLE) ? r_grant[j] : r_grant_q;

            always_comb begin
                for (int i=0; i<N_MASTERS; i++) begin
                    master_awready[i][j] = 0; master_wready[i][j] = 0; master_bvalid[i][j] = 0; master_bresp[i][j] = 0;
                    master_arready[i][j] = 0; master_rvalid[i][j] = 0; master_rdata[i][j] = 0; master_rresp[i][j] = 0;
                end
                if (active_w_grant[1]) begin
                    m_core_if[j].awaddr = s_core_if[1].awaddr; m_core_if[j].awvalid = s_core_if[1].awvalid && (w_state_q == W_ADDR_DATA) && !aw_done_q;
                    m_core_if[j].wdata = s_core_if[1].wdata; m_core_if[j].wvalid = s_core_if[1].wvalid && (w_state_q == W_ADDR_DATA) && !w_done_q;
                    m_core_if[j].bready = s_core_if[1].bready && (w_state_q == W_RESP);
                    master_awready[1][j] = m_core_if[j].awready && (w_state_q == W_ADDR_DATA) && !aw_done_q;
                    master_wready[1][j] = m_core_if[j].wready && (w_state_q == W_ADDR_DATA) && !w_done_q;
                    master_bvalid[1][j] = m_core_if[j].bvalid && (w_state_q == W_RESP); master_bresp[1][j] = m_core_if[j].bresp;
                end else if (active_w_grant[0]) begin
                    m_core_if[j].awaddr = s_core_if[0].awaddr; m_core_if[j].awvalid = s_core_if[0].awvalid && (w_state_q == W_ADDR_DATA) && !aw_done_q;
                    m_core_if[j].wdata = s_core_if[0].wdata; m_core_if[j].wvalid = s_core_if[0].wvalid && (w_state_q == W_ADDR_DATA) && !w_done_q;
                    m_core_if[j].bready = s_core_if[0].bready && (w_state_q == W_RESP);
                    master_awready[0][j] = m_core_if[j].awready && (w_state_q == W_ADDR_DATA) && !aw_done_q;
                    master_wready[0][j] = m_core_if[j].wready && (w_state_q == W_ADDR_DATA) && !w_done_q;
                    master_bvalid[0][j] = m_core_if[j].bvalid && (w_state_q == W_RESP); master_bresp[0][j] = m_core_if[j].bresp;
                end else begin
                    m_core_if[j].awaddr = 0; m_core_if[j].awvalid = 0; m_core_if[j].wdata = 0; m_core_if[j].wvalid = 0; m_core_if[j].bready = 0;
                end
                if (active_r_grant[1]) begin
                    m_core_if[j].araddr = s_core_if[1].araddr; m_core_if[j].arvalid = s_core_if[1].arvalid && (r_state_q == R_ADDR);
                    m_core_if[j].rready = s_core_if[1].rready && (r_state_q == R_DATA);
                    master_arready[1][j] = m_core_if[j].arready && (r_state_q == R_ADDR);
                    master_rvalid[1][j] = m_core_if[j].rvalid && (r_state_q == R_DATA); master_rdata[1][j] = m_core_if[j].rdata; master_rresp[1][j] = m_core_if[j].rresp;
                end else if (active_r_grant[0]) begin
                    m_core_if[j].araddr = s_core_if[0].araddr; m_core_if[j].arvalid = s_core_if[0].arvalid && (r_state_q == R_ADDR);
                    m_core_if[j].rready = s_core_if[0].rready && (r_state_q == R_DATA);
                    master_arready[0][j] = m_core_if[j].arready && (r_state_q == R_ADDR);
                    master_rvalid[0][j] = m_core_if[j].rvalid && (r_state_q == R_DATA); master_rdata[0][j] = m_core_if[j].rdata; master_rresp[0][j] = m_core_if[j].rresp;
                end else begin
                    m_core_if[j].araddr = 0; m_core_if[j].arvalid = 0; m_core_if[j].rready = 0;
                end
            end
        end
    endgenerate

    generate
        for (genvar i = 0; i < N_MASTERS; i++) begin : gen_master_response
            always_comb begin
                s_core_if[i].awready = |master_awready[i]; s_core_if[i].wready = |master_wready[i]; s_core_if[i].bvalid = |master_bvalid[i];
                s_core_if[i].arready = |master_arready[i]; s_core_if[i].rvalid = |master_rvalid[i];
                s_core_if[i].bresp = '0; s_core_if[i].rdata = '0; s_core_if[i].rresp = '0;
                for (int j = 0; j < M_SLAVES; j++) begin
                    s_core_if[i].bresp |= master_bresp[i][j]; s_core_if[i].rdata |= master_rdata[i][j]; s_core_if[i].rresp |= master_rresp[i][j];
                end
            end
        end
    endgenerate
endmodule