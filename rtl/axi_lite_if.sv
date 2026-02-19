interface axi_lite_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input logic aclk,
    input logic aresetn
);

    // Write Address Channel
    logic [ADDR_WIDTH-1:0] awaddr;
    logic                  awvalid;
    logic                  awready;
    logic [2:0]            awprot; // Protection type

    // Write Data Channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                  wvalid;
    logic                  wready;

    // Write Response Channel
    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;

    // Read Address Channel
    logic [ADDR_WIDTH-1:0] araddr;
    logic                  arvalid;
    logic                  arready;
    logic [2:0]            arprot;

    // Read Data Channel
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;

    // Master Modport (The side initiating transactions)
    modport master (
        input  aclk, aresetn, awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid,
        output awaddr, awvalid, awprot, wdata, wstrb, wvalid, bready, araddr, arvalid, arprot, rready
    );

    // Slave Modport (The side responding to transactions)
    modport slave (
        input  aclk, aresetn, awaddr, awvalid, awprot, wdata, wstrb, wvalid, bready, araddr, arvalid, arprot, rready,
        output awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid
    );

endinterface