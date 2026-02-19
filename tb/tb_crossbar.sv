module tb_crossbar;

    logic clk;
    logic rst_n;

    // PHYSICAL interfaces (These are what you should look at in the waveform!)
    axi_lite_if m_if [2] (clk, rst_n);
    axi_lite_if s_if [2] (clk, rst_n);

    // VIRTUAL interfaces (Do NOT put these in the waveform viewer, they will show as 0)
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
        forever #5 clk = ~clk; // 10ns clock period
    end

    // --- Talkative Write Task ---
    task automatic axi_write(int m_idx, logic [31:0] addr, logic [31:0] data);
        $display("[%0t ns] Master %0d: STARTING Write to 0x%0h...", $time/1000, m_idx, addr);
        @(posedge clk);
        v_m_if[m_idx].bready = 1'b1;

        fork
            begin
                v_m_if[m_idx].awaddr  = addr;
                v_m_if[m_idx].awvalid = 1'b1;
                do begin @(posedge clk); end while (!v_m_if[m_idx].awready);
                v_m_if[m_idx].awvalid = 1'b0;
            end
            begin
                v_m_if[m_idx].wdata  = data;
                v_m_if[m_idx].wvalid = 1'b1;
                do begin @(posedge clk); end while (!v_m_if[m_idx].wready);
                v_m_if[m_idx].wvalid = 1'b0;
            end
        join

        do begin @(posedge clk); end while (!v_m_if[m_idx].bvalid);
        v_m_if[m_idx].bready = 1'b0;
        $display("[%0t ns] Master %0d: FINISHED Write to 0x%0h. Response: %0b", $time/1000, m_idx, addr, v_m_if[m_idx].bresp);
    endtask

    // --- Talkative Read Task ---
    task automatic axi_read(int m_idx, logic [31:0] addr, output logic [31:0] data);
        $display("[%0t ns] Master %0d: STARTING Read from 0x%0h...", $time/1000, m_idx, addr);
        @(posedge clk);
        v_m_if[m_idx].araddr  = addr;
        v_m_if[m_idx].arvalid = 1'b1;
        do begin @(posedge clk); end while (!v_m_if[m_idx].arready);
        v_m_if[m_idx].arvalid = 1'b0;

        v_m_if[m_idx].rready = 1'b1;
        do begin @(posedge clk); end while (!v_m_if[m_idx].rvalid);
        data = v_m_if[m_idx].rdata;
        v_m_if[m_idx].rready = 1'b0;
        $display("[%0t ns] Master %0d: FINISHED Read from 0x%0h. Data Received: 0x%0h", $time/1000, m_idx, addr, data);
    endtask

    // --- Slave BFM (Echoes inverted address as data) ---
    logic aw_recv [2];
    logic w_recv [2];

    generate
        for (genvar j = 0; j < 2; j++) begin : gen_slave_bfm
            assign s_if[j].awready = !s_if[j].bvalid;
            assign s_if[j].wready  = !s_if[j].bvalid;
            assign s_if[j].bresp   = 2'b00;

            assign s_if[j].arready = !s_if[j].rvalid;
            assign s_if[j].rresp   = 2'b00;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    s_if[j].bvalid <= 1'b0;
                    aw_recv[j]     <= 1'b0;
                    w_recv[j]      <= 1'b0;
                    s_if[j].rvalid <= 1'b0;
                    s_if[j].rdata  <= '0;
                end else begin
                    // Write Logic
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

                    // Read Logic
                    if (s_if[j].arvalid && s_if[j].arready) begin
                        s_if[j].rvalid <= 1'b1;
                        s_if[j].rdata  <= ~s_if[j].araddr; // Invert address to prove data moved
                    end else if (s_if[j].rvalid && s_if[j].rready) begin
                        s_if[j].rvalid <= 1'b0;
                    end
                end
            end
        end
    endgenerate

    // --- Main Sequence ---
    initial begin
        logic [31:0] rdata;
        v_m_if[0] = m_if[0];
        v_m_if[1] = m_if[1];

        for (int i = 0; i < 2; i++) begin
            v_m_if[i].awvalid = 0; v_m_if[i].wvalid = 0; v_m_if[i].bready = 0;
            v_m_if[i].awaddr = '0; v_m_if[i].wdata = '0; v_m_if[i].wstrb = 4'hF; v_m_if[i].awprot = '0;
            v_m_if[i].arvalid = 0; v_m_if[i].rready = 0; v_m_if[i].araddr = '0; v_m_if[i].arprot = '0;
        end

        $display("\n============================================");
        $display("   AXI CROSSBAR SIMULATION STARTED   ");
        $display("============================================\n");

        rst_n = 0;
        #25 rst_n = 1;

        // Sequence 1: Sequential Writes
        axi_write(0, 32'h4000_0004, 32'hDEADBEEF);
        axi_write(1, 32'h4400_0008, 32'hCAFEBABE);

        // Sequence 2: Concurrent Writes (Arbitration Test)
        fork
            axi_write(0, 32'h4000_0010, 32'h11111111);
            axi_write(1, 32'h4000_0020, 32'h22222222);
        join

        // Sequence 3: Sequential Reads
        axi_read(0, 32'h4000_0004, rdata);
        axi_read(1, 32'h4400_0008, rdata);

        $display("\n============================================");
        $display("   AXI CROSSBAR SIMULATION COMPLETE   ");
        $display("============================================\n");
        $finish;
    end
endmodule