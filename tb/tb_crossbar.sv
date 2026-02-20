module tb_crossbar;
    logic clk, rst_n;
    axi_lite_if m_if [2] (clk, rst_n);
    axi_lite_if s_if [2] (clk, rst_n);
    virtual axi_lite_if v_m_if [2];

    axi_crossbar dut (.aclk(clk), .aresetn(rst_n), .s_cpu_if(m_if), .m_peri_if(s_if));

    initial begin clk = 0; forever #5 clk = ~clk; end

    task automatic axi_write(int m_idx, logic [31:0] addr, logic [31:0] data);
        $display("[%0t ns] Master %0d: STARTING Write to 0x%0h...", $time/1000, m_idx, addr);
        @(posedge clk);
        v_m_if[m_idx].awaddr  <= addr;
        v_m_if[m_idx].awvalid <= 1'b1;
        v_m_if[m_idx].wdata   <= data;
        v_m_if[m_idx].wvalid  <= 1'b1;
        v_m_if[m_idx].bready  <= 1'b1;

        fork
            begin do begin @(posedge clk); end while (v_m_if[m_idx].awready !== 1'b1); v_m_if[m_idx].awvalid <= 1'b0; end
            begin do begin @(posedge clk); end while (v_m_if[m_idx].wready !== 1'b1); v_m_if[m_idx].wvalid <= 1'b0; end
        join
        do begin @(posedge clk); end while (v_m_if[m_idx].bvalid !== 1'b1);
        v_m_if[m_idx].bready <= 1'b0;
        $display("[%0t ns] Master %0d: FINISHED Write to 0x%0h.", $time/1000, m_idx, addr);
    endtask

    task automatic axi_read(int m_idx, logic [31:0] addr, output logic [31:0] data);
        $display("[%0t ns] Master %0d: STARTING Read from 0x%0h...", $time/1000, m_idx, addr);
        @(posedge clk);
        v_m_if[m_idx].araddr  <= addr;
        v_m_if[m_idx].arvalid <= 1'b1;
        do begin @(posedge clk); end while (v_m_if[m_idx].arready !== 1'b1);
        v_m_if[m_idx].arvalid <= 1'b0;

        v_m_if[m_idx].rready <= 1'b1;
        do begin @(posedge clk); end while (v_m_if[m_idx].rvalid !== 1'b1);
        data = v_m_if[m_idx].rdata;
        v_m_if[m_idx].rready <= 1'b0;
        $display("[%0t ns] Master %0d: FINISHED Read from 0x%0h. Data: 0x%0h", $time/1000, m_idx, addr, data);
    endtask

    logic aw_recv [2], w_recv [2];
    generate
        for (genvar j = 0; j < 2; j++) begin : gen_slave_bfm
            assign s_if[j].awready = !s_if[j].bvalid;
            assign s_if[j].wready  = !s_if[j].bvalid;
            assign s_if[j].arready = !s_if[j].rvalid;
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin s_if[j].bvalid <= 0; s_if[j].rvalid <= 0; aw_recv[j] <= 0; w_recv[j] <= 0; end
                else begin
                    if (s_if[j].awvalid && s_if[j].awready) aw_recv[j] <= 1;
                    if (s_if[j].wvalid  && s_if[j].wready)  w_recv[j]  <= 1;
                    if ((aw_recv[j] || (s_if[j].awvalid && s_if[j].awready)) && (w_recv[j] || (s_if[j].wvalid && s_if[j].wready))) begin
                        s_if[j].bvalid <= 1; aw_recv[j] <= 0; w_recv[j] <= 0;
                    end else if (s_if[j].bvalid && s_if[j].bready) s_if[j].bvalid <= 0;
                    if (s_if[j].arvalid && s_if[j].arready) begin s_if[j].rvalid <= 1; s_if[j].rdata <= ~s_if[j].araddr; end
                    else if (s_if[j].rvalid && s_if[j].rready) s_if[j].rvalid <= 0;
                end
            end
        end
    endgenerate

    initial begin
        logic [31:0] rd; v_m_if[0] = m_if[0]; v_m_if[1] = m_if[1];
        rst_n = 0; #100 rst_n = 1; #50;
        axi_write(0, 32'h4000_0004, 32'hDEADBEEF);
        axi_write(1, 32'h4400_0008, 32'hCAFEBABE);
        fork
            axi_write(0, 32'h4000_0010, 32'h11111111);
            axi_write(1, 32'h4000_0020, 32'h22222222);
        join
        axi_read(0, 32'h4000_0004, rd);
        axi_read(1, 32'h4400_0008, rd);
        $display("\nSIMULATION COMPLETE\n"); $finish;
    end
endmodule