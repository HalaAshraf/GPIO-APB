
/*************************************************************** APB BUS ****************************************************************************************************/
module APB(PCLK,PREADY,PRESETn,PENABLE,PADDR,PSEL,transfer,current_state,PWDATA_master,PWDATA,PADDR_master,PWRITE_master,PWRITE,PRDATA_master,PRDATA);

// Inputs from Master
input PCLK,PREADY,PRESETn,transfer;
input PWRITE_master;
output reg PWRITE;
output reg PENABLE,PSEL;

output reg [7:0] PWDATA,PRDATA_master;

input[7:0] PRDATA;
input[7:0] PWDATA_master;

input [3:0] PADDR_master;
output reg [3:0] PADDR;
localparam IDLE=2'b00,SETUP=2'b01,ACCESS= 2'b10;

output reg [1:0] current_state = IDLE;
reg [1:0] next_state = IDLE;


always @(posedge PCLK or negedge PRESETn)
begin
	if(!PRESETn)
		current_state <= IDLE;
	else
		current_state <= next_state;
end

// FSM
always @(posedge PCLK)
begin
	PWRITE = PWRITE_master;
	case(current_state)
		IDLE: begin
			PSEL = 0;
			PENABLE = 0;
			if(transfer)
				next_state = SETUP;
		 	end
		SETUP: begin
			PENABLE = 0;
			PADDR = PADDR_master;
			if(PWRITE_master) begin
					PWDATA = PWDATA_master;
			end
			if(transfer) 
				begin
				PSEL = 1;
				next_state = ACCESS;
				end
			end
		ACCESS: begin
			PENABLE = 1;
			if(PREADY & transfer) begin
				next_state = SETUP;
				if(!PWRITE_master)
					PRDATA_master = PRDATA;
			end
			else if(!PREADY)
				next_state = ACCESS;
			else if(PREADY & !transfer)
				next_state = IDLE;
			end
	endcase
end


endmodule

/*********************************************** GPIO Module *******************************************************************************/
module GPIO 
(
  input PRESETn,PCLK,
  input PSEL,
  input PENABLE,
  input [3:0] PADDR,
  input PWRITE,
  input [7:0] PWDATA,
  output reg [7:0] PRDATA,
  output PREADY,
  input  [7:0] gpio_i,
  input [1:0] current_state,
  output reg[7:0] out_reg
);
integer n,i;
reg[7:0] mem[0:7];

localparam DIRECTION = 0, OUTPUT = 1, INPUT = 2;
localparam IDLE=2'b00,SETUP=2'b01,ACCESS= 2'b10;
reg [7:0] dir_reg=8'd0;
//reg [7:0] out_reg=8'd0;
reg [7:0] in_reg=8'd0;

assign PREADY  = 1'b1;
/*
// read
always @(posedge PCLK)
begin
	if(!PWRITE)
	case(PADDR)
		DIRECTION: PRDATA = dir_reg;
		OUTPUT:	PRDATA = out_reg;
		INPUT: PRDATA = in_reg;
		default: PRDATA =8'd0;
	endcase
end
*/
always @(*)
begin
     if(current_state==ACCESS) begin
	if(PSEL & PENABLE & !PWRITE)
	begin
		PRDATA=mem[PADDR];
	end
	else if(PSEL & PENABLE & PWRITE)begin
		if(PADDR == DIRECTION)
			dir_reg = mem[PADDR];
		else if(PADDR == OUTPUT)
		begin
			for(n =0;n<8;n=n+1)
				out_reg[n] = dir_reg[n] ? mem[PADDR] : 1'bz;
		end
		else if(PADDR == INPUT)
		begin
			for(i = 0;i<8;i=i+1)
				mem[PADDR][i] = dir_reg[n]? 1'bz : gpio_i[i];
		end
	 end
	end
end

endmodule


/******************************************** APB-GPIO Interface ********************************************************************************/

module APB_GPIO_Interface(PCLK,PRESETn,PADDR_master,transfer,PWRITE_master,PWDATA_master,PRDATA_master,gpio_i,PENABLE,PSEL,out);
// inputs from master
input PCLK,PRESETn,transfer;
input [7:0] gpio_i,PWDATA_master; // to write on gpio pins
input [3:0] PADDR_master;
input PWRITE_master;


