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

    // Arbiter Wires
    logic [N_MASTERS-1:0] slave_req [M_SLAVES];
    logic [N_MASTERS-1:0] slave_grant [M_SLAVES];
    logic                 slave_ack [M_SLAVES];

    // Generate an Arbiter for each slave
    generate
        for (genvar j = 0; j < M_SLAVES; j++) begin : gen_arbiters
            
            rr_arbiter #(
                .N_REQ(N_MASTERS)
            ) u_arbiter (
                .clk    (aclk),
                .rst_n  (aresetn),
                .req_i  (slave_req[j]),   
                .ack_i  (slave_ack[j]),   
                .grant_o(slave_grant[j])  
            );

        end
    endgenerate

    for (genvar i = 0; i < N_MASTERS; i++) begin : gen_master_tie
        assign s_cpu_if[i].awready = 1'b0;
        assign s_cpu_if[i].wready  = 1'b0;
        assign s_cpu_if[i].bvalid  = 1'b0;
        assign s_cpu_if[i].bresp   = 2'b00; 
        assign s_cpu_if[i].arready = 1'b0;
        assign s_cpu_if[i].rvalid  = 1'b0;
        assign s_cpu_if[i].rdata   = '0;
        assign s_cpu_if[i].rresp   = 2'b00;
    end

    for (genvar j = 0; j < M_SLAVES; j++) begin : gen_slave_tie
        assign m_peri_if[j].awaddr  = '0;
        assign m_peri_if[j].awvalid = 1'b0;
        assign m_peri_if[j].awprot  = '0;
        assign m_peri_if[j].wdata   = '0;
        assign m_peri_if[j].wstrb   = '0;
        assign m_peri_if[j].wvalid  = 1'b0;
        assign m_peri_if[j].bready  = 1'b0;
        assign m_peri_if[j].araddr  = '0;
        assign m_peri_if[j].arvalid = 1'b0;
        assign m_peri_if[j].arprot  = '0;
        assign m_peri_if[j].rready  = 1'b0;
        
        // Temporarily tie off  internal arbiter inputs to 0
        assign slave_req[j] = '0;
        assign slave_ack[j] = 1'b0;
    end

endmodule