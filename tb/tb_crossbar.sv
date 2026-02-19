module tb_crossbar;

    logic clk;
    logic rst_n;

    axi_lite_if m_if [2] (clk, rst_n);
    axi_lite_if s_if [2] (clk, rst_n);

    virtual axi_lite_if v_m_if [2];

    axi_crossbar #(
        .N_MASTERS(2),
        .M_SLAVES(2)
    ) dut (
        .aclk   (clk),
        .aresetn(rst_n),
        .s_cpu_if (m_if),
        .m_peri_if(s_if)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Cycle-accurate BFM task
    task automatic axi_write(int m_idx, logic [31:0] addr, logic [31:0] data);
        @(posedge clk);
        v_m_if[m_idx].bready = 1'b1;

        fork
            begin
                v_m_if[m_idx].awaddr  = addr;
                v_m_if[m_idx].awvalid = 1'b1;
                do begin
                    @(posedge clk);
                end while (!v_m_if[m_idx].awready);
                v_m_if[m_idx].awvalid = 1'b0;
            end
            begin
                v_m_if[m_idx].wdata  = data;
                v_m_if[m_idx].wvalid = 1'b1;
                do begin
                    @(posedge clk);
                end while (!v_m_if[m_idx].wready);
                v_m_if[m_idx].wvalid = 1'b0;
            end
        join

        do begin
            @(posedge clk);
        end while (!v_m_if[m_idx].bvalid);
        v_m_if[m_idx].bready = 1'b0;
    endtask

    logic aw_recv [2];
    logic w_recv [2];

    generate
        for (genvar j = 0; j < 2; j++) begin : gen_slave_bfm
            assign s_if[j].awready = !s_if[j].bvalid;
            assign s_if[j].wready  = !s_if[j].bvalid;
            assign s_if[j].bresp   = 2'b00;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    s_if[j].bvalid <= 1'b0;
                    aw_recv[j]     <= 1'b0;
                    w_recv[j]      <= 1'b0;
                end else begin
                    if (s_if[j].awvalid && s_if[j].awready) aw_recv[j] <= 1'b1;
                    if (s_if[j].wvalid  && s_if[j].wready)  w_recv[j]  <= 1'b1;

                    if ((aw_recv[j] || (s_if[j].awvalid && s_if[j].awready)) &&
                        (w_recv[j]  || (s_if[j].wvalid  && s_if[j].wready))) begin
                        s_if[j].bvalid <= 1'b1;
                        aw_recv[j]     <= 1'b0;
                        w_recv[j]      <= 1'b0;
                    end else if (s_if[j].bvalid && s_if[j].bready) begin
                        s_if[j].bvalid <= 1'b0;
                    end
                end
            end
        end
    endgenerate

    // Unified test sequence block
    initial begin
        v_m_if[0] = m_if[0];
        v_m_if[1] = m_if[1];

        for (int i = 0; i < 2; i++) begin
            v_m_if[i].awvalid = 0;
            v_m_if[i].wvalid  = 0;
            v_m_if[i].bready  = 0;
            v_m_if[i].awaddr  = '0;
            v_m_if[i].wdata   = '0;
            v_m_if[i].wstrb   = 4'hF;
            v_m_if[i].awprot  = '0;
        end

        rst_n = 0;
        #20 rst_n = 1;
        #20;

        axi_write(0, 32'h4000_0004, 32'hDEADBEEF);
        axi_write(1, 32'h4400_0008, 32'hCAFEBABE);

        fork
            axi_write(0, 32'h4000_0010, 32'h11111111);
            axi_write(1, 32'h4000_0020, 32'h22222222);
        join

        #100 $finish;
    end

endmodule