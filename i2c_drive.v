module i2c_drive(
    input               sys_clk,
    input               sys_rst_n,
    input               start, //start=1 then begin writing or reading
    input               ctrl_w0_r1,
    input [15:0]        addr,
    input [7:0]         data_write,

    output reg          scl,
    inout               sda,
    output reg          flag_done, // 1:finish 1 byte of writing or reading
    output reg [7:0]    data_read
    );

    parameter  SLAVE_ADDRESS    =  7'b1010_000   ; // the address of slave
    parameter  SYSTEM_CLK       =  26'd50_000_000 ; // system clock
    parameter  IIC_CLK          =  26'd250_000    ; // IIC clock
    parameter  DIV_FREQ_FACTOR  =  SYSTEM_CLK/IIC_CLK; // the factor of dividing system clock
    parameter  ADDR_WIDTH       =  1'b1; //1: 16bit address ; 0:8 bit address

    localparam IDLE             = 10'b00_0000_0001;
    localparam SLAVE_ADDR       = 10'b00_0000_0010;
    localparam ROM_ADDR16       = 10'b00_0000_0100;
    localparam ROM_ADDR8        = 10'b00_0000_1000;
    localparam DATA_WR          = 10'b00_0001_0000;
    localparam SLAVE_ADDR_RD    = 10'b00_0010_0000;
    localparam DATA_RD          = 10'b00_0100_0000;
    localparam STOP             = 10'b00_1000_0000;

    reg          drive_clk;
    reg [14:0]   cnt_div, cnt_div_half;    // count for dividing clock
    reg [9:0]    cnt_scl;    // == scl clock 

    reg [9:0]   current_state, next_state;

    reg         flag_ack;//slave ack signal
    reg         flag_state_done;//1: a state is done
    reg [7:0]   data_read_temp;
    reg         sda_transmit_en, sda_transmit;
    wire        sda_receive;
    assign      sda = sda_transmit_en ? sda_transmit : 1'bz; // host send data to slave  
    assign      sda_receive = sda_transmit_en ? 1'bz : sda;  // host receive data from slave

    //--------------------------- generate iic's SCL ------------------------------------------------------------------------
    always @(posedge sys_clk, negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cnt_div         <= 15'd0;
            drive_clk       <= 1'b1;
            scl             <= 1'b1;
        end
        else if (start)begin //start=1, count to divide clock
            if (cnt_div == (DIV_FREQ_FACTOR/8*1-1)) begin
                drive_clk <= ~drive_clk;
                cnt_div   <= cnt_div + 1'd1;
            end
            else if (cnt_div == (DIV_FREQ_FACTOR/8*2-1)) begin
                drive_clk <= ~drive_clk;
                cnt_div   <= cnt_div + 1'd1;
            end
            else if (cnt_div == (DIV_FREQ_FACTOR/8*3-1)) begin
                drive_clk <= ~drive_clk;
                cnt_div   <= cnt_div + 1'd1;
            end
            else if (cnt_div == (DIV_FREQ_FACTOR/8*4-1)) begin
                drive_clk       <= ~drive_clk;
                scl             <= ~scl;
                cnt_div         <= 15'd0;
            end
            else begin
                cnt_div   <= cnt_div + 1'd1;
                drive_clk <= drive_clk;
                scl       <= scl;
            end
        end
        else begin
            cnt_div    <= 15'd0;
            drive_clk  <= 1'b1;
            scl        <= 1'b1;
        end
    end

    //--------------------------- FSM_1, state transfer ------------------------------------------------------------------------
    always @(posedge sys_clk, negedge sys_rst_n) begin
        if (!sys_rst_n) 
            current_state <= IDLE;
        else 
            current_state <= next_state;
    end

    //--------------------------- FSM_3, logic judgement and signal assignment -----------------------------
    always @(posedge drive_clk, negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cnt_scl         <= 10'd0;

            sda_transmit_en <= 1'b1;
            sda_transmit    <= 1'b1; 

            //flag_state_done <= 1'b0;
            flag_done       <= 1'b0;
            flag_ack        <= 1'b0;

            next_state      <= IDLE;

            data_read_temp  <= 8'bz;
            data_read       <= 8'bz;
            
        end
        else begin
            cnt_scl = cnt_scl + 1'd1; //*************/
            //----------------------------- sda assignment----------------------
            case(current_state)
                IDLE:begin
                    flag_done       <= 1'b0;
                    //flag_state_done <= 1'b1;
                    cnt_scl         <= 10'd0;
                    sda_transmit    <= 1'b0;
                    if(start) 
                        next_state <= SLAVE_ADDR;
                    else 
                        next_state <= current_state;
                end
                //------------------------- state: SLAVE_ADDR --------------------
                SLAVE_ADDR:begin
                    case (cnt_scl)
                        10'd1:  sda_transmit_en <= 1'b1;
                        10'd2:  sda_transmit <= SLAVE_ADDRESS[6]; // host send 7 bit slave's address
                        10'd6:  sda_transmit <= SLAVE_ADDRESS[5];
                        10'd10: sda_transmit <= SLAVE_ADDRESS[4];
                        10'd14: sda_transmit <= SLAVE_ADDRESS[3];
                        10'd19: sda_transmit <= SLAVE_ADDRESS[2];
                        10'd23: sda_transmit <= SLAVE_ADDRESS[1];
                        10'd27: sda_transmit <= SLAVE_ADDRESS[0];
                        10'd31: sda_transmit <= 1'b0; //writing flag
                        10'd34: sda_transmit_en <= 1'b0;// host release sda
                        10'd36: begin 
                            if (!sda_receive) // 0:slave ack successfully
                                flag_ack <= 1'b1;
                            else 
                                flag_ack <= 1'b0;
                        end
                        10'd37: begin
                            flag_ack <= 1'b0; 
                            cnt_scl  <= 10'd0;
                        end
                        default: sda_transmit <= sda_transmit;
                    endcase

                    if (flag_ack) begin
                        if(ADDR_WIDTH) 
                            next_state <= ROM_ADDR16;
                        else 
                            next_state <= ROM_ADDR8;                      
                    end
                    else 
                        next_state <= current_state;
                        
                end
                //------------------------- state: ROM_ADDR16 --------------------
                ROM_ADDR16:begin
                    case (cnt_scl)
                        10'd1:  begin
                                sda_transmit_en = 1'b1;
                                sda_transmit = addr[15]; //  host send 15~8th bit address to slave
                        end
                        10'd5:  sda_transmit <= addr[14]; 
                        10'd9:  sda_transmit <= addr[13];
                        10'd13: sda_transmit <= addr[12];
                        10'd17: sda_transmit <= addr[11];
                        10'd21: sda_transmit <= addr[10];
                        10'd25: sda_transmit <= addr[9];
                        10'd29: sda_transmit <= addr[8];
                        10'd33: sda_transmit_en <= 1'b0;// host release sda
                        10'd35: begin 
                            if (!sda_receive) // 0:slave ack successfully
                                flag_ack <= 1'b1;
                            else 
                                flag_ack <= 1'b0;
                        end
                        10'd36: begin
                            flag_ack <= 1'b0; 
                            cnt_scl  <= 10'd0;
                        end
                        default: sda_transmit <= sda_transmit;
                    endcase
                    if(flag_ack) 
                        next_state <= ROM_ADDR8;                    
                    else 
                        next_state <= current_state;
                end
                //------------------------- state: ROM_ADDR8 --------------------
                ROM_ADDR8:begin
                    case (cnt_scl)
                        10'd1:  begin
                                sda_transmit_en = 1'b1;
                                sda_transmit = addr[7];//  host send 7~0th bit address to slave
                        end 
                        10'd5:  sda_transmit <= addr[6];  
                        10'd9:  sda_transmit <= addr[5];
                        10'd13: sda_transmit <= addr[4];
                        10'd17: sda_transmit <= addr[3];
                        10'd21: sda_transmit <= addr[2];
                        10'd25: sda_transmit <= addr[1];
                        10'd29: sda_transmit <= addr[0];
                        10'd33: sda_transmit_en <= 1'b0;// host release sda
                        10'd35: begin 
                            if (!sda_receive) // 0:slave ack successfully
                                flag_ack = 1'b1;
                            else 
                                flag_ack = 1'b0;
                        end
                        10'd36: begin
                            if (flag_ack) begin
                                if(!ctrl_w0_r1) 
                                    next_state <= DATA_WR;
                                else 
                                    next_state <= SLAVE_ADDR_RD;
                            end
                            else 
                                next_state <= current_state;

                            flag_ack <= 1'b0; 
                            cnt_scl  <= 10'd0;
                        end
                        default: sda_transmit <= sda_transmit;
                    endcase
                    
                end
                //------------------------- state: DATA_WR --------------------
                DATA_WR:begin
                    case (cnt_scl)
                        10'd1:  begin
                                sda_transmit_en = 1'b1;
                                sda_transmit = data_write[7]; //  host write 7~0th bits data to slave
                        end
                        
                        10'd5:  sda_transmit <= data_write[6]; 
                        10'd9:  sda_transmit <= data_write[5];
                        10'd13: sda_transmit <= data_write[4];
                        10'd17: sda_transmit <= data_write[3];
                        10'd21: sda_transmit <= data_write[2];
                        10'd25: sda_transmit <= data_write[1];
                        10'd29: sda_transmit <= data_write[0];
                        10'd33: sda_transmit_en <= 1'b0;// host release sda
                        10'd35: begin 
                            if (!sda_receive) // 0:slave ack successfully
                                flag_ack <= 1'b1;
                            else 
                                flag_ack <= 1'b0;
                        end
                        10'd36: begin
                            flag_ack <= 1'b0; 
                            cnt_scl  <= 10'd0;
                        end
                        default: sda_transmit <= sda_transmit;
                    endcase
                    if(flag_ack) 
                        next_state <= STOP;                   
                    else 
                        next_state <= current_state;
                end
                //------------------------- state: SLAVE_ADDR_RD --------------------
                SLAVE_ADDR_RD:begin
                    case (cnt_scl)
                        10'd1:begin
                                sda_transmit_en <= 1'b1;
                                sda_transmit    <= 1'b1; 
                        end
                        10'd3:  sda_transmit <= 1'b0;
                        10'd5:  sda_transmit <= SLAVE_ADDRESS[6]; // send 7 bit slave's address again
                        10'd9:  sda_transmit <= SLAVE_ADDRESS[5];
                        10'd13: sda_transmit <= SLAVE_ADDRESS[4];
                        10'd17: sda_transmit <= SLAVE_ADDRESS[3];
                        10'd21: sda_transmit <= SLAVE_ADDRESS[2];
                        10'd25: sda_transmit <= SLAVE_ADDRESS[1];
                        10'd29: sda_transmit <= SLAVE_ADDRESS[0];
                        10'd33: sda_transmit <= 1'b1; //reading flag
                        10'd37: sda_transmit_en <= 1'b0;// host release sda
                        10'd39: begin 
                            if (!sda_receive) // 0:slave ack successfully
                                flag_ack <= 1'b1;
                            else 
                                flag_ack <= 1'b0;
                        end
                        10'd40: begin
                            flag_ack <= 1'b0; 
                            cnt_scl  <= 10'd0;
                        end
                        default: sda_transmit <= sda_transmit;
                    endcase
                    if(flag_ack) 
                        next_state <= DATA_RD;
                    else 
                        next_state <= current_state; 
                end
                //------------------------- state: DATA_RD --------------------
                DATA_RD:begin
                    case (cnt_scl)
                        10'd1:   sda_transmit_en <= 1'b0;
                        10'd3:   data_read_temp[7] <= sda_receive; // host receives 8 bits data from slave  
                        10'd7:   data_read_temp[6] <= sda_receive; 
                        10'd11:  data_read_temp[5] <= sda_receive; 
                        10'd15:  data_read_temp[4] <= sda_receive; 
                        10'd19:  data_read_temp[3] <= sda_receive;  
                        10'd23:  data_read_temp[2] <= sda_receive; 
                        10'd27:  data_read_temp[1] <= sda_receive;
                        10'd31:  data_read_temp[0] <= sda_receive;
                        10'd33:  sda_transmit_en <= 1'b1;// host release sda   
                        10'd35: begin 
                            if (sda) begin// 1:master do not ack
                                flag_ack <= 1'b1;
                                data_read <= data_read_temp;
                            end
                            else 
                                flag_ack <= 1'b0;
                        end
                        10'd36: begin
                            cnt_scl   <= 10'd0;
                            flag_ack  <= 1'b0;
                        end
                        default: sda_transmit <= sda_transmit;
                    endcase
                    if(flag_ack) 
                        next_state <= STOP;
                    else 
                        next_state <= current_state;
                end
                //------------------------- state: StOP --------------------
                STOP:begin
                    case (cnt_scl)
                        10'd1:begin
                            sda_transmit_en = 1'b1; // host take sda
                            sda_transmit = 1'b0;
                            
                        end 
                        10'd3: begin 
                            flag_done = 1'b1;
                            sda_transmit <= 1'b1;
                            cnt_scl  <= 10'd0;
                        end
                        default: sda_transmit <= sda_transmit;
                    endcase
                    if(flag_done) 
                        next_state <= IDLE;
                    else 
                        next_state <= current_state;
                end
                //------------------------- DEFAULT --------------------
                default: begin
                        sda_transmit <= sda_transmit;
                        next_state   <= IDLE;
                end
            endcase
        end
    end
endmodule

