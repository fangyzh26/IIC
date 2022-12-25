module top_iic(
    input sys_clk,
    input sys_rst_n,

    output scl,
    inout  sda
    );

    parameter  SLAVE_ADDRESS    =  7'b1010_000    ; // the address of slave
    parameter  SYSTEM_CLK       =  26'd50_000_000 ; // system clock
    parameter  IIC_CLK          =  26'd250_000    ; // IIC clock
    parameter  DIV_FREQ_FACTOR  =  SYSTEM_CLK/IIC_CLK/2; // the factor of dividing system clock
    parameter  ADDR_WIDTH       =  1'b1; //1: 16bit address ; 0:8 bit address

    wire        start;
    wire        ctrl_w0_r1;
    wire [15:0] addr;
    wire [7:0]  data_write;
    wire        flag_done;
    wire [7:0]  data_read;

    e2prom_ctrl inst_e2prom_ctrl
    (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .flag_done  (flag_done),
        .data_read  (data_read),

        .start      (start),
        .ctrl_w0_r1 (ctrl_w0_r1),
        .addr       (addr),
        .data_write (data_write)
    );

    i2c_drive #(
        .SLAVE_ADDRESS  (SLAVE_ADDRESS),
        .SYSTEM_CLK     (SYSTEM_CLK),
        .IIC_CLK        (IIC_CLK),
        .DIV_FREQ_FACTOR(DIV_FREQ_FACTOR),
        .ADDR_WIDTH     (ADDR_WIDTH)
    ) inst_i2c_drive (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .start      (start),
        .ctrl_w0_r1 (ctrl_w0_r1),
        .addr       (addr),
        .data_write (data_write),
        
        .scl        (scl),
        .sda        (sda),
        .flag_done  (flag_done),
        .data_read  (data_read)
    );


    
endmodule