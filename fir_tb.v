`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2023 10:38:55 AM
// Design Name: 
// Module Name: fir_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fir_tb
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11,
    parameter Data_Num    = 600
)();
    wire                        awready;
    wire                        wready;
    reg                         awvalid;
    reg   [(pADDR_WIDTH-1): 0]  awaddr;
    reg                         wvalid;
    reg signed [(pDATA_WIDTH-1) : 0] wdata;
    wire                        arready;
    reg                         rready;
    reg                         arvalid;
    reg         [(pADDR_WIDTH-1): 0] araddr;
    wire                        rvalid;
    wire signed [(pDATA_WIDTH-1): 0] rdata;
    reg                         ss_tvalid;
    reg signed [(pDATA_WIDTH-1) : 0] ss_tdata;
    reg                         ss_tlast;
    wire                        ss_tready;
    reg                         sm_tready;
    wire                        sm_tvalid;
    wire signed [(pDATA_WIDTH-1) : 0] sm_tdata;
    wire                        sm_tlast;
    reg                         axis_clk;
    reg                         axis_rst_n;

// ram for tap
    wire [3:0]               tap_WE;
    wire                     tap_EN;
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A;
    wire [(pDATA_WIDTH-1):0] tap_Do;

// ram for data RAM
    wire [3:0]               data_WE;
    wire                     data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A;
    wire [(pDATA_WIDTH-1):0] data_Do;



    fir fir_DUT(
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),

        // ram for tap
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),

        // ram for data
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do),

        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n)

        );
    
    // RAM for tap
    bram11 tap_RAM (
        .CLK(axis_clk),
        .WE(tap_WE),
        .EN(tap_EN),
        .Di(tap_Di),
        .A(tap_A),
        .Do(tap_Do)
    );

    // RAM for data: choose bram11 or bram12
    bram11 data_RAM(
        .CLK(axis_clk),
        .WE(data_WE),
        .EN(data_EN),
        .Di(data_Di),
        .A(data_A),
        .Do(data_Do)
    );

    reg signed [(pDATA_WIDTH-1):0] Din_list[0:(Data_Num-1)];
    reg signed [(pDATA_WIDTH-1):0] golden_list[0:(Data_Num-1)];
	reg error_coef;
// --------------------------------------
//            dump waveform
// --------------------------------------
    initial begin
        $dumpfile("fir.vcd");
        $dumpvars();
    end

// --------------------------------------
//            clock generator
// --------------------------------------
    initial begin
        axis_clk = 0;
        forever begin
            #5 axis_clk = (~axis_clk);
        end
    end

// --------------------------------------
//            reset_n
// --------------------------------------
    initial begin
        axis_rst_n = 0;
        @(posedge axis_clk); @(posedge axis_clk);
        axis_rst_n = 1;
    end


// --------------------------------------
//            data length 
// --------------------------------------
// It is to setup data and golden data.
    reg [31:0]  data_length;
    integer Din, golden, input_data, golden_data, m;
    initial begin
        data_length = 0;
        Din = $fopen("./samples_triangular_wave.dat","r");  // Open file to reading "r"
        golden = $fopen("./out_gold.dat","r");  // Open file to reading "r"
        for(m=0;m<Data_Num;m=m+1) begin
            input_data = $fscanf(Din,"%d", Din_list[m]);  // $fscanf(file pointer, read format, save file) 
            golden_data = $fscanf(golden,"%d", golden_list[m]);
            data_length = data_length + 1;
        end
    end
	
	
// --------------------------------------
//            Stream-in X[n]
// --------------------------------------
// ss = AXI-stream_slave (X[n])	
    integer i;
    initial begin
        $display("------------Start simulation-----------");
        ss_tvalid = 0;        //Transmitter
        $display("----Start the data input(AXI-Stream)----");
        for(i=0;i<(data_length-1);i=i+1) begin
            ss_tlast = 0; ss(Din_list[i]); // input data   using  axis_slave protocol x[n]
        end
		//ap_start address 12'h00 (read / write)
        config_read_check(12'h00, 32'h00, 32'h0000_000f); // check idle = 0, config_read_check(addr, exp_data, mask)
        ss_tlast = 1; ss(Din_list[(Data_Num-1)]); // last X[n] 
        $display("------End the data input(AXI-Stream)------");
    end

// --------------------------------------
//            Stream-out Y[n]
// --------------------------------------
// sm = AXI-stream_Master (Y[n])	
    integer k;
    reg error;
    reg status_error;
    initial begin
        error = 0; status_error = 0;
        sm_tready = 1;  // stream_Master ready  
        wait (sm_tvalid);   // recieve
        for(k=0;k < data_length;k=k+1) begin
            sm(golden_list[k],k); // sm(golden_data, pattern_count)
        end
        config_read_check(12'h00, 32'h02, 32'h0000_0002); // check ap_done = 1 (0x00 [bit 1])  
        config_read_check(12'h00, 32'h04, 32'h0000_0004); // check ap_idle = 1 (0x00 [bit 2])
//config_read_check(addr, exp_data, mask)
        if (error == 0 & error_coef == 0) begin
            $display("---------------------------------------------");
            $display("-----------Congratulations! Pass-------------");
        end
        else begin
            $display("--------Simulation Failed---------");
        end
        $finish;
    end

    // Prevent hang
    integer timeout = (1000000);
    initial begin
        while(timeout > 0) begin
            @(posedge axis_clk);
            timeout = timeout - 1;
        end
        $display($time, "Simualtion Hang ....");
        $finish;
    end

// --------------------------------------
//            FIR coefficient 
// --------------------------------------
    reg signed [31:0] coef[0:10]; // fill in coef 
    initial begin
        coef[0]  =  32'd0;
        coef[1]  = -32'd10;  // negative number using 2's complement 
        coef[2]  = -32'd9;
        coef[3]  =  32'd23;
        coef[4]  =  32'd56;
        coef[5]  =  32'd63;
        coef[6]  =  32'd56;
        coef[7]  =  32'd23;
        coef[8]  = -32'd9;
        coef[9]  = -32'd10;
        coef[10] =  32'd0;
    end
// gtkwave  display 16-radix

// -----------------------------------------
//            FIR coefficient error check
// -----------------------------------------
//  write to mem and read from mem check
   
    initial begin
        error_coef = 0;
        $display("----Start the coefficient input(AXI-lite)----");
        config_write(12'h10, data_length); // config_write(addr, data), data-length
        for(k=0; k< Tape_Num; k=k+1) begin
            config_write(12'h20+4*k, coef[k]); //tap coef
        end
        awvalid <= 0; wvalid <= 0; 
        // read-back and check
        $display(" Check Coefficient ...");
        for(k=0; k < Tape_Num; k=k+1) begin     
            config_read_check(12'h20+4*k, coef[k], 32'hffffffff); //tap coef // config_read_check(addr, exp_data, mask)
        end
        arvalid <= 0;
        $display(" Tape programming done ...");
        $display(" Start FIR");
        @(posedge axis_clk) config_write(12'h00, 32'h0000_0001);    // ap_start = 1
        $display("----End the coefficient input(AXI-lite)----");
    end


// ----------------------------------------
//            AXI4-lite Write Transaction
// ---------------------------------------- 
// Write  address and data  map
    task config_write;
        input [11:0]    addr;
        input [31:0]    data;
        begin
            awvalid <= 0; wvalid <= 0; // address write and data write
            @(posedge axis_clk);
            awvalid <= 1; awaddr <= addr;
            wvalid  <= 1; wdata <= data;
            @(posedge axis_clk);
            while (!wready) @(posedge axis_clk);
        end
    endtask



// ----------------------------------------
//            AXI4-lite Read Transaction
// ---------------------------------------- 
// read  address and data  map
//check data
    task config_read_check;
        input [11:0]        addr;  //address 
        input signed [31:0] exp_data;
        input [31:0]        mask;
        begin
            arvalid <= 0;  //read address valid   using axi-lite
            @(posedge axis_clk);
            arvalid <= 1; araddr <= addr;      // address for read address  
            rready <= 1;   // data  ready
            @(posedge axis_clk);
            while (!rvalid) @(posedge axis_clk);  // wait, until rvalid = 1
            if( (rdata & mask) != (exp_data & mask)) begin       // "&" = bitwise operator ;  rdata != exp_data is error
                $display("ERROR: exp = %d, rdata = %d", exp_data, rdata);
                error_coef <= 1;
            end else begin
                $display("OK: exp = %d, rdata = %d", exp_data, rdata);
            end
        end
    endtask


// ss = AXI-stream_slave (X[n])	
    task ss;
        input  signed [31:0] in1; //input data  32-bit data
        begin
            ss_tvalid <= 1;  // first give tvalid for 1 
            ss_tdata  <= in1; // give input data
            @(posedge axis_clk);
            while (!ss_tready) begin   // if ss_tready is "0", still wait  until handshake occur
                @(posedge axis_clk);
            end
        end
    endtask
	
// sm = AXI-stream_Master (Y[n])	
    task sm;
        input  signed [31:0] in2; // golden data
        input         [31:0] pcnt; // pattern count
        begin
            sm_tready <= 1; // recieve ready
            @(posedge axis_clk) 
            wait(sm_tvalid);
            while(!sm_tvalid) @(posedge axis_clk);
            if (sm_tdata != in2) begin
                $display("[ERROR] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in2, sm_tdata);
                error <= 1;
            end
            else begin
                $display("[PASS] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in2, sm_tdata);
            end
            @(posedge axis_clk);
        end
    endtask
endmodule

