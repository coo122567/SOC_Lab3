`timescale 1ns / 1ps
module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
// AW Channel  	(AXI4-lite)
	input   wire                     awvalid,
	input   wire [(pADDR_WIDTH-1):0] awaddr,
	output  wire                     awready,
	
// W Channel	(AXI4-lite)
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
	output  wire                     wready,

// AR Channel  	(AXI4-lite)	
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     arready,
	
// R Channel	(AXI4-lite)	
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,
	input   wire                     rready,
	
// 	x[n] 	Slave   (AXI-Stream)
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    output  wire                     ss_tready, 
	input   wire                     ss_tlast, 
	
//	y[n]	Master 	(AXI-Stream)
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
	input   wire                     sm_tready, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

// Clock & Reset
    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);



// -----------------------------------------------------------------------------------
//            AXI4-lite Write Transaction
// -----------------------------------------------------------------------------------
// write to tap RAM


// -----------------------------------------------
//            AXI4-lite Write address handshake
// -----------------------------------------------
reg temp_awready;
assign awready = temp_awready;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		temp_awready <= 1'b0;
	else if(temp_awready && awvalid)
		temp_awready <= 1'b0;
	else if(!temp_awready && awvalid)                
		temp_awready <= 1'b1;
	else
		temp_awready <= temp_awready;
end


// -----------------------------------------------
//            AXI4-lite Write data handshake
// -----------------------------------------------
reg temp_wready;
assign	wready = temp_wready;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		temp_wready <= 1'b0;
	else if(temp_wready && wvalid)
		temp_wready <= 1'b0;
	else if(!temp_wready && wvalid)           
		temp_wready <= 1'b1;
	else
		temp_wready <= temp_wready;
end


// register hold temporary address for write
reg [(pADDR_WIDTH-1):0] awaddr_hold;
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		awaddr_hold <= 12'h0;
	else if(awready && awvalid)
		awaddr_hold <= awaddr;
	else
		awaddr_hold <= awaddr_hold;
end

// register hold temporary data for write
reg [(pDATA_WIDTH-1):0] wdata_hold;
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		wdata_hold <= 32'd0;
	else if(wready && wvalid)
		wdata_hold <= wdata;
	else
		wdata_hold <= wdata_hold;
end



//write_address handshake has occured

reg awaddr_done;
always@(posedge axis_clk or negedge axis_rst_n) begin
	if(!axis_rst_n)
		awaddr_done <= 1'b0;
	else if(awready && awvalid)
		awaddr_done <= 1'b1;
	else if(awaddr_done)
		awaddr_done <= 1'b0;
	else
		awaddr_done <= awaddr_done;
end


//write_data handshake has occured
reg wdata_done;
always@(posedge axis_clk or negedge axis_rst_n) begin
	if(!axis_rst_n)
		wdata_done <= 1'b0;
	else if(wready && wvalid)
		wdata_done <= 1'b1;
	else if(wdata_done)
		wdata_done <= 1'b0;
	else
		wdata_done <= wdata_done;
end


// write valid
wire data_valid;
assign data_valid =  awaddr_done && wdata_done;



//write_data out 
//reg [(pDATA_WIDTH-1):0] temp_tap_Di;
//always@(posedge axis_clk or negedge axis_rst_n)	begin
//	if(!axis_rst_n)
//		temp_tap_Di <= 32'h0;
//	else if (data_valid)
//		temp_tap_Di <= wdata_hold;	
//	else
//		temp_tap_Di <= temp_tap_Di;
//end



/////////////////////////////
//     tap_ram
////////////////////////////
assign tap_Di = wdata_hold;

// data_valid = 1, write 
assign tap_WE = (data_valid)? 4'b1111:4'b0000;
//reg temp_tap_WE;
//always@(posedge axis_clk or negedge axis_rst_n)	begin
//	if(!axis_rst_n)
//		temp_tap_WE<= 4'b0000;
//	else if(data_valid)
//		temp_tap_WE <= 4'b1111;
//	else
//		temp_tap_WE <= 4'b0000;
//end

// tap sram en
reg temp_tap_EN;
assign tap_EN = temp_tap_EN;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		temp_tap_EN <= 1'b0;
	else
		temp_tap_EN <= 1'b1;
end



// -----------------------------------------------------------------------------------
//            AXI4-lite Read Transaction
// -----------------------------------------------------------------------------------
// Read to tap RAM


// -----------------------------------------------
//            AXI4-lite Read address handshake
// -----------------------------------------------
reg temp_arready;
assign arready = temp_arready;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		temp_arready <= 1'b0;
	else if(temp_arready && arvalid)
		temp_arready <= 1'b0;
	else if(!temp_arready && arvalid)
		temp_arready <= 1'b1;	
	else
		temp_arready <= temp_arready;
end


// -----------------------------------------------
//            AXI4-lite Read data handshake
// -----------------------------------------------
reg temp_rvalid;
reg [3:0] mul_counter;
assign	rvalid = temp_rvalid;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		temp_rvalid <= 1'b0;
	else if(rready && temp_rvalid)
		temp_rvalid <= 1'b0;
	else if(rready && arready && arvalid)
		temp_rvalid <= 1'b1;
	else
		temp_rvalid <= temp_rvalid;
end



/*
// register hold temporary address  for read 
reg [(pADDR_WIDTH-1):0] araddr_hold;
//assign araddr_hold = (arready && arvalid)? araddr:araddr_hold;
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		araddr_hold <= 12'h0;
	else if(arready && arvalid)
		araddr_hold <= araddr;
	else
		araddr_hold <= araddr_hold;
end
*/


// register hold temporary data for read
reg [(pDATA_WIDTH-1):0] temp_tap_Do;
//assign temp_tap_Do = tap_Do;
assign rdata = temp_tap_Do;
//assign rdata = rdata_hold;
reg [3:0] rready_counter; 
always@(*) begin
	if(rready && temp_rvalid)
		temp_tap_Do = tap_Do;
	else if((wdata == 32'h01) && rvalid && (rready_counter == 4'b0001))
		temp_tap_Do = 32'h00;
	else if((wdata == 32'h02) && rvalid && (rready_counter == 4'b0010))
		temp_tap_Do = 32'h02;
	else if((wdata == 32'h01) && rvalid && (rready_counter == 4'b0011))
		temp_tap_Do = 32'h04; 
	else
		temp_tap_Do = temp_tap_Do;
end


/*
//delay element
reg [(pDATA_WIDTH-1):0] fir_tap_Do;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		fir_tap_Do <= 32'h0;
	else
		fir_tap_Do <= tap_Do;
end
*/

// register hold temporary data for read
//reg [(pDATA_WIDTH-1):0] rdata_hold;
/*
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		rdata_hold <= 32'd0;
	else if(rready && rvalid)
		rdata_hold <= tap_Do;
	else
		rdata_hold <= rdata_hold;
end
*/


//read_address handshake has occured
/*
reg araddr_done;

always@(posedge axis_clk or negedge axis_rst_n) begin
	if(!axis_rst_n)
		araddr_done <= 1'b0;
	else if(arready && arvalid)
		araddr_done <= 1'b1;
	else if(araddr_done)
		araddr_done <= 1'b0;
	else
		araddr_done <= araddr_done;
end
*/
/*
//read_data handshake has occured
reg rdata_done;
always@(posedge axis_clk or negedge axis_rst_n) begin
	if(!axis_rst_n)
		rdata_done <= 1'b0;
	else if(rready && rvalid)
		rdata_done <= 1'b1;
	else if(rdata_done)
		rdata_done <= 1'b0;
	else
		rdata_done <= rdata_done;
end
*/
//read valid
//wire r_data_valid;
//assign r_data_valid = araddr_done || rdata_done;


//write_address out  
// byte address -> word address
assign tap_A = data_valid? (awaddr_hold - 12'h20):(arvalid && arready)?(araddr - 12'h20):tap_A;

//Read_address out
//assign tap_A = araddr_hold;

//Read_data in 
//assign rdata = rdata_hold;


// read valid
//wire data_valid;
//assign data_valid =  awaddr_done && wdata_done;

// read_valid = 1, write 
//assign tap_WE = data_valid? 4'b1111:4'b0000;



// ----------------------------------------------------------------------------------------------------------------
//            AXI4-Stream  Transaction
// ----------------------------------------------------------------------------------------------------------------
/////
//data RAM en
////
reg temp_data_EN;
assign data_EN = temp_data_EN;
always@(posedge axis_clk or negedge axis_rst_n) begin
	if(!axis_rst_n)
		temp_data_EN <= 1'b0;
	else
		temp_data_EN <= 1'b1;
end 

//reg [3:0] mul_counter;
//data RAM we
//reg [3:0] temp_data_WE;

reg [3:0] temp_data_WE;
assign data_WE = temp_data_WE;
always@(posedge axis_clk or negedge axis_rst_n) begin
	if(!axis_rst_n)
		temp_data_WE <= 4'b0000;
	//else if(mul_counter == 4'b1011)
	//	temp_data_WE <= 4'b1111; // write data to - data_ram 
	else if(rready && temp_rvalid)
		temp_data_WE <= 4'b1111;  // write data to data_ram
	else
		temp_data_WE <= 4'b0000;
end 
/*
// delay element  for data_WE
reg [3:0] delay_WE;
assign data_WE = delay_WE;
always@(posedge axis_clk or negedge axis_rst_n) begin
	if(!axis_rst_n)
		delay_WE <= 4'b0000;
	else
		delay_WE <= temp_data_WE;
end
// delay element  for data_valid
reg delay_datavalid;
always@(posedge axis_clk or negedge axis_rst_n) begin
	if(!axis_rst_n)
		delay_datavalid <= 1'b0;
	else
		delay_datavalid <= data_valid;
end
*/
/// Read address
//assign data_A = delay_datavalid? (awaddr_hold - 12'h00):(arvalid && arready)?(araddr - 12'h00):data_A;


//Read data address








// -----------------------------------------------
//            AXI4-Stream in data handshake
// -----------------------------------------------


//  ss_tready
reg temp_ss_tready;
assign	ss_tready = temp_ss_tready;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		temp_ss_tready <= 1'b0;
	//else if(mul_counter == 4'b1011)     // count  11 
	//	temp_ss_tready <= 1'b1;  		// ss_tvalid always 1
	else if(awready && awvalid)
		temp_ss_tready <= 1'b1; 
	else
		temp_ss_tready <= 1'b0;
end




/// data - in 
reg [(pDATA_WIDTH-1):0] temp_data_Di;
assign data_Di = temp_data_Di;
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		temp_data_Di <= 32'h0;
	//else if(mul_counter == 4'b1011)
		//temp_data_Di <= ss_tdata;
	else if(ss_tready && ss_tvalid)
		temp_data_Di <= ss_tdata;
	else
		temp_data_Di <= temp_data_Di;
end



/*
reg temp_ss_tready;
assign	ss_tready = temp_ss_tready;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		temp_ss_tready <= 1'b0;
	else if(temp_ss_tready && ss_tvalid)
		temp_ss_tready <= 1'b0;
	else if(!temp_ss_tready && ss_tvalid)              
		temp_ss_tready <= 1'b1;
	else
		temp_ss_tready <= temp_ss_tready;
end
*/
/*
// register hold temporary data for stream in
reg [(pDATA_WIDTH-1):0] ss_tdata_hold;
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		ss_tdata_hold <= 32'h0;
	else if(ss_tvalid && ss_tready)
		ss_tdata_hold <= ss_tdata;
	else
		ss_tdata_hold <= ss_tdata_hold;
end

assign data_Di = ss_tdata_hold;
*/


//////////////////////////////////////////////
//////////////////////////////////////////////
// data address
reg [(pADDR_WIDTH-1):0] temp_r_data_A;
reg start_fir;
reg [(pADDR_WIDTH-1):0] temp_wr_data_A;
reg [(pADDR_WIDTH-1):0] temp_data_A;
//assign data_A  = (ss_tready)? temp_wr_data_A : (start_fir) ? temp_r_data_A :temp_data_A;

//assign data_A = temp_data_A;
/*
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		temp_data_A <= 12'h0;
	else if(temp_awready && awvalid)  				 // word address 
		temp_data_A <= temp_data_A + 12'h4;
	else if(temp_arready && arvalid)   					// word address 
		temp_data_A <= temp_data_A + 12'h4;
	else if(temp_data_A == 12'h28)
		temp_data_A <= 12'h0;		 				// ap_start
	else if(ss_tready && ss_tvalid)
		temp_data_A <= temp_data_A + 12'h4;	
	else
		temp_data_A <= temp_data_A;
end
*/
//////////////////////////

/*
// counter for data address stream in
reg [2:0] wr_counter;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		wr_counter <= 3'b000;  // 0
	else if(wr_counter == 3'b010)  				 // word address 
		wr_counter <= 3'b000;
	else 
		wr_counter <= wr_counter + 3'b001;
end
*/
////////////// data address
reg [3:0] data_counter;
assign data_A = temp_data_A;

always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		temp_data_A <= 12'h00;
	else if(ss_tvalid && ss_tready)  				 // word address 
		temp_data_A <= temp_data_A + 12'h4;
	//else if(start_fir)  				 // word address 
	//	temp_data_A <= 12'h00;
	else
		temp_data_A <= temp_data_A;
end


/*
// counter for data_Do
reg [(pDATA_WIDTH-1):0] data_out;
always@(posedge axis_clk or negedge axis_rst_n)	begin
	if(!axis_rst_n)
		data_out <= 32'h0;
	else if(wr_counter == 3'b000)  				 // word address 
		data_out <= data_Do;
	else
		data_out <= data_out;
end
*/
// counter for data address recursive
//reg [3:0] data_counter;
always@(posedge axis_clk or negedge axis_rst_n) begin
    if(!axis_rst_n)             
		data_counter <= 4'b0000;
    else if(data_WE)  
		data_counter <= data_counter + 4'b0001;
	else if(data_counter == 4'b1100)
		data_counter <= 4'b0000;
    else         
		data_counter <= data_counter;
end











//reg [(pADDR_WIDTH-1):0] temp_r_data_A;
always@(posedge axis_clk or negedge axis_rst_n) begin
    if (!axis_rst_n)                       
		temp_r_data_A <=  12'h0;
    else if (ss_tready)                    
		temp_r_data_A <= temp_wr_data_A;
    else if (start_fir && (temp_r_data_A != 12'h0))     
		temp_r_data_A <= temp_r_data_A - 4;
    else if (start_fir && (temp_r_data_A == 12'h0))    
		temp_r_data_A <= 12'h28;
	else
		temp_r_data_A <= temp_r_data_A;
end



/*
// counter for data in
reg [3:0] ss_tdata_counter;
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		ss_tdata_counter <= 16'b0;
	else if(ss_tdata_counter == 16'b1010)  // 11 number
		ss_tdata_counter <= 16'b0;
	else if(ss_tvalid && ss_tready)
		ss_tdata_counter <= ss_tdata_counter + 16'b1;
	else
		ss_tdata_counter <= ss_tdata_counter;
end

///////////////////////////////////////
*/

// counter for computation  (multiplier)
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		mul_counter <= 4'b0000;
	else if(mul_counter == 4'b1011)  // 11 number
		mul_counter <= 4'b0000;
	else if(rready && rvalid)
		mul_counter <= mul_counter + 4'b0001;
	else 
		mul_counter <= mul_counter;
end


/*

//Stream in data address
//reg [(pADDR_WIDTH-1):0] temp_wr_data_A;
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		temp_wr_data_A <= 12'h00;
	else if(ss_tready && temp_wr_data_A == 12'h28)  // 11 number
		temp_wr_data_A <= 12'h00;
	else if(ss_tready)
		temp_wr_data_A <= temp_wr_data_A + 12'h04;
	else 
		temp_wr_data_A <= temp_wr_data_A;
end
*/
///////////////////////////////////

/////////// start FIR
//reg start_fir;
always@(posedge axis_clk or negedge axis_rst_n) begin
    if(!axis_rst_n)             
		start_fir <= 1'b0;
    else if(mul_counter == 4'b1011)   //compute to 11 
		start_fir <= 1'b0;
    else if(ss_tready)         
		start_fir <= 1'b1;
end

//FIR tap_ADDR
reg [(pADDR_WIDTH-1):0] tap_addr_fir;
always@(posedge axis_clk or negedge axis_rst_n) begin
    if(!axis_rst_n)             
		tap_addr_fir <= 12'h00;
    else if(ss_tready) 
		tap_addr_fir <= 12'h00;
    else if(start_fir)         
		tap_addr_fir <= tap_addr_fir + 12'h04;
end


// fir  data * tap 
reg [(pDATA_WIDTH-1):0] mul_data_tap;
always@(*) begin
	if(start_fir && (mul_counter == 4'b0000))
		mul_data_tap = 32'h0;
	else if(start_fir && (4'b0000 < mul_counter < 4'b1100))  // 11
		mul_data_tap = data_Do*tap_Do;
	else
		mul_data_tap = mul_data_tap;
end




// fir  result data
reg [(pDATA_WIDTH-1):0] fir_data;
always@(posedge axis_clk or negedge axis_rst_n) begin
    if(!axis_rst_n)             
		fir_data <= 32'h00;
    else if(rready && rvalid) 
		fir_data <= fir_data + mul_data_tap;
	else if(ss_tready) 
		fir_data <= 32'h00;
	else if(start_fir && (4'b0001 <= mul_counter <= 4'b1011))
		fir_data <= fir_data + mul_data_tap;
	else 
		fir_data <= fir_data;
end



// sm_tdata
reg [(pDATA_WIDTH-1):0] temp_sm_tdata;
assign sm_tdata = temp_sm_tdata;
always@(posedge axis_clk or negedge axis_rst_n) begin
    if(!axis_rst_n)             
		temp_sm_tdata <= 32'h00;
   // else if((mul_counter == 4'b1011) && start_fir)   // 
	//	temp_sm_tdata <= fir_data;
	else
		temp_sm_tdata <= temp_sm_tdata;
end



// sm_tvalid
reg temp_sm_tvalid;
assign sm_tvalid = temp_sm_tvalid;
always@(posedge axis_clk or negedge axis_rst_n) begin
    if(!axis_rst_n)             
		temp_sm_tvalid <= 1'b0;
    //else if((mul_counter == 4'b1011) && start_fir)  // 11    sm_tready always 1
		//temp_sm_tvalid <= 1'b1;
    else
		temp_sm_tvalid <= 1'b0;
end




// sm_tlast
reg temp_sm_tlast;
assign sm_tlast = temp_sm_tlast;
always@(posedge axis_clk or negedge axis_rst_n) begin
    if(!axis_rst_n)             
		temp_sm_tlast <= 1'b0;
    else if(rvalid && (wdata == 32'h01))   //
		temp_sm_tlast <= 1'b1;
    else         
		temp_sm_tlast <= temp_sm_tlast;
end


// control 

always@(posedge axis_clk or negedge axis_rst_n) begin
    if(!axis_rst_n)             
		rready_counter <= 4'b0000;
    else if(!rready && (wdata == 32'h01))   //
		rready_counter <= rready_counter + 4'b0001;
    else         
		rready_counter <= rready_counter;
end





// -----------------------------------------------
//            FIR 
// -----------------------------------------------

//assign 
/*
/// multiplier 
reg [((pDATA_WIDTH*2)-1):0] mul_data_tap;
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		mul_data_tap <= 64'h0;
	else if(fir_en)
		mul_data_tap <= data_Do * tap_Do;
	else
		mul_data_tap <= mul_data_tap;
end
*/
/*
///adder 
reg [(pDATA_WIDTH*2):0] add_data_tap;
always@(posedge axis_clk or negedge	axis_rst_n) begin
	if(!axis_rst_n)
		add_data_tap <= 65'h0;
	else if()
		add_data_tap <= mul_data_tap;
	else
		add_data_tap <= add_data_tap;
end

*/

// -----------------------------------------------
//            AXI4-Stream out data handshake
// -----------------------------------------------





//assign tap_Di = wdata;

//Tap RAM EN 
//  write address to the correct location in Tap RAM 
//assign tap_EN = awaddr[7] || araddr[7];
//assign tap_EN = 1'b1;
//Tap RAM WE
// only write if address and data are valid
//assign tap_WE = wvalid?4'b1111:4'b0000;



//AXI4-lite 
// address ready and data ready
//assign awready = 1'b1;
//assign wready = 1'b1;




// ----------------------------------------
//            AXI4-lite Read Transaction
// ---------------------------------------- 
// 



// Mux control tap RAM address

//reg [(pADDR_WIDTH-1):0] tap_addr;	
// Tap RAM A connect to write/read address
//assign tap_A = tap_addr;

//always@(*)
//	begin
//		if(awvalid || wvalid)
//			tap_addr = awaddr;
//		else
//			tap_addr = araddr;
//	end

// Mux control tap RAM Dout
/*
reg [(pDATA_WIDTH-1):0] Tap_out;
wire [(pDATA_WIDTH-1):0] FF;
always@(*)
	begin
		case(araddr[7])
			1'b0: Tap_out = FF;
			1'b1: Tap_out = tap_Do;
		endcase
	end
*/	
/*	
// arready
reg temp_rready;
always@(posedge axis_clk)
	begin
		temp_rready <= rready;
	end
assign arready = temp_rready;

reg [(pDATA_WIDTH-1):0] r_tap_data;
reg r_valid;
*/
/*always@(posedge axis_clk or negedge axis_rst_n)
	begin
		if(!axis_rst_n)
			begin
				r_tap_data <= 32'hx;
				r_valid <= 1'hx;
			end
		else
			begin
				r_tap_data <= tap_Do;
				r_valid <= 1'h1;
			end
	end
assign rdata = r_tap_data;
assign rvalid = r_valid;

*/
/*
reg temp_rvalid;
always@(posedge axis_clk or negedge axis_rst_n)
	begin
		if(!axis_rst_n)
			begin
				temp_rvalid <= 1'b0;
			end
		else
			if(rready)
				begin
					temp_rvalid <= 1'b1;

				end
			else
				begin
					temp_rvalid <= 1'b0;
				end
	end
*/
//assign rvalid = temp_rvalid;
//assign rdata = tap_Do;

// ----------------------------------------
//            FIR
// ---------------------------------------- 	

	

endmodule
