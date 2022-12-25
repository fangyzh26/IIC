module tb_i2c_drive();

    parameter  T                =  20; // a FPGA clock period
    parameter  SLAVE_ADDRESS    =  7'b1010_000   ; // the address of slave
    parameter  SYSTEM_CLK       =  26'd50_000_000 ; // system clock
    parameter  IIC_CLK          =  26'd250_000    ; // IIC clock
    parameter  DIV_FREQ_FACTOR  =  SYSTEM_CLK/IIC_CLK; // the factor of dividing system clock
    parameter  ADDR_WIDTH       =  1'b1; //1: 16bit address ; 0:8 bit address

    reg         sys_clk;
    reg         sys_rst_n;
    
    //reg         sda;
    initial begin  
        for(integer i=0; i<=1500000; i=i+1) 
            #10 sys_clk = ~sys_clk;
    end

    initial begin
        sys_clk          = 1'b0;
        sys_rst_n        = 1'b1;
        #(T*5) sys_rst_n = 1'b0;
        #(T*5) sys_rst_n = 1'b1;
    end

    
	top_iic #(
			.SLAVE_ADDRESS  (SLAVE_ADDRESS),
			.SYSTEM_CLK     (SYSTEM_CLK),
			.IIC_CLK        (IIC_CLK),
			.DIV_FREQ_FACTOR(DIV_FREQ_FACTOR),
			.ADDR_WIDTH     (ADDR_WIDTH)
		) inst_top_iic (
			.sys_clk   (sys_clk),
			.sys_rst_n (sys_rst_n),
			.scl       (scl),
			.sda       (sda)
		);

    
    EEPROM_AT24C64 inst_EEPROM_AT24C64 (
			.scl (scl),
			.sda (sda)
		);

        pullup(sda);
    
    pulldown(sda);

    initial 
        $vcdpluson();

    initial begin
        $fsdbDumpfile("top_iic.fsdb");
        $fsdbDumpvars(0);
    end

endmodule