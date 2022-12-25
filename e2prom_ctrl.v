module e2prom_ctrl(
    input               sys_clk,
    input               sys_rst_n,
    input               flag_done,//1:finish a process of writing or reading
    input [7:0]         data_read,

    output reg          start, //start=1 then begin writing or reading
    output              ctrl_w0_r1,// 0:write  1:read
    output reg [15:0]   addr,
    output reg [ 7:0]   data_write
    );

    localparam WAIT_TIME  = 19'd5_000; // writing time interval:20*5000=100,000ns=0.1ms, make sure that data write sucessfully
    localparam BYTE_DEPTH = 16;// the number of bytes need to be write

    reg  flag_write_over,flag_read_over;

    reg  flag_done_delay1, flag_done_delay2; // to find the posedge of flag_done
    wire flag_done_posedge;

    reg [7:0]  memory [7:0]; // a memory to store data which read from eeprom

    reg [19:0]  wait_cnt;     // 
    reg [4:0]  wr_addr_cnt,rd_addr_cnt;

    //--------------------------- define the period of writing or reading, start=1 means working ---------------------------------------------------------
    always @(posedge sys_clk, negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            start    <= 1'b0;
            wait_cnt <= 10'd0;
        end
        else if((!flag_done_posedge) && !flag_read_over)begin
            if (!ctrl_w0_r1) begin
                if (wait_cnt == (WAIT_TIME-1)) begin //writing interval
                    wait_cnt <= wait_cnt;
                    start    <= 1'b1;
                end
                else begin
                    wait_cnt <= wait_cnt + 1'b1;
                    start    <= start;
                end
            end
            else begin
                if (wait_cnt == (WAIT_TIME/20-1)) begin //reading interval
                    wait_cnt <= wait_cnt;
                    start    <= 1'b1;
                end
                else begin
                    wait_cnt <= wait_cnt + 1'b1;
                    start    <= start;
                end
            end
        end
        else if (flag_read_over) begin
            start    <= 1'b0;
        end
        else begin
            start    <= 1'b0;
            wait_cnt <= 10'd0;
        end
    end

    //--------------------------- get flag_done's posedge ---------------------------------------------------------
    always @(posedge sys_clk, negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            flag_done_delay1 <= 1'b0;
            flag_done_delay2 <= 1'b0;
        end
        else begin
            flag_done_delay1 <= flag_done;
            flag_done_delay2 <= flag_done_delay1;
        end
    end
    assign flag_done_posedge = flag_done && (!flag_done_delay2);


    //--------------------------- eeprom's address pointer and data need to be wrote---------------------------------------------------------
    assign ctrl_w0_r1 = flag_write_over; // 0:write  1:read
    always @(posedge sys_clk, negedge sys_rst_n) begin
        if (!sys_rst_n) begin
           flag_write_over  <= 1'b0;
           addr             <= 16'b0;
           data_write       <= 8'b0;
           wr_addr_cnt      <= 4'd0;
           rd_addr_cnt      <= 4'd0;
           flag_read_over   <= 1'b0;
        end
        else if (!ctrl_w0_r1) begin  //------------writing! the control of writing address and data need to be wrote
            if (flag_done_posedge)  begin
                if (wr_addr_cnt==4'd1) begin
                    wr_addr_cnt   <= 4'd0;
                    addr       <= addr + 1'b1;
                    data_write <= data_write + 1'b1;
                end
                else begin
                    wr_addr_cnt   <= wr_addr_cnt + 1'b1;
                    addr       <= addr;
                    data_write <= data_write;
                end
                if(addr == BYTE_DEPTH-1) begin // the flag of stop writing and start reading 
                    flag_write_over <= ~flag_write_over;
                    addr            <= 16'b0;
                end
                else 
                    flag_write_over <= flag_write_over;
            end
            else begin
               addr       <= addr;
               data_write <= data_write;
            end
        end
        else begin //----------------reading! the control of reading address 
            data_write <= 8'bZ;
            if (flag_done_posedge)  begin
                if (rd_addr_cnt==4'd1) begin
                    rd_addr_cnt  <= 4'd0;
                    memory[addr] <= data_read; //****store data which read from EEPROM*****
                    addr         <= addr + 1'b1;
                end
                else begin
                    rd_addr_cnt   <= rd_addr_cnt + 1'b1;
                    addr          <= addr;
                end
                if(addr == BYTE_DEPTH) begin // the flag of stop reading and start writing
                    flag_read_over <= 1'b1;
                    addr           <= 16'bz;
                end
                else 
                    flag_write_over <= flag_write_over;
            end
            else 
               addr <= addr;           
        end
    end

endmodule

