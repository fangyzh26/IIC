`timescale 1ns/1ns
`define timeslice 1250
module EEPROM_AT24C64(
scl,
sda
);
input scl; 
inout sda; 
reg out_flag; 
reg[7:0] memory[8191:0]; 
reg[12:0]address; 
reg[7:0]memory_buf; 
reg[7:0]sda_buf; 
reg[7:0]shift; 
reg[7:0]addr_byte_h; 
reg[7:0]addr_byte_l; 
reg[7:0]ctrl_byte; 
reg[1:0]State;
integer i;
//---------------------------
parameter
r7 = 8'b1010_1111, w7 = 8'b1010_1110, //main7
r6 = 8'b1010_1101, w6 = 8'b1010_1100, //main6
r5 = 8'b1010_1011, w5 = 8'b1010_1010, //main5
r4 = 8'b1010_1001, w4 = 8'b1010_1000, //main4
r3 = 8'b1010_0111, w3 = 8'b1010_0110, //main3
r2 = 8'b1010_0101, w2 = 8'b1010_0100, //main2
r1 = 8'b1010_0011, w1 = 8'b1010_0010, //main1
r0 = 8'b1010_0001, w0 = 8'b1010_0000; //main0
assign sda = (out_flag == 1) ? sda_buf[7] : 1'bz;

initial
begin
addr_byte_h = 0;
addr_byte_l = 0;
ctrl_byte = 0;
out_flag = 0;
sda_buf = 0;
State = 2'b00;
memory_buf = 0;
address = 0;
shift = 0;
for(i=0;i<=8191;i=i+1)
memory[i] = 0;
end
always@(negedge sda)
begin
if(scl == 1)
begin
State = State + 1;
if(State == 2'b11)
disable write_to_eeprom;
end
end

always@(posedge sda)
begin
if(scl == 1) 
stop_W_R;
else
begin
casex(State)
2'b01:begin
read_in;
if(ctrl_byte == w7 || ctrl_byte == w6
|| ctrl_byte == w5 || ctrl_byte == w4
|| ctrl_byte == w3 || ctrl_byte == w2
|| ctrl_byte == w1 || ctrl_byte == w0)
begin
State = 2'b10;
write_to_eeprom; 
end
else
State = 2'b00;
end
2'b11:
read_from_eeprom;
default:
State = 2'b00;
endcase
end
end 
task stop_W_R;
begin
State = 2'b00;
addr_byte_h = 0;
addr_byte_l = 0;
ctrl_byte = 0;
out_flag = 0;
sda_buf = 0;
end
endtask

task read_in;
begin
shift_in(ctrl_byte);
shift_in(addr_byte_h);
shift_in(addr_byte_l);
end
endtask

task write_to_eeprom;
begin
shift_in(memory_buf);
address = {addr_byte_h[4:0], addr_byte_l};
memory[address] = memory_buf;
State = 2'b00;
end
endtask

task read_from_eeprom;
begin
shift_in(ctrl_byte);
if(ctrl_byte == r7 || ctrl_byte == w6
|| ctrl_byte == r5 || ctrl_byte == r4
|| ctrl_byte == r3 || ctrl_byte == r2
|| ctrl_byte == r1 || ctrl_byte == r0)
begin
address = {addr_byte_h[4:0], addr_byte_l};
sda_buf = memory[address];
shift_out;
State = 2'b00;
end
end
endtask
task shift_in;
output[7:0]shift;
begin
@(posedge scl) shift[7] = sda;
@(posedge scl) shift[6] = sda;
@(posedge scl) shift[5] = sda;
@(posedge scl) shift[4] = sda;
@(posedge scl) shift[3] = sda;
@(posedge scl) shift[2] = sda;
@(posedge scl) shift[1] = sda;
@(posedge scl) shift[0] = sda;
@(negedge scl)
begin
#(`timeslice);
out_flag = 1;
sda_buf = 0;
end
@(negedge scl)
begin
#(`timeslice-250);
out_flag = 0;
end
end
endtask
task shift_out;
begin
out_flag = 1;
for(i=6; i>=0; i=i-1)
begin
@(negedge scl);
#`timeslice;
sda_buf = sda_buf << 1;
end
@(negedge scl) #`timeslice sda_buf[7] = 1;
@(negedge scl) #`timeslice out_flag = 0;
end
endtask
endmodule