// outputs to master
output [7:0] PRDATA_master; 
output reg PENABLE,PSEL;
// wires between apb and gpio
wire PENABLE_IN,PSEL_IN,PREADY_O,PENABLE_O,PSEL_O;
wire [1:0] current_state_in,current_state_out;
wire [7:0] PRDATA;
output reg[7:0] out;
wire[7:0] PWDATA;
wire [3:0] PADDR;
wire PWRITE;
wire PREADY;


APB apb1(.PCLK(PCLK),.PRESETn(PRESETn),.PSEL(PSEL_O),.PWDATA(PWDATA),.PWDATA_master(PWDATA_master),.PENABLE(PENABLE_OUT),.PREADY(PREADY),.current_state(current_state_out),.PADDR(PADDR),.PADDR_master(PADDR_master),.transfer(transfer),.PWRITE_master(PWRITE_master),.PWRITE(PWRITE),.PRDATA_master(PRDATA_master),.PRDATA(PRDATA));

GPIO g1( .PCLK(PCLK) ,.PENABLE(PENABLE_IN) ,.PWRITE(PWRITE),.PSEL(PSEL_IN),.PRESETn(PRESETn),.PWDATA(PWDATA),.PADDR(PADDR),.PREADY(PREADY_O),.PRDATA(PRDATA),.current_state(current_state_in),.gpio_i(gpio_i),.out_reg(out_reg));

//assign PRDATA = PRDATA_O;
assign PENABLE_IN = PENABLE_O;
assign PSEL_IN = PSEL_O;
assign PREADY = PREADY_O;
assign PENABLE = PENABLE_O;
assign PSEL = PSEL_O;
assign current_state_in = current_state_out;
/*always @(*) begin
	if(!PWRITE)
		PRDATA = PRDATA_O;
	else if(PWRITE)
		out = out_reg;*/
//end
endmodule

/********************************************************** Test Bench **********************************************************************/
module gpiotb;

// inputs from master
reg PCLK,transfer,PRESETn,PWRITE_master;
reg [3:0] PADDR_master;
//inputs from master to GPIO
reg[7:0] PWDATA_master;
reg[7:0] gpio_i; // to write on pins

// outputs
wire [7:0] out;
wire[7:0] PRDATA_master;
wire PENABLE,PSEL;

localparam DIRECTION = 0, OUTPUT = 1, INPUT = 2;
APB_GPIO_Interface uut(.PCLK(PCLK),.PRESETn(PRESETn),.transfer(transfer),.PWRITE_master(PWRITE_master),.PADDR_master(PADDR_master),.PWDATA_master(PWDATA_master),.gpio_i(gpio_i),.PRDATA_master(PRDATA_master),.PENABLE(PENABLE),.PSEL(PSEL),.out(out));

always #50 PCLK = ~PCLK;

initial begin
PCLK = 0;
PRESETn = 0;
transfer = 0;
PADDR_master = 0;
PWRITE_master = 0;
PWDATA_master = 0;
gpio_i = 0;
end

initial begin
PRESETn = 1;
// set pin 0,pin1 dir output
PADDR_master = DIRECTION;
PWDATA_master = 8'd3;
PWRITE_master = 1;
transfer = 1;
#100;
transfer = 0;
#50;

// write 2 
PADDR_master = OUTPUT;
PWDATA_master = 8'd2;
PWRITE_master = 1;
transfer = 1;
#100;

transfer = 0;
#50;

// set pin1,pin4,pin5 direction input
PADDR_master = DIRECTION;
PWDATA_master = 8'd255;
PWRITE_master = 1;
transfer =1;
#100;

transfer = 0;
#50;
// write 25 on pins
PADDR_master = INPUT;
gpio_i = 8'd25;
PWRITE_master = 1;
transfer = 1;
#100;

transfer = 0;
#50;

// read
PADDR_master = INPUT;
PWRITE_master = 0;
transfer = 1;
#100;

transfer = 0;

end
endmodule